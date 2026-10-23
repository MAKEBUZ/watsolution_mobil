import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/field_session.dart';
import 'package:watsolution_mobil/field/published_work.dart';

void main() {
  final invoice = <String, dynamic>{
    'id': 12,
    'person': {'id': 7, 'fullName': 'Prueba'},
    'meter': {'id': 9},
    'amountDue': '1500',
    'consumptionM3': '10',
    'ratePerM3': '100',
    'fixedCharge': '500',
    'subsidyPercent': '0',
    'additionalCharges': '0',
  };
  PublishedWork work(Map<String, dynamic> bill, {int personId = 7}) =>
      PublishedWork(
        (method, path, {data}) async => Response(
          requestOptions: RequestOptions(path: path),
          data: path.startsWith('/api/invoices/')
              ? bill
              : {
                  'id': 9,
                  'person': {'id': personId},
                  'waterMeasure': '110',
                  'readingDate': '2026-10-14',
                },
        ),
      );
  test(
    'history receipt uses billed consumption and exact associated meter',
    () async {
      final result = await work(invoice).invoiceReceipt(12);
      expect(result['previousReading'], 100);
      expect(result['waterMeasure'], 110);
      expect(result['personName'], 'Prueba');
      expect((result['billing'] as Map)['rate'], 100);
    },
  );
  test(
    'cannot invent missing historical tariffs or mix customer readings',
    () async {
      await expectLater(
        work({...invoice, 'ratePerM3': null}).invoiceReceipt(12),
        throwsStateError,
      );
      await expectLater(
        work(invoice, personId: 8).invoiceReceipt(12),
        throwsFormatException,
      );
      await expectLater(
        work({...invoice, 'amountDue': 9999}).invoiceReceipt(12),
        throwsStateError,
      );
    },
  );
  test(
    'confirmed operations leave queue but retain receipt without network',
    () async {
      final session = FieldSession()
        ..locked = false
        ..credentials = {
          'authorities': ['ROLE_ADMIN'],
        }
        ..operations = [
          {
            'id': 'done',
            'status': 'confirmed',
            'result': jsonEncode({'invoiceId': 12}),
            'command': jsonEncode({
              'personId': 7,
              'personName': 'Nombre guardado',
              'billing': {'rate': 100},
            }),
          },
          {'id': 'pending', 'status': 'pending'},
          {'id': 'review', 'status': 'uncertain'},
          {'id': 'cancelled', 'status': 'cancelled'},
        ];
      expect(session.pendingOperations.map((o) => o['id']), [
        'pending',
        'review',
      ]);
      expect(
        (await session.invoiceReceipt(12))['personName'],
        'Nombre guardado',
      );
      expect(session.operations, hasLength(4));
      session.locked = true;
      await expectLater(session.invoiceReceipt(12), throwsStateError);
      session.dispose();
    },
  );
}
