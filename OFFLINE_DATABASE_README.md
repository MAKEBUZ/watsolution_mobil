# Sistema de Base de Datos Offline para Watsolution

## Descripción

Este sistema implementa una base de datos SQLite local que permite que la aplicación funcione sin conexión a internet y sincronice automáticamente los datos cuando se recupera la conexión.

## Características

- ✅ **Funcionamiento Offline**: La aplicación funciona completamente sin conexión a internet
- ✅ **Sincronización Automática**: Los datos se sincronizan automáticamente cuando hay conexión
- ✅ **Detección de Conectividad**: Sistema automático para detectar cambios en la conectividad
- ✅ **Cola de Sincronización**: Las operaciones pendientes se encolan para sincronización posterior
- ✅ **Datos Locales**: Almacenamiento local de todos los datos críticos
- ✅ **Interfaz Unificada**: Misma interfaz para operaciones online y offline

## Estructura del Sistema

```
lib/services/local_database/
├── database_helper.dart          # Helper principal de SQLite
├── sync_service.dart             # Servicio de sincronización con Supabase
├── unified_database_service.dart # Servicio unificado (online/offline)
├── offline_initializer.dart      # Inicialización del sistema offline
└── models/
    └── local_models.dart         # Modelos de datos locales
```

## Uso

### 1. Inicialización

El sistema se inicializa automáticamente al iniciar la aplicación en `main.dart`:

```dart
await OfflineInitializer.initialize();
```

### 2. Uso del Servicio Unificado

Para usar el sistema offline, simplemente reemplaza las llamadas directas a Supabase con el servicio unificado:

```dart
// Antes (solo online)
final response = await Supabase.instance.client
    .from('people')
    .select()
    .order('full_name');

// Ahora (online y offline)
final people = await UnifiedDatabaseService.instance.getPeople();
```

### 3. Crear Usuarios

```dart
final result = await UnifiedDatabaseService.instance.createPerson(
  fullName: 'Juan Pérez',
  documentNumber: '12345678',
  phone: '555-1234',
  email: 'juan@example.com',
  neighborhood: 'Centro',
  street: 'Calle Principal',
  houseNumber: '123',
  city: 'Ciudad',
);
```

### 4. Crear Mediciones

```dart
await UnifiedDatabaseService.instance.createMeter(
  personId: personId,
  waterMeasure: 150.5,
  readingDate: DateTime.now(),
  observation: 'Lectura mensual',
);
```

### 5. Obtener Mediciones

```dart
final meters = await UnifiedDatabaseService.instance.getMetersByPersonId(personId);
```

### 6. Sincronización Manual

```dart
// Sincronizar todos los datos pendientes
await UnifiedDatabaseService.instance.syncData();

// Cargar datos desde el servidor
await UnifiedDatabaseService.instance.loadDataFromServer();
```

## Indicadores de Estado

La interfaz muestra claramente el estado de conexión:

- 🟢 **Online**: Con conexión a internet, datos sincronizados
- 🔴 **Offline**: Sin conexión, datos guardados localmente

## Flujo de Trabajo

### Modo Online
1. Los datos se leen y escriben directamente en Supabase
2. Se mantiene una copia local para uso offline
3. La sincronización es inmediata

### Modo Offline
1. Los datos se leen y escriben en la base de datos local SQLite
2. Las operaciones se encolan para sincronización
3. Al recuperar la conexión, se sincronizan automáticamente

### Sincronización
1. Se ejecuta cada 5 minutos automáticamente
2. Se puede ejecutar manualmente desde la interfaz
3. Sincroniza personas y mediciones pendientes
4. Maneja conflictos de forma inteligente

## Modelos de Datos

### Persona Local
```dart
LocalPerson {
  id: int?                    // ID local
  serverId: int?             // ID en Supabase
  fullName: String           // Nombre completo
  documentNumber: String     // Número de documento
  phone: String?             // Teléfono
  email: String?             // Email
  status: String             // Estado (active/inactive)
  addressId: int?             // ID de dirección
  syncStatus: String         // pending/synced/error
  createdAt: DateTime?        // Fecha de creación
  updatedAt: DateTime?       // Última actualización
}
```

### Medidor Local
```dart
LocalMeter {
  id: int?                    // ID local
  serverId: int?              // ID en Supabase
  peopleId: int               // ID de la persona
  waterMeasure: double         // Medición de agua
  readingDate: DateTime      // Fecha de lectura
  observation: String?        // Observaciones
  invoicePath: String?        // Ruta de factura
  syncStatus: String          // pending/synced/error
  createdAt: DateTime?        // Fecha de creación
  updatedAt: DateTime?       // Última actualización
}
```

## Configuración

### Dependencias

Las siguientes dependencias se agregaron a `pubspec.yaml`:

```yaml
dependencies:
  sqflite: ^2.3.0          # Base de datos SQLite
  connectivity_plus: ^4.0.1 # Detección de conectividad
  path: ^1.8.3              # Manejo de rutas de archivos
```

### Permisos

No se requieren permisos adicionales para el funcionamiento offline.

## Solución de Problemas

### Error de Sincronización
- Verifica la conexión a internet
- Revisa los logs de sincronización
- Intenta sincronización manual desde la interfaz

### Base de Datos Corrupta
- La aplicación recreará la base de datos si detecta corrupción
- Los datos del servidor se sincronizarán nuevamente

### Conflictos de Datos
- El sistema prioriza los datos más recientes
- Se mantiene un historial de cambios

## Mejores Prácticas

1. **Siempre usa el servicio unificado** en lugar de llamadas directas a Supabase
2. **Maneja errores de sincronización** mostrando mensajes al usuario
3. **Indica el estado de conexión** claramente en la interfaz
4. **Sincroniza manualmente** después de períodos prolongados offline
5. **Prueba en ambos modos** (online y offline) durante el desarrollo

## Futuras Mejoras

- [ ] Sincronización selectiva por usuario
- [ ] Resolución de conflictos manual
- [ ] Compresión de datos para sincronización
- [ ] Backup automático de base de datos local
- [ ] Estadísticas de uso offline