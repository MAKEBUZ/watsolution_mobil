import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String? _baseUrl;

  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
    _baseUrl = dotenv.env['API_BASE_URL']?.trim();
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw Exception('API_BASE_URL falta o está vacío en .env');
    }
    // Asegurar que no termine en /
    if (_baseUrl!.endsWith('/')) {
      _baseUrl = _baseUrl!.substring(0, _baseUrl!.length - 1);
    }
  }

  static String get baseUrl => _baseUrl!;

  static String get authenticate => '$baseUrl/api/authenticate';
  static String get register => '$baseUrl/api/register';
  static String get account => '$baseUrl/api/account';
  static String get addresses => '$baseUrl/api/addresses';
  static String get people => '$baseUrl/api/people';
  static String get meters => '$baseUrl/api/meters';
  static String get invoices => '$baseUrl/api/invoices';
  static String get noticiasPublic => '$baseUrl/api/public/noticias';
  static String get adminStats => '$baseUrl/api/admin/stats';
  static String get adminDashboard => '$baseUrl/api/admin/dashboard';
  static String get adminActivity => '$baseUrl/api/admin/activity';
  static String get adminBillingGenerate => '$baseUrl/api/admin/billing/generate';
  static String get boldHash => '$baseUrl/api/bold/hash';
  static String get boldWebhook => '$baseUrl/api/bold/webhook';
  static String get boldResult => '$baseUrl/api/bold/result';
}
