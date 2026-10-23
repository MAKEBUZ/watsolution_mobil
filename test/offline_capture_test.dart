import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/config/api_config.dart';
import 'package:watsolution_mobil/field/field_store.dart';
import 'published_session_test.dart' show fixture, jsonResponse;

class MemoryStore implements FieldStore {
  final persistedPerson = <String, dynamic>{'id': 7, 'fullName': 'Synthetic'};
  @override
  Future<Map<String, dynamic>?> person(int id) async =>
      id == 7 ? Map.of(persistedPerson) : null;
  @override
  Future<void> updateReference(int id, Map<String, dynamic> reference) async {
    persistedPerson.addAll(reference);
  }

  final values = <String, String>{
    'preparedAt': DateTime.now().toUtc().toIso8601String(),
  };
  final rows = <Map<String, Object?>>[];
  @override
  Future<String?> meta(String key) async => values[key];
  @override
  Future<void> setMeta(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<List<Map<String, dynamic>>> people() async => [
    Map.of(persistedPerson),
  ];
  @override
  Future<List<Map<String, Object?>>> operations() async => List.of(rows);
  @override
  Future<void> capture(Map<String, dynamic> command) async {
    rows.add({
      'id': command['operationId'],
      'person_id': command['personId'],
      'status': 'pending',
      'command': jsonEncode(command),
    });
  }

  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ApiConfig.load(origin: 'https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'containsKey' ? false : null,
        );
  });
  test(
    'previous reading remains available after recreating session without network',
    () async {
      final store = MemoryStore();
      final first = fixture(
        (_) async => jsonResponse([
          {
            'id': 8,
            'waterMeasure': 100,
            'readingDate': '2026-10-06',
            'person': {'id': 7},
          },
        ]),
      )..store = store;
      await first.reload();
      await first.measurementReference(first.people.single);
      await first.lock();
      var networkCalls = 0;
      final reopened = fixture((_) async {
        networkCalls++;
        throw StateError('Offline');
      })..store = store;
      await reopened.reload();
      final result = await reopened.measurementReference({
        'id': 7,
        'fullName': 'Synthetic',
      });
      expect(result.single['waterMeasure'], 100);
      expect(result.single['readingDate'], '2026-10-06');
      expect(networkCalls, 0);
      reopened.people = [
        {'id': 7, 'fullName': 'Synthetic'},
      ];
      final recovered = await reopened.measurementReference(
        reopened.people.single,
      );
      expect(recovered.single['waterMeasure'], 100);
      expect(networkCalls, 0);
      await reopened.lock();
    },
  );
  test(
    'invoice financial inputs and baseline persist offline without issuing a bill',
    () async {
      final store = MemoryStore();
      final session = fixture(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      session.store = store;
      final now = DateTime.now().toUtc();
      session.credentials!['offlineIssued'] = now.toIso8601String();
      session.credentials!['offlineUntil'] = now
          .add(const Duration(hours: 12))
          .toIso8601String();
      await session.reload();
      final billing = {
        'rate': 1000.0,
        'fixedCharge': 500.0,
        'subsidy': 0.1,
        'surcharges': 0.0,
      };
      await expectLater(
        session.saveOnlineReading(7, 25, '', billing: billing),
        throwsStateError,
      );
      expect(store.rows, isEmpty);
      session.people.single.addAll({
        'previousReading': 20,
        'previousMeterId': 9,
        'previousDate': '2026-10-06',
      });
      final result = await session.saveOnlineReading(
        7,
        25,
        'Prueba',
        billing: billing,
      );
      expect(result['kind'], 'local');
      expect(result['billing'], true);
      final saved = jsonDecode(store.rows.single['command'] as String);
      expect(saved['billing'], billing);
      expect(saved['personName'], 'Synthetic');
      expect(saved['previousMeterId'], 9);
      expect(saved['previousReading'], 20);
      await session.sync();
      expect(store.rows.single['status'], 'pending');
      await session.lock();
      expect(store.rows, hasLength(1));
    },
  );
  test(
    'offline measurement persists before network and survives local lock',
    () async {
      final store = MemoryStore();
      final session = fixture(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      session.store = store;
      final now = DateTime.now().toUtc();
      session.credentials!['offlineIssued'] = now.toIso8601String();
      session.credentials!['offlineUntil'] = now
          .add(const Duration(hours: 12))
          .toIso8601String();
      await session.reload();
      session.people.single.addAll({
        'previousReading': 20,
        'previousMeterId': 9,
        'previousDate': '2026-10-06',
      });
      final result = await session.saveOnlineReading(
        7,
        25,
        'Prueba',
        billing: {'rate': 100, 'fixedCharge': 0, 'subsidy': 0, 'surcharges': 0},
      );
      expect(result['kind'], 'local');
      expect(store.rows.single['status'], 'pending');
      await session.sync();
      expect(session.locked, isFalse);
      expect(session.pending, 1);
      await session.lock();
      expect(store.rows, hasLength(1));
      expect(
        jsonDecode(store.rows.single['command'] as String)['waterMeasure'],
        25,
      );
    },
  );
  test(
    'expired local access cannot capture but preserves existing work',
    () async {
      final store = MemoryStore();
      final session = fixture(
        (_) async => throw StateError('No network expected'),
      );
      session.store = store;
      session.credentials!['offlineIssued'] = DateTime.now()
          .subtract(const Duration(hours: 13))
          .toIso8601String();
      session.credentials!['offlineUntil'] = DateTime.now()
          .subtract(const Duration(hours: 1))
          .toIso8601String();
      await session.reload();
      await expectLater(
        session.saveOnlineReading(
          7,
          25,
          '',
          billing: {
            'rate': 100,
            'fixedCharge': 0,
            'subsidy': 0,
            'surcharges': 0,
          },
        ),
        throwsStateError,
      );
      expect(store.rows, isEmpty);
      await session.lock();
    },
  );
}
