import '../../config/api_config.dart';
import 'api_service.dart';

class AddressService {
  static final AddressService instance = AddressService._init();
  final ApiService _api = ApiService.instance;

  AddressService._init();

  Future<Map<String, dynamic>> getAll({int page = 0, int size = 20}) async {
    final response = await _api.client.get(
      ApiConfig.addresses,
      queryParameters: {'page': page, 'size': size},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getById(int id) async {
    final response = await _api.client.get('${ApiConfig.addresses}/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await _api.client.post(ApiConfig.addresses, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> data) async {
    final response = await _api.client.put(ApiConfig.addresses, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateById(int id, Map<String, dynamic> data) async {
    final response = await _api.client.put('${ApiConfig.addresses}/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(int id) async {
    await _api.client.delete('${ApiConfig.addresses}/$id');
  }
}
