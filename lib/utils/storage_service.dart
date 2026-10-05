import '../services/api/invoice_service.dart';

class StorageService {
  /// Obtener URL pre-firmada para descargar una factura PDF desde S3 (vía backend)
  static Future<String> getInvoiceDownloadUrl(int invoiceId) async {
    return await InvoiceService.instance.getDownloadUrl(invoiceId);
  }
}
