import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import 'api_service.dart';

class PersonService {
  static final PersonService instance = PersonService._init();
  final ApiService _api = ApiService.instance;

  PersonService._init();

  /// GET /api/people - Listar personas (devuelve array plano PersonDTO[], metadata en headers)
  Future<List<dynamic>> getAll({int page = 0, int size = 20}) async {
    final response = await _api.client.get(
      ApiConfig.people,
      queryParameters: {'page': page, 'size': size},
    );
    return response.data as List<dynamic>;
  }

  /// GET /api/people/me - Obtener persona vinculada al usuario autenticado
  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await _api.client.get('${ApiConfig.people}/me');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /api/people/:id
  Future<Map<String, dynamic>> getById(int id) async {
    final response = await _api.client.get('${ApiConfig.people}/$id');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/people - Crear persona con dirección y usuario de auth
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await _api.client.post(ApiConfig.people, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// PUT /api/people - Actualizar persona
  Future<Map<String, dynamic>> update(Map<String, dynamic> data) async {
    final response = await _api.client.put(ApiConfig.people, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// PUT /api/people/:id - Actualizar persona por ID
  Future<Map<String, dynamic>> updateById(int id, Map<String, dynamic> data) async {
    final response = await _api.client.put('${ApiConfig.people}/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// DELETE /api/people/:id
  Future<void> delete(int id) async {
    await _api.client.delete('${ApiConfig.people}/$id');
  }
}
