import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/published_outbox.dart';

void main() {
  late Map<String, Object?> row;
  late PublishedOutbox engine;
  late bool offline, lostResponse, failMeterRead, changedBaseline;
  late List<String> posts;
  final meter = {
    'id': 10,
    'person': {'id': 7},
    'waterMeasure': 25,
    'readingDate': '2026-10-07',
  };
  final invoice = {
    'id': 100,
    'person': {'id': 7},
    'meter': {'id': 10},
    'amountDue': 5500,
  };
  setUp(() {
    offline = lostResponse = failMeterRead = changedBaseline = false;
    posts = [];
    row = {
      'id': 'invoice-draft',
      'status': 'pending',
      'command': jsonEncode({
        'personId': 7,
        'waterMeasure': 25,
        'readingDate': '2026-10-06',
        'previousMeterId': 9,
        'previousReading': 20,
        'billing': {
          'rate': 1000,
          'fixedCharge': 500,
          'subsidy': 0,
          'surcharges': 0,
        },
      }),
    };
    engine = PublishedOutbox(
      load: () async => [Map.of(row)],
      ensureActive: () {},
      update: (id, status, error) async {
        row['status'] = status;
      },
      rememberInvoice: (id, result) async {
        row['result'] = jsonEncode(result);
      },
      acknowledge: (id, result) async {
        row['status'] = 'confirmed';
        row['result'] = jsonEncode(result);
      },
      request: (method, path, {data}) async {
        final options = RequestOptions(path: path);
        if (offline) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        dynamic value;
        if (method == 'POST') {
          posts.add(path);
          expect(row['status'], 'sending');
          expect(path, '/api/admin/billing/generate');
          expect(data['prevReading'], 20);
          expect(data['currentReading'], 25);
          expect(data['rate'], 1000);
          if (lostResponse) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            );
          }
          value = invoice;
        } else if (path == '/api/meters/by-person/7') {
          value = [
            {
              'id': changedBaseline ? 11 : 9,
              'waterMeasure': 20,
              'readingDate': '2026-10-05',
              'person': {'id': 7},
            },
          ];
        } else if (path == '/api/meters/10') {
          if (failMeterRead) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          value = meter;
        } else if (path == '/api/invoices/100') {
          value = invoice;
        } else {
          fail('Unexpected path: $path');
        }
        return Response(requestOptions: options, data: value);
      },
    );
  });
  test('invoice draft waits offline then sends one combined request', () async {
    offline = true;
    await expectLater(engine.sync(), throwsA(isA<DioException>()));
    expect(row['status'], 'pending');
    expect(posts, isEmpty);
    offline = false;
    await engine.sync();
    await engine.sync();
    expect(posts, ['/api/admin/billing/generate']);
    expect(row['status'], 'confirmed');
    expect(jsonDecode(row['result'] as String)['invoiceId'], 100);
    expect(jsonDecode(row['command'] as String)['readingDate'], '2026-10-06');
  });
  test('changed baseline stops invoice before any mutation', () async {
    changedBaseline = true;
    await engine.sync();
    expect(row['status'], 'conflict');
    expect(posts, isEmpty);
  });
  test('cancelled invoice remains local and is never issued', () async {
    row['status'] = 'cancelled';
    await engine.sync();
    expect(posts, isEmpty);
    expect(row['status'], 'cancelled');
  });
  test(
    'lost billing response never repeats non-idempotent financial POST',
    () async {
      lostResponse = true;
      await expectLater(engine.sync(), throwsA(isA<DioException>()));
      await engine.sync();
      expect(row['status'], 'uncertain');
      expect(posts, hasLength(1));
    },
  );
  test(
    'persisted invoice receipt resumes by GET after interrupted confirmation',
    () async {
      failMeterRead = true;
      await expectLater(engine.sync(), throwsA(isA<DioException>()));
      expect(jsonDecode(row['result'] as String)['invoiceId'], 100);
      failMeterRead = false;
      await engine.sync();
      expect(row['status'], 'confirmed');
      expect(posts, hasLength(1));
    },
  );
}
