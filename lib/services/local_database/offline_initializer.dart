import 'unified_database_service.dart';

class OfflineInitializer {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      
      // Inicializar el servicio unificado
      final unifiedService = UnifiedDatabaseService.instance;
      
      // Cargar datos iniciales desde el servidor si hay conexión
      await unifiedService.loadDataFromServer();
      
      _initialized = true;
    } catch (e) {
      // No lanzar error para que la app pueda funcionar sin offline
    }
  }

  static Future<void> syncData() async {
    try {
      final unifiedService = UnifiedDatabaseService.instance;
      await unifiedService.syncData();
    } catch (e) {
      rethrow;
    }
  }
}