import '../../config/api_config.dart';
import 'api_service.dart';

class MeterService {
  static final MeterService instance = MeterService._init();
  final ApiService _api = ApiService.instance;

  MeterService._init();

  /// GET /api/meters - Listar lecturas (devuelve array plano MeterDTO[], metadata en headers)
  Future<List<dynamic>> getAll({int page = 0, int size = 20, String sort = 'readingDate,desc'}) async {
    final query = <String, dynamic>{'page': page, 'size': size};
    if (sort.isNotEmpty) query['sort'] = sort;
    final response = await _api.client.get(
      ApiConfig.meters,
      queryParameters: query,
    );
    return response.data as List<dynamic>;
  }

  /// GET /api/meters/by-person/:personId (devuelve array plano MeterDTO[])
  Future<List<dynamic>> getByPersonId(int personId) async {
    final response = await _api.client.get('${ApiConfig.meters}/by-person/$personId');
    return response.data as List<dynamic>;
  }

  /// GET /api/meters/:id
  Future<Map<String, dynamic>> getById(int id) async {
    final response = await _api.client.get('${ApiConfig.meters}/$id');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/meters - Crear lectura
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await _api.client.post(ApiConfig.meters, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// PUT /api/meters - Actualizar lectura
  Future<Map<String, dynamic>> update(Map<String, dynamic> data) async {
    final response = await _api.client.put(ApiConfig.meters, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// PUT /api/meters/:id - Actualizar lectura por ID
  Future<Map<String, dynamic>> updateById(int id, Map<String, dynamic> data) async {
    final response = await _api.client.put('${ApiConfig.meters}/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// DELETE /api/meters/:id
  Future<void> delete(int id) async {
    await _api.client.delete('${ApiConfig.meters}/$id');
  }
}
