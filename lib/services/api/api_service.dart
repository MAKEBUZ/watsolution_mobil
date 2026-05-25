import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/api_config.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  late final Dio _dio;

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
        print('[API] ${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('[API] ${response.statusCode} ${response.requestOptions.path}');
        handler.next(response);
      },
      onError: (DioException e, handler) {
        print('[API ERROR] ${e.requestOptions.method} ${e.requestOptions.path} -> ${e.message}');
        if (e.response != null) {
          print('[API ERROR BODY] ${e.response?.data}');
        }
        handler.next(e);
      },
    ));
  }

  Dio get client => _dio;

  String? _getToken() {
    final box = Hive.box('app');
    return box.get('jwt_token') as String?;
  }

  Future<void> setToken(String token) async {
    final box = Hive.box('app');
    await box.put('jwt_token', token);
  }

  Future<void> clearToken() async {
    final box = Hive.box('app');
    await box.delete('jwt_token');
  }

  String? get currentToken => _getToken();

  bool get isAuthenticated {
    final token = _getToken();
    return token != null && token.isNotEmpty;
  }
}
