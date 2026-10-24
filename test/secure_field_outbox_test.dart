import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/secure_field_outbox.dart';

void main() {
  Map<String, dynamic> command() => {
    'operationId': '343ac377-8f2b-49d2-bf5c-3c4dd3a3c5dc',
    'personId': 7,
    'personName': 'Synthetic private name',
    'previousMeterId': 8,
    'previousReading': 100,
    'waterMeasure': 110,
    'readingDate': '2026-10-23',
    'observation': '',
    'billing': {
      'rate': 100,
      'fixedCharge': 5000,
      'subsidy': 0,
      'surcharges': 0,
    },
  };
  test(
    'lost acknowledgement retries same operation and retains original until confirmed',
    () async {
      final original = jsonEncode(command());
      final row = <String, Object?>{
        'id': command()['operationId'],
        'command': original,
        'status': 'pending',
      };
      var requests = 0;
      final ids = <String>[];
      final outbox = SecureFieldOutbox(
        load: () async => [row],
        ensureActive: () {},
        claim: (_) async {
          row['transport'] = 'field-v2';
          row['status'] = 'sending';
          return true;
        },
        update: (_, state, message) async {
          row['status'] = state;
        },
        acknowledge: (_, result) async {
          row['status'] = 'confirmed';
          row['result'] = jsonEncode(result);
        },
        request: (method, path, {data}) async {
          expect(path, '/api/mobile/capture-billing');
          expect(data.containsKey('personName'), false);
          expect(data.containsKey('previousReading'), false);
          ids.add(data['operationId']);
          requests++;
          if (requests == 1) {
            throw DioException(
              requestOptions: RequestOptions(),
              type: DioExceptionType.connectionError,
            );
          }
          return Response(
            requestOptions: RequestOptions(),
            data: {
              'operationId': data['operationId'],
              'personId': 7,
              'meterId': 9,
              'waterMeasure': 110,
              'readingDate': '2026-10-23',
              'invoiceId': 22,
              'amountDue': 6000,
            },
          );
        },
      );
      await expectLater(outbox.sync(), throwsA(isA<DioException>()));
      expect(row['status'], 'retry');
      expect(row['command'], original);
      await outbox.sync();
      expect(row['status'], 'confirmed');
      expect(ids.toSet().length, 1);
      expect(row['command'], original);
    },
  );
  test('old uncertain invoice is retained without blind POST', () async {
    final row = <String, Object?>{
      'id': command()['operationId'],
      'command': jsonEncode(command()),
      'status': 'uncertain',
    };
    final outbox = SecureFieldOutbox(
      load: () async => [row],
      ensureActive: () {},
      claim: (_) async => throw StateError('Must not claim legacy uncertainty'),
      update: (_, state, message) async {
        expect(state, 'uncertain');
      },
      acknowledge: (_, result) async => fail('Must not acknowledge'),
      request: (_, __, {data}) async => throw StateError('Must not request'),
    );
    await outbox.sync();
    expect(jsonDecode(row['command'] as String), command());
  });
  test('cancelled claim does not submit a reading', () async {
    final outbox = SecureFieldOutbox(
      load: () async => [
        {
          'id': command()['operationId'],
          'command': jsonEncode(command()),
          'status': 'pending',
        },
      ],
      ensureActive: () {},
      claim: (_) async => false,
      update: (_, __, ___) async {},
      acknowledge: (_, __) async => fail('Cancelled'),
      request: (_, __, {data}) async => throw StateError('Cancelled'),
    );
    await outbox.sync();
  });
}
