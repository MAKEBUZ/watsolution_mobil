import '../../config/api_config.dart';
import 'api_service.dart';

class NewsService {
  static final NewsService instance = NewsService._init();
  final ApiService _api = ApiService.instance;

  NewsService._init();

  /// GET /api/public/noticias - Listar noticias activas (sin autenticación)
  Future<List<dynamic>> getPublicNews() async {
    final response = await _api.client.get(ApiConfig.noticiasPublic);
    return response.data as List<dynamic>;
  }
}
