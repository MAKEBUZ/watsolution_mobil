import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../landing_page/landing_page.dart';
import '../../services/api/auth_service.dart';
import '../../services/api/invoice_service.dart';
import '../../services/api/meter_service.dart';
import '../../utils/invoice_pdf.dart';

class HomePageFunctions {
  static Future<void> logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
    }
  }

  /// Trae las facturas (invoices) más recientes del backend.
  /// Cada invoice incluye meter y person anidados.
  static Future<List<Map<String, dynamic>>> fetchRecentInvoices() async {
    try {
      // Pedir las facturas ordenadas por id descendente y tomar las 10 más recientes
      final invoices = await InvoiceService.instance.getAll(size: 10, sort: 'id,desc');
      final typed = invoices.cast<Map<String, dynamic>>();
      return typed;
    } catch (e) {
      print('Error obteniendo facturas recientes: $e');
      return [];
    }
  }

  /// Backwards compat
  static Future<List<Map<String, dynamic>>> fetchRecentMeters() async {
    try {
      final meters = await MeterService.instance.getAll(size: 20);
      final typed = meters.cast<Map<String, dynamic>>();
      typed.sort((a, b) {
        final dateA = DateTime.tryParse((a['readingDate'] ?? a['reading_date'] ?? '').toString()) ?? DateTime(1970);
        final dateB = DateTime.tryParse((b['readingDate'] ?? b['reading_date'] ?? '').toString()) ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      return typed;
    } catch (e) {
      print('Error obteniendo medidores recientes: $e');
      return [];
    }
  }

  static Stream<List<Map<String, dynamic>>> streamRecentMeters() async* {
    while (true) {
      yield await fetchRecentInvoices();
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  /// Descargar factura. Si tiene pdfUrl en el backend, usa el endpoint de download.
  /// Si no tiene pdfUrl (factura creada desde app móvil), genera PDF localmente.
  static Future<bool> downloadInvoice(BuildContext context, Map<String, dynamic> invoice) async {
    final invoiceId = invoice['id'] as int?;
    final pdfUrl = invoice['pdfUrl'] ?? invoice['pdf_url'];

    // 1. Si hay pdfUrl en el backend, obtener URL pre-firmada y abrir
    if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
      try {
        if (invoiceId == null) return false;
        final url = await InvoiceService.instance.getDownloadUrl(invoiceId);
        final ok = await launchUrlString(url, webOnlyWindowName: '_blank');
        return ok;
      } catch (e) {
        // Fallo el backend, intentar generar local
      }
    }

    // 2. Generar PDF localmente
    try {
      final meter = invoice['meter'] as Map<String, dynamic>?;
      final person = invoice['person'] as Map<String, dynamic>?;
      if (meter == null || person == null) {
        throw Exception('Datos incompletos para generar factura');
      }

      final address = person['address'] as Map<String, dynamic>?;

      final pdfBytes = await buildInvoicePdf(InvoiceData(
        person: person,
        meter: meter,
        address: address,
        invoice: invoice,
      ));

      // Guardar en directorio temporal
      final tempDir = Directory.systemTemp;
      final fileName = 'factura_${invoiceId ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      // Intentar abrir
      final ok = await launchUrlString('file://${file.path}', webOnlyWindowName: '_blank');
      if (!ok) {
        // Si no se puede abrir directamente, mostrar mensaje con ruta
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Factura guardada en: ${file.path}')),
          );
        }
      }
      return ok;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generando factura: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  static Future<bool> openInvoice(String invoicePath) async {
    final ok = await launchUrlString(invoicePath, webOnlyWindowName: '_blank');
    return ok;
  }
}
