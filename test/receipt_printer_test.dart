import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/receipt_printer.dart';

void main() {
  final command = {
    'personId': 4,
    'operationId': '12345678-1234-1234-1234-123456789abc',
    'readingDate': '2026-10-14',
    'previousReading': 100,
    'waterMeasure': 110,
    'billing': {'rate': 100, 'fixedCharge': 500, 'subsidy': 0, 'surcharges': 0},
  };
  test('receipt uses saved readings and tariffs, fits narrow paper', () {
    final lines = receiptLines(
      command,
      'María Fernández de los Nombres Muy Largos',
    );
    expect(lines, contains('María Fernández de los Nombres Muy Largos'));
    expect(lines, contains('Conserva este comprobante de tu lectura.'));
    expect(lines.join('\n'), contains('Consumo: 10 m³'));
    expect(lines.join(' '), contains(r'TOTAL ESTIMADO: $1.500 COP'));
    expect(lines.join(' '), contains('Gracias por cuidar el agua.'));
    expect(lines.join(''), contains(command['operationId']));
  });
  test('untrusted names cannot introduce printer control characters', () {
    final lines = receiptLines(command, 'Nombre\x1b@\nOtro');
    expect(
      lines.any((line) => RegExp(r'[\x00-\x1f\x7f]').hasMatch(line)),
      isFalse,
    );
  });
  test('invalid baseline cannot produce a receipt', () {
    expect(
      () => receiptLines({...command, 'waterMeasure': 90}, 'Prueba'),
      throwsStateError,
    );
  });
}
