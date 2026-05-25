import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/local_models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('watsolution_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabla de personas
    await db.execute('''
      CREATE TABLE people (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        full_name TEXT NOT NULL,
        document_number TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        status TEXT DEFAULT 'active',
        address_id INTEGER,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabla de direcciones
    await db.execute('''
      CREATE TABLE addresses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        neighborhood TEXT NOT NULL,
        street TEXT,
        house_number TEXT,
        city TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabla de medidores
    await db.execute('''
      CREATE TABLE meters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        people_id INTEGER NOT NULL,
        water_measure REAL NOT NULL,
        reading_date TEXT NOT NULL,
        observation TEXT,
        invoice_path TEXT,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (people_id) REFERENCES people (id)
      )
    ''');

    // Tabla de sincronización
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        local_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // Métodos CRUD para People
  Future<int> insertPerson(LocalPerson person) async {
    final db = await instance.database;
    return await db.insert('people', person.toMap());
  }

  Future<List<LocalPerson>> getAllPeople() async {
    final db = await instance.database;
    final result = await db.query('people', orderBy: 'full_name');
    return result.map((json) => LocalPerson.fromMap(json)).toList();
  }

  Future<LocalPerson?> getPersonById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'people',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return LocalPerson.fromMap(result.first);
    }
    return null;
  }

  Future<int> updatePerson(LocalPerson person) async {
    final db = await instance.database;
    return await db.update(
      'people',
      person.toMap(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  // Métodos CRUD para Addresses
  Future<int> insertAddress(LocalAddress address) async {
    final db = await instance.database;
    return await db.insert('addresses', address.toMap());
  }

  Future<LocalAddress?> getAddressById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'addresses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return LocalAddress.fromMap(result.first);
    }
    return null;
  }

  // Métodos CRUD para Meters
  Future<int> insertMeter(LocalMeter meter) async {
    final db = await instance.database;
    return await db.insert('meters', meter.toMap());
  }

  Future<List<LocalMeter>> getMetersByPersonId(int personId) async {
    final db = await instance.database;
    final result = await db.query(
      'meters',
      where: 'people_id = ?',
      whereArgs: [personId],
      orderBy: 'reading_date DESC',
    );
    return result.map((json) => LocalMeter.fromMap(json)).toList();
  }

  // Métodos para sincronización
  Future<int> insertSyncQueueItem(SyncQueueItem item) async {
    final db = await instance.database;
    return await db.insert('sync_queue', item.toMap());
  }

  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final db = await instance.database;
    final result = await db.query('sync_queue', orderBy: 'created_at');
    return result.map((json) => SyncQueueItem.fromMap(json)).toList();
  }

  Future<int> deleteSyncQueueItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Obtener datos pendientes de sincronización
  Future<List<LocalPerson>> getPeoplePendingSync() async {
    final db = await instance.database;
    final result = await db.query(
      'people',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at',
    );
    return result.map((json) => LocalPerson.fromMap(json)).toList();
  }

  Future<List<LocalMeter>> getMetersPendingSync() async {
    final db = await instance.database;
    final result = await db.query(
      'meters',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at',
    );
    return result.map((json) => LocalMeter.fromMap(json)).toList();
  }

  // Actualizar estado de sincronización
  Future<void> updatePersonSyncStatus(int id, String status, {int? serverId}) async {
    final db = await instance.database;
    final updates = {
      'sync_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (serverId != null) {
      updates['server_id'] = serverId.toString();
    }
    await db.update(
      'people',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMeterSyncStatus(int id, String status, {int? serverId}) async {
    final db = await instance.database;
    final updates = {
      'sync_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (serverId != null) {
      updates['server_id'] = serverId.toString();
    }
    await db.update(
      'meters',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    _database = null;
    await db.close();
  }
}