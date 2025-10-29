import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoiceData {
  final Map<String, dynamic> person;
  final Map<String, dynamic> meter;
  final Map<String, dynamic>? address;
  InvoiceData({required this.person, required this.meter, this.address});
}

Future<Uint8List> buildInvoicePdf(InvoiceData data) async {
  final doc = pw.Document();

  String fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String addressLabel(Map<String, dynamic>? a) {
    if (a == null) return 'Sin dirección';
    final neighborhood = (a['neighborhood'] ?? '').toString().trim();
    final street = (a['street'] ?? '').toString().trim();
    final house = (a['house_number'] ?? '').toString().trim();
    final city = (a['city'] ?? '').toString().trim();
    final left = [neighborhood, street, house].where((p) => p.isNotEmpty).join(' ');
    if (left.isNotEmpty && city.isNotEmpty) {
      return '$left, $city';
    }
    return left.isNotEmpty ? left : (city.isNotEmpty ? city : 'Sin dirección');
  }

  final p = data.person;
  final m = data.meter;
  final a = data.address;

  final personName = (p['full_name'] ?? '').toString();
  final personDoc = (p['document_number'] ?? '').toString();
  final meterId = m['id']?.toString() ?? '—';
  final readingDate = fmtDate((m['reading_date'] ?? '').toString());
  final waterMeasure = m['water_measure']?.toString() ?? '—';
  final observation = (m['observation'] ?? '').toString();
  final addrText = addressLabel(a);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Factura de servicio', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('N°: $meterId'),
            pw.SizedBox(height: 16),
            pw.Text('Cliente', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Nombre: ${personName.isEmpty ? '—' : personName}'),
            pw.Text('Documento: ${personDoc.isEmpty ? '—' : personDoc}'),
            pw.Text('Dirección: $addrText'),
            pw.SizedBox(height: 16),
            pw.Text('Detalle de medición', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Fecha de lectura: $readingDate'),
            pw.Text('Medición de agua (m³): $waterMeasure'),
            if (observation.isNotEmpty) pw.Text('Observación: $observation'),
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Generado por WatSolution', style: const pw.TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    ),
  );

  return await doc.save();
}