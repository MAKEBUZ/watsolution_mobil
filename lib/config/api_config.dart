class ApiConfig {
  static String? _baseUrl;
  static String? _storageOrigin;
  static const railwayProductionOrigin =
      'https://back-production-b5f3.up.railway.app';
  static const awsProductionOrigin =
      'https://api.watsolution.3-142-23-99.sslip.io';

  static Future<void> load({
    String? origin,
    bool preserveRailwayStorage = const bool.fromEnvironment(
      'PRESERVE_RAILWAY_PRODUCTION_STORAGE',
    ),
  }) async {
    // Do not leave a previous configuration usable after a failed load.
    _baseUrl = null;
    _storageOrigin = null;
    var baseUrl = (origin ?? const String.fromEnvironment('API_BASE_URL'))
        .trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError('Se requiere un origen HTTPS válido');
    }
    if (baseUrl.isEmpty) {
      throw Exception('Falta API_BASE_URL en la configuración pública');
    }
    // Asegurar que no termine en /
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    // Enable only after restoring the same production database (including IDs
    // and idempotency records). Keep encrypted data, keys and pending operations
    // in their original namespace; never copy them into an unrelated backend.
    if (preserveRailwayStorage && baseUrl != awsProductionOrigin) {
      throw StateError('La migración local requiere el destino AWS autorizado');
    }
    _baseUrl = baseUrl;
    _storageOrigin = preserveRailwayStorage ? railwayProductionOrigin : baseUrl;
  }

  static String get baseUrl => _baseUrl!;
  static String get storageOrigin => _storageOrigin!;

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
