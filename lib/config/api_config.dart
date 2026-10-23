class ApiConfig {
  static String? _baseUrl;

  static Future<void> load({String? origin}) async {
    _baseUrl = (origin ?? const String.fromEnvironment('API_BASE_URL')).trim();
    final uri = Uri.tryParse(_baseUrl!);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError('Se requiere un origen HTTPS válido');
    }
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw Exception('Falta API_BASE_URL en la configuración pública');
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
  static String get adminBillingGenerate =>
      '$baseUrl/api/admin/billing/generate';
  static String get boldHash => '$baseUrl/api/bold/hash';
  static String get boldWebhook => '$baseUrl/api/bold/webhook';
  static String get boldResult => '$baseUrl/api/bold/result';
}
