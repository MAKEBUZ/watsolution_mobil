import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/published_work.dart';

Response<dynamic> response(dynamic value) => Response(
  data: value,
  statusCode: 200,
  requestOptions: RequestOptions(path: '/synthetic'),
);

void main() {
  test(
    'measurement creates one meter with the server person/address and no invoice',
    () async {
      final posts = <String>[];
      final work = PublishedWork((method, path, {data}) async {
        if (path.contains('by-person')) {
          return response([
            {'id': 3, 'waterMeasure': '20.00', 'readingDate': '2026-01-01'},
          ]);
        }
        if (path == '/api/people/7') {
          return response({
            'id': 7,
            'address': {'id': 9},
          });
        }
        posts.add(path);
        expect(data['person'], {'id': 7});
        expect(data['address'], {'id': 9});
        return response({'id': 4, ...data});
      });
      final result = await work.save(
        personId: 7,
        measure: 21,
        observation: 'Test',
      );
      expect(result['id'], 4);
      expect(posts, ['/api/meters']);
    },
  );
  test(
    'billing uses one canonical call without first creating another meter',
    () async {
      final posts = <String>[];
      final work = PublishedWork((method, path, {data}) async {
        if (method == 'GET') {
          return response([
            {'id': 3, 'waterMeasure': 20, 'readingDate': '2026-01-01'},
          ]);
        }
        posts.add(path);
        expect(data['prevReading'], 20);
        expect(data['currentReading'], 25);
        expect(data['personId'], 7);
        return response({
          'id': 12,
          'amountDue': '5100.00',
          'status': 'PENDING',
        });
      });
      final result = await work.save(
        personId: 7,
        measure: 25,
        observation: '',
        billing: {
          'rate': 1000,
          'fixedCharge': 100,
          'subsidy': 0,
          'surcharges': 0,
        },
      );
      expect(result['kind'], 'invoice');
      expect(posts, ['/api/admin/billing/generate']);
    },
  );
  test(
    'decreasing values and missing billing baseline never issue a POST',
    () async {
      var posts = 0;
      var initial = false;
      final work = PublishedWork((method, path, {data}) async {
        if (method == 'POST') posts++;
        return response(
          initial
              ? []
              : [
                  {'id': 3, 'waterMeasure': 20, 'readingDate': '2026-01-01'},
                ],
        );
      });
      await expectLater(
        work.save(personId: 7, measure: 19, observation: ''),
        throwsStateError,
      );
      initial = true;
      await expectLater(
        work.save(
          personId: 7,
          measure: 20,
          observation: '',
          billing: {'rate': 1, 'fixedCharge': 1, 'subsidy': 0, 'surcharges': 0},
        ),
        throwsStateError,
      );
      expect(posts, 0);
    },
  );
  test('lost write response does not cause an automatic second POST', () async {
    var posts = 0;
    final work = PublishedWork((method, path, {data}) async {
      if (method == 'GET') {
        return response([
          {'id': 3, 'waterMeasure': 20, 'readingDate': '2026-01-01'},
        ]);
      }
      posts++;
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.receiveTimeout,
      );
    });
    await expectLater(
      work.save(
        personId: 7,
        measure: 21,
        observation: '',
        billing: {'rate': 1, 'fixedCharge': 1, 'subsidy': 0, 'surcharges': 0},
      ),
      throwsA(isA<DioException>()),
    );
    expect(posts, 1);
  });
  test(
    'downloads request the authorized endpoint and reject unsafe URLs',
    () async {
      var url = 'http://example.invalid/invoice.pdf';
      final work = PublishedWork((method, path, {data}) async {
        expect(method, 'GET');
        expect(path, '/api/invoices/download/12');
        return response({'url': url});
      });
      await expectLater(work.invoiceDownload(12), throwsFormatException);
      url = 'https://example.invalid/invoice.pdf?signature=synthetic';
      expect((await work.invoiceDownload(12)).scheme, 'https');
      url = 'https://user:password@example.invalid/private';
      await expectLater(work.invoiceDownload(12), throwsFormatException);
    },
  );
}
