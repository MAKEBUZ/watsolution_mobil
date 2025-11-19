import 'unified_database_service.dart';

class OfflineInitializer {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('Inicializando base de datos offline...');
      
      // Inicializar el servicio unificado
      final unifiedService = UnifiedDatabaseService.instance;
      
      // Cargar datos iniciales desde el servidor si hay conexión
      await unifiedService.loadDataFromServer();
      
      _initialized = true;
      print('Base de datos offline inicializada exitosamente');
    } catch (e) {
      print('Error inicializando base de datos offline: $e');
      // No lanzar error para que la app pueda funcionar sin offline
    }
  }

  static Future<void> syncData() async {
    try {
      final unifiedService = UnifiedDatabaseService.instance;
      await unifiedService.syncData();
      print('Datos sincronizados exitosamente');
    } catch (e) {
      print('Error sincronizando datos: $e');
      rethrow;
    }
  }
}