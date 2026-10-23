import 'package:dio/dio.dart';
import '../../config/api_config.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  late final Dio _dio;
  String? _legacyMemoryToken;

  ApiService._init() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (DioException e, handler) {
        if (e.response != null) {
        }
        handler.next(e);
      },
    ));
  }

  Dio get client => _dio;

  String? _getToken() {
    return _legacyMemoryToken;
  }

  Future<void> setToken(String token) async {
    _legacyMemoryToken = token;
  }

  Future<void> clearToken() async {
    _legacyMemoryToken = null;
  }

  String? get currentToken => _getToken();

  bool get isAuthenticated {
    final token = _getToken();
    return token != null && token.isNotEmpty;
  }
}
