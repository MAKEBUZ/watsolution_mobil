import 'dart:async';
import 'database_helper.dart';
import 'sync_service.dart';
import 'models/local_models.dart';
import '../api/person_service.dart';
import '../api/meter_service.dart';

class UnifiedDatabaseService {
  static final UnifiedDatabaseService instance = UnifiedDatabaseService._init();
  final DatabaseHelper _localDb = DatabaseHelper.instance;
  final SyncService _syncService = SyncService.instance;
  final PersonService _personService = PersonService.instance;
  final MeterService _meterService = MeterService.instance;

  Timer? _syncTimer;

  SyncService get syncService => _syncService;

  UnifiedDatabaseService._init() {
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await syncData();
    });
  }

  Future<List<Map<String, dynamic>>> getPeople() async {
    try {
      if (await _syncService.isOnline()) {
        final people = await _personService.getAll(size: 1000);
        final list = people.cast<Map<String, dynamic>>();
        await _savePeopleToLocal(list);
        return list;
      } else {
        final localPeople = await _localDb.getAllPeople();
        return localPeople.map((person) => _localPersonToMap(person)).toList();
      }
    } catch (e) {
      print('Error obteniendo personas: $e');
      final localPeople = await _localDb.getAllPeople();
      return localPeople.map((person) => _localPersonToMap(person)).toList();
    }
  }

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
        // El backend espera CreatePersonWithAccountDTO con campos de dirección directos
        final personResult = await _personService.create({
          'fullName': fullName,
          'documentNumber': documentNumber,
          'phone': phone,
          'email': email,
          'status': 'ACTIVE',
          'neighborhood': neighborhood,
          'street': street,
          'houseNumber': houseNumber,
          'city': city,
        });
        await _savePersonToLocal(personResult);
        return personResult;
      } else {
        final localAddress = LocalAddress(
          neighborhood: neighborhood ?? '',
          street: street,
          houseNumber: houseNumber,
          city: city,
          syncStatus: 'pending',
        );
        final addressId = await _localDb.insertAddress(localAddress);

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

        await _syncService.addToSyncQueue('people', 'insert', localPerson.copyWith(id: personId).toMap());

        return _localPersonToMap(localPerson.copyWith(id: personId));
      }
    } catch (e) {
      print('Error creando persona: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMetersByPersonId(int personId) async {
    try {
      if (await _syncService.isOnline()) {
        final localPerson = await _localDb.getPersonById(personId);
        final serverId = localPerson?.serverId ?? personId;
        final meters = await _meterService.getByPersonId(serverId);
        final list = meters.cast<Map<String, dynamic>>();
        await _saveMetersToLocal(list, personId);
        return list;
      } else {
        final localMeters = await _localDb.getMetersByPersonId(personId);
        return localMeters.map((meter) => _localMeterToMap(meter)).toList();
      }
    } catch (e) {
      print('Error obteniendo medidores: $e');
      final localMeters = await _localDb.getMetersByPersonId(personId);
      return localMeters.map((meter) => _localMeterToMap(meter)).toList();
    }
  }

  Future<Map<String, dynamic>?> createMeter({
    required int personId,
    int? addressId,
    required double waterMeasure,
    required DateTime readingDate,
    String? observation,
    String? invoicePath,
  }) async {
    try {
      if (await _syncService.isOnline()) {
        // Enviar al backend con formato de objetos de relación (JHipster/NestJS espera objetos, no IDs sueltos)
        final payload = <String, dynamic>{
          'waterMeasure': waterMeasure,
          'readingDate': '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}',
          'observation': observation,
        };
        // Agregar relaciones como objetos
        payload['person'] = {'id': personId};
        if (addressId != null) {
          payload['address'] = {'id': addressId};
        }

        final result = await _meterService.create(payload);
        // Guardar localmente después de crear en backend
        await _saveMeterToLocal(result, personId);
        return result;
      } else {
        final localMeter = LocalMeter(
          peopleId: personId,
          waterMeasure: waterMeasure,
          readingDate: readingDate,
          observation: observation,
          invoicePath: invoicePath,
          syncStatus: 'pending',
        );
        final meterId = await _localDb.insertMeter(localMeter);
        await _syncService.addToSyncQueue('meters', 'insert', localMeter.copyWith(id: meterId).toMap());
        return _localMeterToMap(localMeter.copyWith(id: meterId));
      }
    } catch (e) {
      print('Error creando medidor: $e');
      rethrow;
    }
  }

  Future<void> syncData() async {
    await _syncService.syncAllData();
  }

  Future<void> loadDataFromServer() async {
    await _syncService.syncFromServer();
  }

  Map<String, dynamic> _localPersonToMap(LocalPerson person) {
    return {
      'id': person.serverId ?? person.id,
      'fullName': person.fullName,
      'documentNumber': person.documentNumber,
      'phone': person.phone,
      'email': person.email,
      'status': person.status,
      'addressId': person.addressId,
      'subscriberNumber': person.subscriberNumber,
      'stratum': person.stratum,
      'userId': person.userId,
      'greenPoints': person.greenPoints,
      'daysSinceLastDebt': person.daysSinceLastDebt,
      'savingsPercent': person.savingsPercent,
      'address': person.addressId != null ? _getAddressMap(person.addressId!) : null,
    };
  }

  Map<String, dynamic> _localMeterToMap(LocalMeter meter) {
    return {
      'id': meter.serverId ?? meter.id,
      'personId': meter.peopleId,
      'waterMeasure': meter.waterMeasure,
      'readingDate': meter.readingDate.toIso8601String(),
      'observation': meter.observation,
      'invoicePath': meter.invoicePath,
    };
  }

  Future<Map<String, dynamic>?> _getAddressMap(int addressId) async {
    final address = await _localDb.getAddressById(addressId);
    if (address == null) return null;
    return {
      'id': address.serverId ?? address.id,
      'neighborhood': address.neighborhood,
      'street': address.street,
      'houseNumber': address.houseNumber,
      'city': address.city,
      'latitude': address.latitude,
      'longitude': address.longitude,
    };
  }

  Future<void> _savePeopleToLocal(List<Map<String, dynamic>> people) async {
    for (final personData in people) {
      await _savePersonToLocal(personData);
    }
  }

  Future<void> _savePersonToLocal(Map<String, dynamic> personData) async {
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
      addressId = await _localDb.insertAddress(address);
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

    await _localDb.insertPerson(person);
  }

  Future<void> _saveMetersToLocal(List<Map<String, dynamic>> meters, int personId) async {
    for (final meterData in meters) {
      await _saveMeterToLocal(meterData, personId);
    }
  }

  Future<void> _saveMeterToLocal(Map<String, dynamic> meterData, int personId) async {
    final wmRaw = meterData['waterMeasure'] ?? meterData['water_measure'] ?? 0.0;
    final double waterMeasure;
    if (wmRaw is num) {
      waterMeasure = wmRaw.toDouble();
    } else if (wmRaw is String) {
      waterMeasure = double.tryParse(wmRaw) ?? 0.0;
    } else {
      waterMeasure = 0.0;
    }
    final meter = LocalMeter(
      serverId: meterData['id'],
      peopleId: personId,
      waterMeasure: waterMeasure,
      readingDate: DateTime.parse(meterData['readingDate'] ?? meterData['reading_date']),
      observation: meterData['observation'],
      invoicePath: meterData['invoicePath'] ?? meterData['invoice_path'],
      syncStatus: 'synced',
    );
    await _localDb.insertMeter(meter);
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
