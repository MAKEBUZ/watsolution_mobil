import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:watsolution_mobil/config/api_config.dart';
import 'package:watsolution_mobil/field/field_session.dart';

class FixtureAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) response;
  FixtureAdapter(this.response);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => response(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object value, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

FieldSession fixture(Future<ResponseBody> Function(RequestOptions) response) {
  final session = FieldSession()
    ..onlineOnly = true
    ..locked = false
    ..credentials = {
      'id': '2',
      'login': 'synthetic',
      'authorities': ['ROLE_ADMIN'],
      'id_token': 'synthetic',
    };
  session.api.httpClientAdapter = FixtureAdapter(response);
  return session;
}

void main() {
  test(
    'prepared previous measurement is displayed without any network call',
    () async {
      final session = fixture(
        (_) async => throw StateError('Network must not be used'),
      );
      final person = <String, dynamic>{
        'id': 7,
        'fullName': 'Synthetic',
        'previousMeterId': 8,
        'previousReading': 100,
        'previousDate': '2026-10-06',
      };
      session.people = [person];
      final rows = await session.measurementReference(person);
      expect(rows.single['waterMeasure'], 100);
      expect(rows.single['readingDate'], '2026-10-06');
      await session.lock();
    },
  );
  test(
    'missing previous measurement is retrieved and used as invoice reference',
    () async {
      final session = fixture(
        (_) async => jsonResponse([
          {
            'id': 8,
            'waterMeasure': 100,
            'readingDate': '2026-10-06',
            'person': {'id': 7},
          },
        ]),
      );
      final person = <String, dynamic>{'id': 7, 'fullName': 'Synthetic'};
      session.people = [person];
      await session.measurementReference(person);
      expect(person['previousReading'], 100);
      expect(person['previousMeterId'], 8);
      await session.lock();
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  test('connection loss preserves account and prepared people', () async {
    final session = fixture(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    session.people = [
      {'id': 7, 'fullName': 'Synthetic'},
    ];
    await session.verifyOnlineSession();
    expect(session.locked, isFalse);
    expect(session.people, isNotEmpty);
    expect(session.credentials, isNotNull);
    await session.lock();
  });
  test('loss of online authorization clears personal data', () async {
    final session = fixture((_) async => jsonResponse({}, 401));
    session.people = [
      {'id': 7, 'fullName': 'Synthetic'},
    ];
    await session.verifyOnlineSession();
    expect(session.locked, isTrue);
    expect(session.people, isEmpty);
    expect(session.credentials, isNull);
  });
  test(
    'history requires an available person and discards unrelated fields',
    () async {
      await ApiConfig.load(origin: 'https://example.invalid');
      var calls = 0;
      final session = fixture((options) async {
        calls++;
        expect(options.path, endsWith('/api/meters/by-person/7'));
        return jsonResponse([
          {
            'waterMeasure': '21.50',
            'readingDate': '2026-10-01',
            'observation': 'private',
          },
        ]);
      });
      await expectLater(session.readingHistory(7), throwsStateError);
      expect(calls, 0);
      session.people = [
        {'id': 7, 'fullName': 'Synthetic'},
      ];
      final rows = await session.readingHistory(7);
      expect(rows.single, {'waterMeasure': 21.5, 'readingDate': '2026-10-01'});
      await session.lock();
    },
  );
  setUp(() => ApiConfig.load(origin: 'https://example.invalid'));
  test(
    'published queries retain only minimal fields and do not prepare offline',
    () async {
      final session = fixture((options) async {
        expect(options.path, contains('/api/people?'));
        expect(options.method, 'GET');
        return jsonResponse([
          {
            'id': 7,
            'fullName': 'Synthetic',
            'email': 'private@example.invalid',
          },
        ]);
      });
      await session.prepare();
      expect(session.people.single.containsKey('email'), isFalse);
      expect(session.preparedAt, isNull);
      expect(session.store, isNull);
      await session.lock();
    },
  );
  test('operators never fall back to the global subscriber listing', () async {
    var calls = 0;
    final session = fixture((_) async {
      calls++;
      return jsonResponse([]);
    });
    session.credentials!['authorities'] = ['ROLE_OPERATOR'];
    await expectLater(session.prepare(), throwsStateError);
    expect(calls, 0);
    await session.lock();
  });
  test(
    'late personal response after locking cannot restore visible data',
    () async {
      final pending = Completer<ResponseBody>();
      final requested = Completer<void>();
      final session = fixture((_) {
        requested.complete();
        return pending.future;
      });
      final prepare = session.prepare();
      final rejected = expectLater(prepare, throwsStateError);
      await requested.future;
      await session.lock();
      pending.complete(
        jsonResponse([
          {'id': 7, 'fullName': 'Synthetic'},
        ]),
      );
      await rejected;
      expect(session.people, isEmpty);
      expect(session.credentials, isNull);
    },
  );
  test('failed second page preserves the previous complete snapshot', () async {
    var calls = 0;
    final session = fixture((_) async {
      calls++;
      if (calls == 2) return jsonResponse({'error': 'synthetic'}, 503);
      return jsonResponse(
        List.generate(100, (i) => {'id': i + 1, 'fullName': 'Synthetic $i'}),
      );
    });
    session.people = [
      {'id': 500, 'fullName': 'Previous snapshot'},
    ];
    await expectLater(session.prepare(), throwsA(isA<DioException>()));
    expect(session.people.single['id'], 500);
    await session.lock();
  });
  test(
    'expired published access never calls an absent refresh route',
    () async {
      final calls = <String>[];
      final session = fixture((options) async {
        calls.add(options.path);
        return jsonResponse({}, 401);
      });
      await expectLater(session.prepare(), throwsA(isA<DioException>()));
      expect(calls.length, 1);
      expect(calls.single, contains('/api/people?'));
      await session.lock();
    },
  );
}
