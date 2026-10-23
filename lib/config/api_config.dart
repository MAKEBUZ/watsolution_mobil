class ApiConfig {
  static String? _baseUrl;
  static String? _storageOrigin;
  static const productionStorage = 'watsolution-production-v1';
  static const awsProductionOrigin =
      'https://api.watsolution.3-142-23-99.sslip.io';

  static Future<void> load({String? origin}) async {
    // Do not leave a previous configuration usable after a failed load.
    _baseUrl = null;
    _storageOrigin = null;
    var baseUrl =
        (origin ??
                const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: awsProductionOrigin,
                ))
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
    _baseUrl = baseUrl;
    _storageOrigin = baseUrl == awsProductionOrigin
        ? productionStorage
        : baseUrl;
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
