import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/qr_service.dart';
import '../api/person_service.dart';
import '../api/meter_service.dart';
import '../api/address_service.dart';
import 'database_helper.dart';
import 'models/local_models.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Connectivity _connectivity = Connectivity();
  final PersonService _personService = PersonService.instance;
  final MeterService _meterService = MeterService.instance;
  final AddressService _addressService = AddressService.instance;

  SyncService._init();

  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Future<void> syncAllData() async {
    if (!await isOnline()) {
      print('Sin conexión a internet, sincronización cancelada');
      return;
    }

    try {
      print('Iniciando sincronización...');
      await _syncPeople();
      await _syncMeters();
      await _syncQueue();
      print('Sincronización completada exitosamente');
    } catch (e) {
      print('Error durante la sincronización: $e');
      rethrow;
    }
  }

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

  Future<void> _syncPerson(LocalPerson person) async {
    try {
      if (person.serverId != null) {
        // Actualizar en backend
        await _personService.updateById(person.serverId!, {
          'id': person.serverId,
          'fullName': person.fullName,
          'documentNumber': person.documentNumber,
          'phone': person.phone,
          'email': person.email,
          'status': person.status.toUpperCase(),
        });
        await _dbHelper.updatePersonSyncStatus(person.id!, 'synced');
      } else {
        // Crear nueva persona en backend usando CreatePersonWithAccountDTO
        String? neighborhood;
        String? street;
        String? houseNumber;
        String? city;
        if (person.addressId != null) {
          final address = await _dbHelper.getAddressById(person.addressId!);
          if (address != null) {
            neighborhood = address.neighborhood;
            street = address.street;
            houseNumber = address.houseNumber;
            city = address.city;
          }
        }

        final result = await _personService.create({
          'fullName': person.fullName,
          'documentNumber': person.documentNumber,
          'phone': person.phone,
          'email': person.email,
          'status': 'ACTIVE',
          'neighborhood': neighborhood,
          'street': street,
          'houseNumber': houseNumber,
          'city': city,
        });

        final serverId = result['id'] as int?;
        if (serverId != null) {
          await _dbHelper.updatePersonSyncStatus(person.id!, 'synced', serverId: serverId);
          try {
            await QrService.createUserQr(personId: serverId);
            print('QR generado automáticamente para persona sincronizada: $serverId');
          } catch (e) {
            print('Error generando QR para persona sincronizada $serverId: $e');
          }
        }
      }
      print('Persona sincronizada: ${person.fullName}');
    } catch (e) {
      print('Error sincronizando persona ${person.fullName}: $e');
      await _dbHelper.updatePersonSyncStatus(person.id!, 'error');
      rethrow;
    }
  }

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

  Future<void> _syncMeter(LocalMeter meter) async {
    try {
      final person = await _dbHelper.getPersonById(meter.peopleId);
      if (person == null || person.serverId == null) {
        print('Persona no encontrada o no sincronizada para medidor');
        return;
      }

      final result = await _meterService.create({
        'personId': person.serverId,
        'waterMeasure': meter.waterMeasure,
        'readingDate': meter.readingDate.toIso8601String(),
        'observation': meter.observation,
        'invoicePath': meter.invoicePath,
      });

      final serverId = result['id'] as int?;
      if (serverId != null) {
        await _dbHelper.updateMeterSyncStatus(meter.id!, 'synced', serverId: serverId);
      }
      print('Medidor sincronizado para: ${person.fullName}');
    } catch (e) {
      print('Error sincronizando medidor: $e');
      await _dbHelper.updateMeterSyncStatus(meter.id!, 'error');
      rethrow;
    }
  }

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

  Future<void> _processSyncQueueItem(SyncQueueItem item) async {
    try {
      final data = json.decode(item.data) as Map<String, dynamic>;

      switch (item.tableName) {
        case 'people':
          if (item.operation == 'insert') {
            await _personService.create(data);
          } else if (item.operation == 'update') {
            await _personService.update(data);
          } else if (item.operation == 'delete') {
            await _personService.delete(data['id']);
          }
          break;
        case 'addresses':
          if (item.operation == 'insert') {
            await _addressService.create(data);
          } else if (item.operation == 'update') {
            await _addressService.update(data);
          } else if (item.operation == 'delete') {
            await _addressService.delete(data['id']);
          }
          break;
        case 'meters':
          if (item.operation == 'insert') {
            await _meterService.create(data);
          } else if (item.operation == 'update') {
            await _meterService.update(data);
          } else if (item.operation == 'delete') {
            await _meterService.delete(data['id']);
          }
          break;
        default:
          print('Tabla no soportada en cola de sync: ${item.tableName}');
      }

      await _dbHelper.deleteSyncQueueItem(item.id!);
      print('Operación ${item.operation} en ${item.tableName} sincronizada');
    } catch (e) {
      print('Error procesando item de cola: $e');
      rethrow;
    }
  }

  Future<void> addToSyncQueue(String tableName, String operation, Map<String, dynamic> data) async {
    final item = SyncQueueItem(
      tableName: tableName,
      localId: data['id'] ?? 0,
      operation: operation,
      data: json.encode(data),
      createdAt: DateTime.now(),
    );
    await _dbHelper.insertSyncQueueItem(item);
    if (await isOnline()) {
      try {
        await syncAllData();
      } catch (e) {
        print('Error en sincronización automática: $e');
      }
    }
  }

  Future<void> syncFromServer() async {
    if (!await isOnline()) {
      print('Sin conexión a internet, no se pueden cargar datos del servidor');
      return;
    }

    try {
      print('Cargando datos desde el servidor...');
      final people = await _personService.getAll(size: 1000);

      for (final personData in people) {
        await _saveServerPersonToLocal(personData as Map<String, dynamic>);
      }
      print('Datos del servidor cargados exitosamente');
    } catch (e) {
      print('Error cargando datos del servidor: $e');
      rethrow;
    }
  }

  Future<void> _saveServerPersonToLocal(Map<String, dynamic> personData) async {
    try {
      int? addressId;
      if (personData['address'] != null) {
        final addressData = personData['address'] as Map<String, dynamic>;
        final address = LocalAddress(
          serverId: addressData['id'],
          neighborhood: addressData['neighborhood'] ?? '',
          street: addressData['street'],
          houseNumber: addressData['houseNumber'],
          city: addressData['city'] ?? '',
          latitude: addressData['latitude']?.toDouble(),
          longitude: addressData['longitude']?.toDouble(),
          syncStatus: 'synced',
        );
        addressId = await _dbHelper.insertAddress(address);
      }

      final person = LocalPerson(
        serverId: personData['id'],
        fullName: personData['fullName'] ?? '',
        documentNumber: personData['documentNumber'] ?? '',
        phone: personData['phone'],
        email: personData['email'],
        status: personData['status'] ?? 'active',
        addressId: addressId,
        subscriberNumber: personData['subscriberNumber'],
        stratum: personData['stratum']?.toInt(),
        userId: personData['userId'],
        greenPoints: personData['greenPoints']?.toInt(),
        daysSinceLastDebt: personData['daysSinceLastDebt']?.toInt(),
        savingsPercent: personData['savingsPercent']?.toDouble(),
        syncStatus: 'synced',
      );

      await _dbHelper.insertPerson(person);
    } catch (e) {
      print('Error guardando persona del servidor: $e');
      rethrow;
    }
  }

  Future<void> clearLocalData() async {
    await _dbHelper.clearAll();
    print('Base de datos local limpiada');
  }
}
