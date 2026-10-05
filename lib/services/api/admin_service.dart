import '../../config/api_config.dart';
import 'api_service.dart';

class AdminService {
  static final AdminService instance = AdminService._init();
  final ApiService _api = ApiService.instance;

  AdminService._init();

  /// GET /api/admin/stats
  Future<Map<String, dynamic>> getStats() async {
    final response = await _api.client.get(ApiConfig.adminStats);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/admin/dashboard
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _api.client.get(ApiConfig.adminDashboard);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/admin/activity?limit=
  Future<List<dynamic>> getActivity({int limit = 20}) async {
    final response = await _api.client.get(
      ApiConfig.adminActivity,
      queryParameters: {'limit': limit},
    );
    return response.data as List<dynamic>;
  }

  /// GET /api/admin/users-with-status
  Future<List<dynamic>> getUsersWithStatus() async {
    final response = await _api.client.get('${ApiConfig.baseUrl}/api/admin/users-with-status');
    return response.data as List<dynamic>;
  }

  /// POST /api/admin/billing/generate
  Future<Map<String, dynamic>> generateBilling(Map<String, dynamic> data) async {
    final response = await _api.client.post(ApiConfig.adminBillingGenerate, data: data);
    return response.data as Map<String, dynamic>;
  }
}
