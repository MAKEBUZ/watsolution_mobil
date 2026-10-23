import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/config/api_config.dart';
import 'published_session_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() async {
    storage.clear();
    await ApiConfig.load(origin: 'https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final key = call.arguments['key'] as String;
          switch (call.method) {
            case 'containsKey':
              return storage.containsKey(key);
            case 'read':
              return storage[key];
            case 'write':
              storage[key] = call.arguments['value'];
              return null;
            case 'delete':
              storage.remove(key);
              return null;
            default:
              throw StateError('Unexpected secure-storage method');
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'uncertain submission survives session recreation and prevents another POST',
    () async {
      var writes = 0;
      Future<ResponseBody> response(RequestOptions options) async {
        if (options.method == 'POST') {
          writes++;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        if (options.path.contains('/api/people/')) {
          return fixtures.jsonResponse({
            'id': 7,
            'address': {'id': 9},
          });
        }
        return fixtures.jsonResponse([
          {'id': 3, 'waterMeasure': 20, 'readingDate': '2026-01-01'},
        ]);
      }

      final first = fixtures.fixture(response)
        ..people = [
          {'id': 7, 'fullName': 'Synthetic'},
        ];
      await expectLater(
        first.saveOnlineReading(
          7,
          21,
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
      expect(writes, 1);
      expect(storage.length, 1);
      await first.lock();
      final second = fixtures.fixture(response)
        ..people = [
          {'id': 7, 'fullName': 'Synthetic'},
        ];
      await expectLater(
        second.saveOnlineReading(
          7,
          21,
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
      expect(writes, 1);
      await second.lock();
    },
  );
  test(
    'new measurement without invoice is rejected before any network mutation',
    () async {
      var calls = 0;
      final session = fixtures.fixture((_) async {
        calls++;
        return fixtures.jsonResponse({});
      });
      session.people = [
        {'id': 7, 'fullName': 'Synthetic'},
      ];
      await expectLater(session.saveOnlineReading(7, 21, ''), throwsStateError);
      expect(calls, 0);
      await session.lock();
    },
  );

  test(
    'confirmed submission clears its guard only after parsing a valid response',
    () async {
      final session =
          fixtures.fixture((options) async {
              if (options.method == 'POST') {
                return fixtures.jsonResponse({
                  'id': 4,
                  'amountDue': 100,
                  ...Map<String, dynamic>.from(options.data),
                });
              }
              if (options.path.contains('/api/people/')) {
                return fixtures.jsonResponse({
                  'id': 7,
                  'address': {'id': 9},
                });
              }
              return fixtures.jsonResponse([
                {'id': 3, 'waterMeasure': 20, 'readingDate': '2026-01-01'},
              ]);
            })
            ..people = [
              {'id': 7, 'fullName': 'Synthetic'},
            ];
      expect(
        (await session.saveOnlineReading(
          7,
          21,
          '',
          billing: {
            'rate': 100,
            'fixedCharge': 0,
            'subsidy': 0,
            'surcharges': 0,
          },
        ))['id'],
        4,
      );
      expect(storage, isEmpty);
      expect(session.busy, isFalse);
      await session.lock();
    },
  );
}
