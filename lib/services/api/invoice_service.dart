import '../../config/api_config.dart';
import 'api_service.dart';

class InvoiceService {
  static final InvoiceService instance = InvoiceService._init();
  final ApiService _api = ApiService.instance;

  InvoiceService._init();

  /// GET /api/invoices - devuelve array plano InvoiceDTO[]
  Future<List<dynamic>> getAll({int page = 0, int size = 20}) async {
    final response = await _api.client.get(
      ApiConfig.invoices,
      queryParameters: {'page': page, 'size': size},
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getByPersonId(int personId) async {
    final response = await _api.client.get('${ApiConfig.invoices}/by-person/$personId');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getById(int id) async {
    final response = await _api.client.get('${ApiConfig.invoices}/$id');
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/invoices/download/:id - Obtener URL pre-firmada para descargar PDF
  /// El backend devuelve { url: string }
  Future<String> getDownloadUrl(int id) async {
    final response = await _api.client.get('${ApiConfig.invoices}/download/$id');
    final data = response.data as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('La factura no tiene PDF disponible');
    }
    return url;
  }

  /// POST /api/invoices/:id/generate-pdf - Generar PDF y subir a S3
  Future<Map<String, dynamic>> generatePdf(int id) async {
    final response = await _api.client.post('${ApiConfig.invoices}/$id/generate-pdf');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await _api.client.post(ApiConfig.invoices, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> data) async {
    final response = await _api.client.put(ApiConfig.invoices, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateById(int id, Map<String, dynamic> data) async {
    final response = await _api.client.put('${ApiConfig.invoices}/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(int id) async {
    await _api.client.delete('${ApiConfig.invoices}/$id');
  }
}
