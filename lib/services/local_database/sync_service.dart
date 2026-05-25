import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import 'models/local_models.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Connectivity _connectivity = Connectivity();

  SyncService._init();

  // Verificar conectividad a internet
  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // Sincronizar todos los datos pendientes
  Future<void> syncAllData() async {
    if (!await isOnline()) {
      print('Sin conexión a internet, sincronización cancelada');
      return;
    }

    try {
      print('Iniciando sincronización...');
      
      // Sincronizar personas
      await _syncPeople();
      
      // Sincronizar medidores
      await _syncMeters();
      
      // Sincronizar cola de operaciones
      await _syncQueue();
      
      print('Sincronización completada exitosamente');
    } catch (e) {
      print('Error durante la sincronización: $e');
      rethrow;
    }
  }

  // Sincronizar personas pendientes
  Future<void> _syncPeople() async {
    try {
      final pendingPeople = await _dbHelper.getPeoplePendingSync();
      print('Sincronizando ${pendingPeople.length} personas...');

      for (final person in pendingPeople) {
        await _syncPerson(person);
      }
    } catch (e) {
      print('Error sincronizando personas: $e');
      rethrow;
    }
  }

  // Sincronizar una persona individual
  Future<void> _syncPerson(LocalPerson person) async {
    try {
      final client = Supabase.instance.client;
      
      // Si la persona tiene un server_id, es una actualización
      if (person.serverId != null) {
        // Actualizar en Supabase
        await client
            .from('people')
            .update({
              'full_name': person.fullName,
              'document_number': person.documentNumber,
              'phone': person.phone,
              'email': person.email,
              'status': person.status,
            })
            .eq('id', person.serverId!);
        
        // Actualizar estado de sincronización
        await _dbHelper.updatePersonSyncStatus(person.id!, 'synced');
      } else {
        // Crear nueva persona en Supabase
        
        // Primero crear la dirección si existe
        int? addressId;
        if (person.addressId != null) {
          final address = await _dbHelper.getAddressById(person.addressId!);
          if (address != null) {
            final addrResult = await client
                .from('addresses')
                .insert({
                  'neighborhood': address.neighborhood,
                  'street': address.street,
                  'house_number': address.houseNumber,
                  'city': address.city,
                })
                .select('id')
                .single();
            addressId = addrResult['id'] as int;
          }
        }

        // Crear persona en Supabase
        final result = await client
            .from('people')
            .insert({
              'full_name': person.fullName,
              'document_number': person.documentNumber,
              'phone': person.phone,
              'email': person.email,
              'status': person.status,
              'address_id': addressId,
            })
            .select('id')
            .single();
        
        final serverId = result['id'] as int;
        
        // Actualizar estado de sincronización con server_id
        await _dbHelper.updatePersonSyncStatus(person.id!, 'synced', serverId: serverId);
      }
      
      print('Persona sincronizada: ${person.fullName}');
    } catch (e) {
      print('Error sincronizando persona ${person.fullName}: $e');
      // Marcar como error de sincronización
      await _dbHelper.updatePersonSyncStatus(person.id!, 'error');
      rethrow;
    }
  }

  // Sincronizar medidores pendientes
  Future<void> _syncMeters() async {
    try {
      final pendingMeters = await _dbHelper.getMetersPendingSync();
      print('Sincronizando ${pendingMeters.length} medidores...');

      for (final meter in pendingMeters) {
        await _syncMeter(meter);
      }
    } catch (e) {
      print('Error sincronizando medidores: $e');
      rethrow;
    }
  }

  // Sincronizar un medidor individual
  Future<void> _syncMeter(LocalMeter meter) async {
    try {
      final client = Supabase.instance.client;
      
      // Obtener la persona asociada para obtener el server_id
      final person = await _dbHelper.getPersonById(meter.peopleId);
      if (person == null || person.serverId == null) {
        print('Persona no encontrada o no sincronizada para medidor');
        return;
      }

      // Crear medidor en Supabase
      final result = await client
          .from('meters')
          .insert({
            'people_id': person.serverId,
            'water_measure': meter.waterMeasure,
            'reading_date': meter.readingDate.toIso8601String(),
            'observation': meter.observation,
            'invoice_path': meter.invoicePath,
          })
          .select('id')
          .single();
      
      final serverId = result['id'] as int;
      
      // Actualizar estado de sincronización con server_id
      await _dbHelper.updateMeterSyncStatus(meter.id!, 'synced', serverId: serverId);
      
      print('Medidor sincronizado para: ${person.fullName}');
    } catch (e) {
      print('Error sincronizando medidor: $e');
      // Marcar como error de sincronización
      await _dbHelper.updateMeterSyncStatus(meter.id!, 'error');
      rethrow;
    }
  }

  // Sincronizar cola de operaciones
  Future<void> _syncQueue() async {
    try {
      final pendingItems = await _dbHelper.getPendingSyncItems();
      print('Sincronizando ${pendingItems.length} operaciones pendientes...');

      for (final item in pendingItems) {
        await _processSyncQueueItem(item);
      }
    } catch (e) {
      print('Error procesando cola de sincronización: $e');
      rethrow;
    }
  }

  // Procesar un item de la cola de sincronización
  Future<void> _processSyncQueueItem(SyncQueueItem item) async {
    try {
      final client = Supabase.instance.client;
      final data = json.decode(item.data);

      switch (item.operation) {
        case 'insert':
          await client.from(item.tableName).insert(data);
          break;
        case 'update':
          await client.from(item.tableName).update(data).eq('id', data['id']);
          break;
        case 'delete':
          await client.from(item.tableName).delete().eq('id', data['id']);
          break;
      }

      // Eliminar item procesado
      await _dbHelper.deleteSyncQueueItem(item.id!);
      
      print('Operación ${item.operation} en ${item.tableName} sincronizada');
    } catch (e) {
      print('Error procesando item de cola: $e');
      rethrow;
    }
  }

  // Agregar operación a la cola de sincronización
  Future<void> addToSyncQueue(String tableName, String operation, Map<String, dynamic> data) async {
    final item = SyncQueueItem(
      tableName: tableName,
      localId: data['id'] ?? 0,
      operation: operation,
      data: json.encode(data),
      createdAt: DateTime.now(),
    );
    
    await _dbHelper.insertSyncQueueItem(item);
    
    // Intentar sincronizar inmediatamente si hay conexión
    if (await isOnline()) {
      try {
        await syncAllData();
      } catch (e) {
        print('Error en sincronización automática: $e');
      }
    }
  }

  // Cargar datos desde Supabase a la base de datos local
  Future<void> syncFromServer() async {
    if (!await isOnline()) {
      print('Sin conexión a internet, no se pueden cargar datos del servidor');
      return;
    }

    try {
      print('Cargando datos desde el servidor...');
      final client = Supabase.instance.client;

      // Obtener personas del servidor
      final peopleResponse = await client.from('people').select('''
        *,
        addresses(*)
      ''');

      for (final personData in peopleResponse) {
        await _saveServerPersonToLocal(personData);
      }

      print('Datos del servidor cargados exitosamente');
    } catch (e) {
      print('Error cargando datos del servidor: $e');
      rethrow;
    }
  }

  // Guardar persona del servidor en base de datos local
  Future<void> _saveServerPersonToLocal(Map<String, dynamic> personData) async {
    try {
      // Guardar dirección si existe
      int? addressId;
      if (personData['addresses'] != null) {
        final addressData = personData['addresses'];
        final address = LocalAddress(
          serverId: addressData['id'],
          neighborhood: addressData['neighborhood'] ?? '',
          street: addressData['street'],
          houseNumber: addressData['house_number'],
          city: addressData['city'] ?? '',
          syncStatus: 'synced',
        );
        addressId = await _dbHelper.insertAddress(address);
      }

      // Guardar persona
      final person = LocalPerson(
        serverId: personData['id'],
        fullName: personData['full_name'] ?? '',
        documentNumber: personData['document_number'] ?? '',
        phone: personData['phone'],
        email: personData['email'],
        status: personData['status'] ?? 'active',
        addressId: addressId,
        syncStatus: 'synced',
      );

      await _dbHelper.insertPerson(person);
    } catch (e) {
      print('Error guardando persona del servidor: $e');
      rethrow;
    }
  }

  // Limpiar base de datos local
  Future<void> clearLocalData() async {
    final db = await _dbHelper.database;
    await db.delete('meters');
    await db.delete('people');
    await db.delete('addresses');
    await db.delete('sync_queue');
    print('Base de datos local limpiada');
  }
}