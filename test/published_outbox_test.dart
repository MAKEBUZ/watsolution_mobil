import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/published_outbox.dart';

void main() {
  late Map<String, Object?> row;
  late List<Map<String, dynamic>> remote;
  late int posts;
  late bool failAfterCommit, offline, failPersistence, wrongAck;
  late PublishedOutbox engine;
  setUp(() {
    row = {
      'id': 'test-uuid',
      'status': 'pending',
      'command': jsonEncode({
        'personId': 7,
        'waterMeasure': 25,
        'readingDate': '2026-10-06',
        'observation': 'Prueba',
      }),
    };
    remote = [];
    posts = 0;
    failAfterCommit = offline = failPersistence = wrongAck = false;
    engine = PublishedOutbox(
      load: () async => [Map.of(row)],
      ensureActive: () {},
      update: (id, status, error) async {
        if (failPersistence) throw StateError('Disk unavailable');
        row['status'] = status;
      },
      acknowledge: (id, result) async {
        row['status'] = 'confirmed';
        row['result'] = result;
      },
      request: (method, path, {data}) async {
        final options = RequestOptions(path: path);
        if (offline) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        if (method == 'POST') {
          posts++;
          expect(row['status'], 'sending');
          expect(data['readingDate'], '2026-10-06');
          final saved = <String, dynamic>{
            ...data as Map<String, dynamic>,
            'id': 10,
          };
          remote.add(saved);
          if (failAfterCommit) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return Response(
            requestOptions: options,
            data: wrongAck ? {...saved, 'waterMeasure': 999} : saved,
          );
        }
        return Response(
          requestOptions: options,
          data: path.contains('by-person')
              ? remote
              : {
                  'id': 7,
                  'address': {'id': 2},
                },
        );
      },
    );
  });
  test(
    'offline keeps pending and reconnect posts original reading once',
    () async {
      offline = true;
      await expectLater(engine.sync(), throwsA(isA<DioException>()));
      expect(row['status'], 'pending');
      expect(posts, 0);
      offline = false;
      await engine.sync();
      await engine.sync();
      expect(row['status'], 'confirmed');
      expect(posts, 1);
    },
  );
  test('cancelled records never post when connection returns', () async {
    row['status'] = 'cancelled';
    await engine.sync();
    expect(posts, 0);
    expect(row['status'], 'cancelled');
  });
  test(
    'lost ACK reconciles marker without posting again after restart',
    () async {
      failAfterCommit = true;
      await expectLater(engine.sync(), throwsA(isA<DioException>()));
      expect(row['status'], 'uncertain');
      row['status'] = 'sending'; // persisted state after process death
      await engine.sync();
      expect(row['status'], 'confirmed');
      expect(posts, 1);
    },
  );
  test(
    'unresolved result never retries even if remote history is empty',
    () async {
      row['status'] = 'sending';
      await engine.sync();
      await engine.sync();
      expect(row['status'], 'uncertain');
      expect(posts, 0);
    },
  );
  test('newer remote reading becomes conflict without sending', () async {
    remote.add({
      'id': 9,
      'waterMeasure': 30,
      'readingDate': '2026-10-07',
      'person': {'id': 7},
    });
    await engine.sync();
    expect(row['status'], 'conflict');
    expect(posts, 0);
  });
  test('persisting intent is required before any network mutation', () async {
    failPersistence = true;
    await expectLater(engine.sync(), throwsStateError);
    expect(posts, 0);
  });
  test(
    'mismatched confirmation stays uncertain rather than confirmed',
    () async {
      wrongAck = true;
      await expectLater(engine.sync(), throwsFormatException);
      expect(row['status'], 'uncertain');
    },
  );
}
