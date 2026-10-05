import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoiceData {
  final Map<String, dynamic> person;
  final Map<String, dynamic> meter;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? invoice;
  InvoiceData({required this.person, required this.meter, this.address, this.invoice});
}

Future<Uint8List> buildInvoicePdf(InvoiceData data) async {
  final doc = pw.Document();

  String fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  String addressLabel(Map<String, dynamic>? a) {
    if (a == null) return 'Sin dirección';
    final neighborhood = (a['neighborhood'] ?? '').toString().trim();
    final street = (a['street'] ?? '').toString().trim();
    final house = (a['houseNumber'] ?? a['house_number'] ?? '').toString().trim();
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
  final inv = data.invoice;

  // Soporte camelCase y snake_case
  final personName = (p['fullName'] ?? p['full_name'] ?? '').toString();
  final personDoc = (p['documentNumber'] ?? p['document_number'] ?? '').toString();
  final subscriberNumber = (p['subscriberNumber'] ?? p['subscriber_number'] ?? '').toString();
  
  final meterId = m['id']?.toString() ?? '—';
  final readingDate = fmtDate((m['readingDate'] ?? m['reading_date'] ?? '').toString());
  final waterMeasure = (m['waterMeasure'] ?? m['water_measure'])?.toString() ?? '—';
  final observation = (m['observation'] ?? '').toString();
  final addrText = addressLabel(a);

  // Helper para parsear números que el backend envía como String
  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Datos de factura
  final invoiceId = inv?['id']?.toString() ?? meterId;
  final issueDate = fmtDate((inv?['issueDate'] ?? inv?['issue_date'] ?? '').toString());
  final dueDate = fmtDate((inv?['dueDate'] ?? inv?['due_date'] ?? '').toString());
  final consumptionM3Val = parseDouble(inv?['consumptionM3'] ?? inv?['consumption_m_3']);
  final ratePerM3Val = parseDouble(inv?['ratePerM3'] ?? inv?['rate_per_m3']);
  final fixedChargeVal = parseDouble(inv?['fixedCharge'] ?? inv?['fixed_charge']);
  final subsidyPercentVal = parseDouble(inv?['subsidyPercent'] ?? inv?['subsidy_percent']);
  final additionalChargesVal = parseDouble(inv?['additionalCharges'] ?? inv?['additional_charges']);
  final amountDueVal = parseDouble(inv?['amountDue'] ?? inv?['amount_due']);

  final consumptionM3 = consumptionM3Val.toStringAsFixed(2);
  final ratePerM3 = ratePerM3Val.toStringAsFixed(2);
  final fixedCharge = fixedChargeVal.toStringAsFixed(2);
  final subsidyPercent = subsidyPercentVal.toStringAsFixed(2);
  final additionalCharges = additionalChargesVal.toStringAsFixed(2);
  final amountDue = amountDueVal;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('WatSolution', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text('Factura de Servicio de Agua', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('N° Factura: $invoiceId', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Fecha emisión: $issueDate', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('Vence: $dueDate', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Cliente', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('Nombre: ${personName.isEmpty ? '—' : personName}'),
                  pw.Text('Documento: ${personDoc.isEmpty ? '—' : personDoc}'),
                  if (subscriberNumber.isNotEmpty) pw.Text('N° Suscriptor: $subscriberNumber'),
                  pw.Text('Dirección: $addrText'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Detalle de Medición', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('Fecha de lectura: $readingDate'),
                  pw.Text('Medición actual (m³): $waterMeasure'),
                  if (observation.isNotEmpty) pw.Text('Observación: $observation'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Detalle de Facturación', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _tableRow('Consumo (m³)', consumptionM3),
                      _tableRow('Tarifa por m³', '\$ $ratePerM3'),
                      _tableRow('Cargo fijo', '\$ $fixedCharge'),
                      if (double.tryParse(subsidyPercent) != null && double.parse(subsidyPercent) > 0)
                        _tableRow('Subsidio (${(double.parse(subsidyPercent) * 100).toStringAsFixed(0)}%)', '-\$ ${(double.parse(consumptionM3) * double.parse(ratePerM3) * double.parse(subsidyPercent)).toStringAsFixed(2)}'),
                      if (double.tryParse(additionalCharges) != null && double.parse(additionalCharges) > 0)
                        _tableRow('Cargos adicionales', '\$ $additionalCharges'),
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('TOTAL A PAGAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('\$ ${amountDue.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Center(
              child: pw.Text('Generado por WatSolution - Sistema de Gestión de Agua', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ),
          ],
        );
      },
    ),
  );

  return await doc.save();
}

pw.TableRow _tableRow(String label, String value) {
  return pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(label),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );
}
