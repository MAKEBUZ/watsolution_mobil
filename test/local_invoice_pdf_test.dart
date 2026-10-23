import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/local_invoice_pdf.dart';

void main() {
  test(
    'stored name survives cache replacement; old operations use matching person',
    () {
      expect(
        operationPersonName({'personId': 4, 'personName': 'Ana Gómez'}, []),
        'Ana Gómez',
      );
      expect(
        operationPersonName(
          {'personId': 4},
          [
            {'id': 5, 'fullName': 'Otra persona'},
            {'id': 4, 'fullName': 'Ana Gómez'},
          ],
        ),
        'Ana Gómez',
      );
      expect(
        operationPersonName({'personId': 4}, []),
        contains('Nombre no disponible'),
      );
    },
  );
  test('offline invoice creates PDF from saved financial values', () async {
    final bytes = await buildLocalInvoicePdf({
      'operationId': 'synthetic-operation',
      'readingDate': '2026-10-08',
      'previousReading': 100,
      'waterMeasure': 110,
      'billing': {
        'rate': 100,
        'fixedCharge': 500,
        'subsidy': 0,
        'surcharges': 0,
      },
    }, 'Ana Gómez');
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
