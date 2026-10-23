import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/config/api_config.dart';
import 'package:watsolution_mobil/field/operation_policy.dart';
import 'offline_capture_test.dart' show MemoryStore;
import 'published_session_test.dart' show fixture, jsonResponse;

class PreparedStore extends MemoryStore {
  List<Map<String, dynamic>> prepared = [];
  @override
  Future<void> replacePeople(List<Map<String, dynamic>> people) async {
    prepared = (jsonDecode(jsonEncode(people)) as List)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> people() async => prepared;
}

void main() {
  setUp(() => ApiConfig.load(origin: 'https://example.invalid'));
  test(
    'preparation obtains references for people never opened, before going offline',
    () async {
      final calls = <String>[];
      final store = PreparedStore();
      final session = fixture((options) async {
        calls.add(options.path);
        if (options.path.contains('/api/people?')) {
          return jsonResponse([
            {'id': 7, 'fullName': 'Person 7'},
            {'id': 8, 'fullName': 'Person 8'},
          ]);
        }
        final id = options.path.endsWith('/7') ? 7 : 8;
        return jsonResponse([
          {
            'id': id * 10,
            'person': {'id': id},
            'waterMeasure': id * 100,
            'readingDate': '2026-10-06',
          },
        ]);
      })..store = store;
      await session.prepare();
      expect(calls.where((p) => p.contains('by-person')), hasLength(2));
      final callCount = calls.length;
      expect(
        (await session.measurementReference(
          session.people.last,
        )).single['waterMeasure'],
        800,
      );
      expect(calls.length, callCount);
      expect(store.prepared.last['previousMeterId'], 80);
      await session.lock();
    },
  );
  test(
    'pricing persists for next session and does not rewrite queued invoices',
    () async {
      final store = MemoryStore();
      final session = fixture(
        (_) async => throw StateError('No network required'),
      )..store = store;
      final now = DateTime.now().toUtc();
      session.credentials!['offlineIssued'] = now.toIso8601String();
      session.credentials!['offlineUntil'] = now
          .add(const Duration(hours: 12))
          .toIso8601String();
      store.rows.add({
        'id': 'old',
        'command': '{"billing":{"rate":50}}',
        'status': 'pending',
      });
      await session.savePricing(100, 500);
      expect(session.error, isNull);
      expect(session.defaultRate, 100);
      expect(store.rows.single['command'], '{"billing":{"rate":50}}');
      await session.lock();
      final reopened = fixture(
        (_) async => throw StateError('No network required'),
      )..store = store;
      await reopened.reload();
      expect(reopened.defaultRate, 100);
      expect(reopened.defaultFixedCharge, 500);
      await reopened.lock();
    },
  );
  test(
    'failed reference download preserves the previous complete local preparation',
    () async {
      final store = PreparedStore()
        ..prepared = [
          {
            'id': 99,
            'fullName': 'Previous',
            'previousMeterId': 1,
            'previousReading': 100,
          },
        ];
      final session = fixture((options) async {
        if (options.path.contains('/api/people?')) {
          return jsonResponse([
            {'id': 7, 'fullName': 'Person 7'},
            {'id': 8, 'fullName': 'Person 8'},
          ]);
        }
        if (options.path.endsWith('/7')) return jsonResponse([]);
        return jsonResponse({}, 503);
      })..store = store;
      await expectLater(session.prepare(), throwsException);
      expect(store.prepared.single['id'], 99);
      await session.lock();
    },
  );
  test('cancelled rows are terminal and do not count as pending', () {
    expect(isPendingOperation('cancelled'), isFalse);
    expect(isPendingOperation('uncertain'), isTrue);
    expect(isPendingOperation('pending'), isTrue);
  });
}
