import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import 'sync_service.dart';
import 'models/local_models.dart';

class UnifiedDatabaseService {
  static final UnifiedDatabaseService instance = UnifiedDatabaseService._init();
  final DatabaseHelper _localDb = DatabaseHelper.instance;
  final SyncService _syncService = SyncService.instance;
  
  Timer? _syncTimer;

  // Getter público para acceso al servicio de sincronización
  SyncService get syncService => _syncService;

  UnifiedDatabaseService._init() {
    // Iniciar sincronización periódica cada 5 minutos
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await syncData();
    });
  }

  // Método para obtener personas (usa local si está offline, cloud si está online)
  Future<List<Map<String, dynamic>>> getPeople() async {
    try {
      if (await _syncService.isOnline()) {
        // Si está online, usar Supabase
        final client = Supabase.instance.client;
        final response = await client
            .from('people')
            .select('''
              *,
              addresses(*)
            ''')
            .order('full_name');
        
        // Guardar en local para uso offline
        await _savePeopleToLocal(response.cast<Map<String, dynamic>>());
        
        return response;
      } else {
        // Si está offline, usar base de datos local
        final localPeople = await _localDb.getAllPeople();
        return localPeople.map((person) => _localPersonToMap(person)).toList();
      }
    } catch (e) {
      print('Error obteniendo personas: $e');
      // Si hay error, intentar con datos locales
      final localPeople = await _localDb.getAllPeople();
      return localPeople.map((person) => _localPersonToMap(person)).toList();
    }
  }

  // Método para crear persona
  Future<Map<String, dynamic>?> createPerson({
    required String fullName,
    required String documentNumber,
    String? phone,
    String? email,
    String? neighborhood,
    String? street,
    String? houseNumber,
    required String city,
  }) async {
    try {
      if (await _syncService.isOnline()) {
        // Crear en Supabase
        final client = Supabase.instance.client;
        
        // Crear dirección primero
        final addrResult = await client
            .from('addresses')
            .insert({
              'neighborhood': neighborhood,
              'street': street,
              'house_number': houseNumber,
              'city': city,
            })
            .select('id')
            .single();
        
        final addressId = addrResult['id'] as int;
        
        // Crear persona
        final personResult = await client
            .from('people')
            .insert({
              'full_name': fullName,
              'document_number': documentNumber,
              'phone': phone,
              'email': email,
              'status': 'active',
              'address_id': addressId,
            })
            .select('''
              *,
              addresses(*)
            ''')
            .single();
        
        // Guardar copia local
        await _savePersonToLocal(personResult);
        
        return personResult;
      } else {
        // Crear en base de datos local
        
        // Crear dirección local
        final localAddress = LocalAddress(
          neighborhood: neighborhood ?? '',
          street: street,
          houseNumber: houseNumber,
          city: city,
          syncStatus: 'pending',
        );
        final addressId = await _localDb.insertAddress(localAddress);
        
        // Crear persona local
        final localPerson = LocalPerson(
          fullName: fullName,
          documentNumber: documentNumber,
          phone: phone,
          email: email,
          status: 'active',
          addressId: addressId,
          syncStatus: 'pending',
        );
        final personId = await _localDb.insertPerson(localPerson);
        
        // Agregar a cola de sincronización
        await _syncService.addToSyncQueue('addresses', 'insert', localAddress.toMap());
        await _syncService.addToSyncQueue('people', 'insert', localPerson.copyWith(id: personId).toMap());
        
        return _localPersonToMap(localPerson.copyWith(id: personId));
      }
    } catch (e) {
      print('Error creando persona: $e');
      rethrow;
    }
  }

  // Método para obtener medidores de una persona
  Future<List<Map<String, dynamic>>> getMetersByPersonId(int personId) async {
    try {
      if (await _syncService.isOnline()) {
        // Obtener de Supabase
        final client = Supabase.instance.client;
        
        // Primero obtener el server_id de la persona
        final localPerson = await _localDb.getPersonById(personId);
        if (localPerson?.serverId == null) {
          return [];
        }
        
        final response = await client
            .from('meters')
            .select()
            .eq('people_id', localPerson!.serverId!)
            .order('reading_date', ascending: false);
        
        // Guardar en local
        await _saveMetersToLocal(response.cast<Map<String, dynamic>>(), personId);
        
        return response;
      } else {
        // Obtener de base de datos local
        final localMeters = await _localDb.getMetersByPersonId(personId);
        return localMeters.map((meter) => _localMeterToMap(meter)).toList();
      }
    } catch (e) {
      print('Error obteniendo medidores: $e');
      // Si hay error, intentar con datos locales
      final localMeters = await _localDb.getMetersByPersonId(personId);
      return localMeters.map((meter) => _localMeterToMap(meter)).toList();
    }
  }

  // Método para crear medidor
  Future<Map<String, dynamic>?> createMeter({
    required int personId,
    required double waterMeasure,
    required DateTime readingDate,
    String? observation,
    String? invoicePath,
  }) async {
    try {
      if (await _syncService.isOnline()) {
        // Crear en Supabase
        final client = Supabase.instance.client;
        
        // Obtener el server_id de la persona
        final localPerson = await _localDb.getPersonById(personId);
        if (localPerson?.serverId == null) {
          throw Exception('Persona no sincronizada con el servidor');
        }
        
        final result = await client
            .from('meters')
            .insert({
              'people_id': localPerson!.serverId!,
              'water_measure': waterMeasure,
              'reading_date': readingDate.toIso8601String(),
              'observation': observation,
              'invoice_path': invoicePath,
            })
            .select()
            .single();
        
        // Guardar copia local
        await _saveMeterToLocal(result, personId);
        
        return result;
      } else {
        // Crear en base de datos local
        final localMeter = LocalMeter(
          peopleId: personId,
          waterMeasure: waterMeasure,
          readingDate: readingDate,
          observation: observation,
          invoicePath: invoicePath,
          syncStatus: 'pending',
        );
        final meterId = await _localDb.insertMeter(localMeter);
        
        // Agregar a cola de sincronización
        await _syncService.addToSyncQueue('meters', 'insert', localMeter.copyWith(id: meterId).toMap());
        
        return _localMeterToMap(localMeter.copyWith(id: meterId));
      }
    } catch (e) {
      print('Error creando medidor: $e');
      rethrow;
    }
  }

  // Método para sincronizar datos manualmente
  Future<void> syncData() async {
    await _syncService.syncAllData();
  }

  // Método para cargar datos del servidor
  Future<void> loadDataFromServer() async {
    await _syncService.syncFromServer();
  }

  // Métodos auxiliares para conversión
  Map<String, dynamic> _localPersonToMap(LocalPerson person) {
    return {
      'id': person.serverId ?? person.id,
      'full_name': person.fullName,
      'document_number': person.documentNumber,
      'phone': person.phone,
      'email': person.email,
      'status': person.status,
      'address_id': person.addressId,
      'addresses': person.addressId != null ? _getAddressMap(person.addressId!) : null,
    };
  }

  Map<String, dynamic> _localMeterToMap(LocalMeter meter) {
    return {
      'id': meter.serverId ?? meter.id,
      'people_id': meter.peopleId,
      'water_measure': meter.waterMeasure,
      'reading_date': meter.readingDate.toIso8601String(),
      'observation': meter.observation,
      'invoice_path': meter.invoicePath,
    };
  }

  Future<Map<String, dynamic>?> _getAddressMap(int addressId) async {
    final address = await _localDb.getAddressById(addressId);
    if (address == null) return null;
    
    return {
      'id': address.serverId ?? address.id,
      'neighborhood': address.neighborhood,
      'street': address.street,
      'house_number': address.houseNumber,
      'city': address.city,
    };
  }

  // Guardar personas en base de datos local
  Future<void> _savePeopleToLocal(List<Map<String, dynamic>> people) async {
    for (final personData in people) {
      await _savePersonToLocal(personData);
    }
  }

  Future<void> _savePersonToLocal(Map<String, dynamic> personData) async {
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
      addressId = await _localDb.insertAddress(address);
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

    await _localDb.insertPerson(person);
  }

  Future<void> _saveMetersToLocal(List<Map<String, dynamic>> meters, int personId) async {
    for (final meterData in meters) {
      await _saveMeterToLocal(meterData, personId);
    }
  }

  Future<void> _saveMeterToLocal(Map<String, dynamic> meterData, int personId) async {
    final meter = LocalMeter(
      serverId: meterData['id'],
      peopleId: personId,
      waterMeasure: (meterData['water_measure'] ?? 0.0).toDouble(),
      readingDate: DateTime.parse(meterData['reading_date']),
      observation: meterData['observation'],
      invoicePath: meterData['invoice_path'],
      syncStatus: 'synced',
    );

    await _localDb.insertMeter(meter);
  }

  // Limpiar recursos
  void dispose() {
    _syncTimer?.cancel();
  }
}