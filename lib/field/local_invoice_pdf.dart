import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'billing_calculation.dart';

String operationPersonName(Map command, Iterable<Map> people) {
  final saved = command['personName']?.toString().trim() ?? '';
  if (saved.isNotEmpty) return saved;
  for (final person in people) {
    if (person['id'] == command['personId']) {
      final name = person['fullName']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
    }
  }
  return 'Nombre no disponible · ID ${command['personId']}';
}

Future<Uint8List> buildLocalInvoicePdf(Map command, String name) async {
  final billing = command['billing'] as Map;
  final summary = BillingCalculation(
    previous: command['previousReading'] as num,
    current: command['waterMeasure'] as num,
    rate: billing['rate'] as num,
    fixedCharge: billing['fixedCharge'] as num,
    subsidy: billing['subsidy'] as num,
    surcharges: billing['surcharges'] as num,
  );
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text(
          'WatSolution',
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Comprobante de medición',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Gracias por cuidar el agua. Conserva este comprobante de tu lectura.',
        ),
        pw.SizedBox(height: 20),
        pw.Text('Persona: $name'),
        pw.Text('Fecha de captura: ${command['readingDate']}'),
        pw.Text('Referencia local: ${command['operationId']}'),
        pw.SizedBox(height: 20),
        for (final entry in <String, String>{
          'Medición anterior':
              '${quantity(command['previousReading'] as num)} m³',
          'Medición nueva': '${quantity(command['waterMeasure'] as num)} m³',
          'Consumo': '${quantity(summary.consumption)} m³',
          'Precio por m³': cop(billing['rate'] as num),
          'Cargo por consumo': cop(summary.consumptionCharge),
          'Tarifa fija': cop(summary.fixedCharge),
          'Descuento': cop(summary.discount),
          'Cargos adicionales': cop(summary.additionalCharges),
          'Total estimado': cop(summary.total),
        }.entries)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text('${entry.key}: ${entry.value}'),
          ),
      ],
    ),
  );
  return document.save();
}

Future<bool> saveLocalInvoicePdf(Map command, String name) async {
  final bytes = await buildLocalInvoicePdf(command, name);
  return await const MethodChannel('watsolution/documents').invokeMethod<bool>(
        'savePdf',
        {'bytes': bytes, 'name': 'Comprobante de medición.pdf'},
      ) ??
      false;
}
