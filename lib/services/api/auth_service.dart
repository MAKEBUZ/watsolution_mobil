import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final ApiService _api = ApiService.instance;

  AuthService._init();

  /// Login con username/password contra /api/authenticate
  /// Retorna el JWT token
  Future<String> login({required String username, required String password}) async {
    try {
      final response = await _api.client.post(
        ApiConfig.authenticate,
        data: {
          'username': username,
          'password': password,
        },
      );

      final token = response.data['id_token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Token no recibido del servidor');
      }

      await _api.setToken(token);
      return token;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Credenciales inválidas');
      }
      throw Exception('Error de login: ${e.message}');
    } catch (e) {
      throw Exception('Error de login: $e');
    }
  }

  /// Registro de nuevo usuario contra /api/register
  Future<void> register({
    required String login,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String langKey = 'es',
  }) async {
    try {
      await _api.client.post(
        ApiConfig.register,
        data: {
          'login': login,
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'langKey': langKey,
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Error de registro: $message');
    } catch (e) {
      throw Exception('Error de registro: $e');
    }
  }

  /// Obtener datos del usuario autenticado /api/account
  Future<Map<String, dynamic>> getAccount() async {
    try {
      final response = await _api.client.get(ApiConfig.account);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesión expirada');
      }
      throw Exception('Error obteniendo cuenta: ${e.message}');
    } catch (e) {
      throw Exception('Error obteniendo cuenta: $e');
    }
  }

  /// Actualizar información del usuario /api/account
  Future<void> updateAccount(Map<String, dynamic> data) async {
    try {
      await _api.client.post(ApiConfig.account, data: data);
    } on DioException catch (e) {
      throw Exception('Error actualizando cuenta: ${e.message}');
    } catch (e) {
      throw Exception('Error actualizando cuenta: $e');
    }
  }

  /// Cambiar contraseña /api/account/change-password
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      await _api.client.post(
        '${ApiConfig.account}/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw Exception('Error cambiando contraseña: ${e.message}');
    } catch (e) {
      throw Exception('Error cambiando contraseña: $e');
    }
  }

  /// Cerrar sesión
  Future<void> logout() async {
    await _api.clearToken();
  }

  bool get isLoggedIn => _api.isAuthenticated;
}
