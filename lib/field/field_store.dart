import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'operation_policy.dart';
import 'storage_migration.dart';

const secureSession = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
);
const secureKeys = FlutterSecureStorage(
  aOptions: AndroidOptions.biometric(
    enforceBiometrics: true,
    requireBiometricsPerOperation: true,
    resetOnError: false,
    storageNamespace: 'field_keys',
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    accountName: 'field_keys',
  ),
);

class FieldStore {
  final Database db;
  FieldStore._(this.db);
  static String randomKey() =>
      base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)));

  static Future<FieldStore> open(
    String environment,
    String accountId, {
    bool deviceProtected = false,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('El almacén de campo requiere Android o iOS.');
    }
    final originalScope = await storageScope(environment, accountId);
    final alias = await secureSession.read(
      key: 'field-scope-alias:$originalScope',
    );
    if (alias != null && !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(alias)) {
      throw StateError('La referencia del almacén local no es válida.');
    }
    if (alias != null &&
        alias != originalScope &&
        await databaseExists(
          p.join(await getDatabasesPath(), 'field_$originalScope.db'),
        )) {
      throw StateError(
        'Hay dos almacenes locales; se conservaron para recuperación.',
      );
    }
    final scope = alias ?? originalScope;
    final path = p.join(await getDatabasesPath(), 'field_$scope.db');
    final keyStorage = deviceProtected ? secureSession : secureKeys;
    var key = await keyStorage.read(key: scope);
    if (alias != null && (!await databaseExists(path) || key == null)) {
      throw StateError(
        'Falta el almacén anterior o su clave; no se borró ningún dato.',
      );
    }
    if (key == null) {
      if (await databaseExists(path)) {
        throw StateError(
          'Falta la clave del almacén. No se borró ningún dato; solicita recuperación.',
        );
      }
      key = randomKey();
      await keyStorage.write(key: scope, value: key);
    }
    final db = await openDatabase(
      path,
      password: key,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE people (id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE outbox (id TEXT PRIMARY KEY, person_id INTEGER NOT NULL, command TEXT NOT NULL, status TEXT NOT NULL, result TEXT, error TEXT, attempts INTEGER NOT NULL DEFAULT 0, retry_at INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX outbox_status ON outbox(status, retry_at)',
        );
        await db.execute(
          'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
    final cipher = await db.rawQuery('PRAGMA cipher_version');
    if (cipher.isEmpty) {
      await db.close();
      throw StateError('Cifrado no disponible');
    }
    return FieldStore._(db);
  }

  Future<void> replacePeople(List<Map<String, dynamic>> people) =>
      db.transaction((txn) async {
        await txn.delete('people');
        final batch = txn.batch();
        for (final person in people) {
          batch.insert('people', {
            'id': person['id'],
            'payload': jsonEncode(person),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        await txn.insert('metadata', {
          'key': 'preparedAt',
          'value': DateTime.now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });

  Future<List<Map<String, dynamic>>> people() async =>
      (await db.query('people', orderBy: 'id'))
          .map(
            (r) =>
                Map<String, dynamic>.from(jsonDecode(r['payload'] as String)),
          )
          .toList();
  Future<List<Map<String, Object?>>> operations() =>
      db.query('outbox', orderBy: 'created_at DESC');
  Future<Map<String, dynamic>?> person(int id) async {
    final rows = await db.query('people', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(rows.single['payload'] as String),
          );
  }

  Future<String?> meta(String key) async {
    final rows = await db.query('metadata', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) => db
      .insert('metadata', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});

  Future<void> updateReference(int personId, Map<String, dynamic> reference) =>
      db.transaction((txn) async {
        final rows = await txn.query(
          'people',
          where: 'id = ?',
          whereArgs: [personId],
        );
        if (rows.isEmpty) throw StateError('Persona no preparada.');
        final person = Map<String, dynamic>.from(
          jsonDecode(rows.single['payload'] as String),
        );
        person.addAll(reference);
        await txn.update(
          'people',
          {'payload': jsonEncode(person)},
          where: 'id = ?',
          whereArgs: [personId],
        );
      });

  Future<void> capture(Map<String, dynamic> command) => db.transaction((
    txn,
  ) async {
    final personId = command['personId'];
    final person = await txn.query(
      'people',
      where: 'id = ?',
      whereArgs: [personId],
    );
    if (person.isEmpty) {
      throw StateError('Persona no preparada para esta cuenta');
    }
    final pending = await txn.query(
      'outbox',
      where: 'person_id = ? AND status NOT IN (?, ?, ?)',
      whereArgs: [personId, 'confirmed', 'reviewed', 'cancelled'],
    );
    if (pending.isNotEmpty) {
      throw StateError(
        'Ya existe una lectura pendiente para esta persona. Sincronízala o resuelve el conflicto.',
      );
    }
    await txn.insert('outbox', {
      'id': command['operationId'],
      'person_id': personId,
      'command': jsonEncode(command),
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  });

  Future<void> acknowledge(String id, Map<String, dynamic> result) =>
      db.transaction((txn) async {
        await txn.update(
          'outbox',
          {'status': 'confirmed', 'result': jsonEncode(result), 'error': null},
          where: 'id = ?',
          whereArgs: [id],
        );
        final rows = await txn.query(
          'people',
          where: 'id = ?',
          whereArgs: [result['personId']],
        );
        if (rows.isNotEmpty) {
          final person = Map<String, dynamic>.from(
            jsonDecode(rows.first['payload'] as String),
          );
          person.addAll({
            'previousMeterId': result['meterId'],
            'previousReading': result['waterMeasure'],
            'previousDate': result['readingDate'],
          });
          await txn.update(
            'people',
            {'payload': jsonEncode(person)},
            where: 'id = ?',
            whereArgs: [result['personId']],
          );
        }
      });

  Future<void> cancelPending(String id) async {
    final count = await db.update(
      'outbox',
      {
        'status': 'cancelled',
        'error': 'Cancelado en la tablet antes de enviarse.',
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'pending'],
    );
    if (count != 1) {
      throw StateError(
        'El registro ya se está enviando o no puede cancelarse localmente.',
      );
    }
  }

  Future<void> withdrawPeople(List<int> ids) => db.transaction((txn) async {
    for (final id in ids) {
      await txn.delete('people', where: 'id = ?', whereArgs: [id]);
      await txn.update(
        'outbox',
        {
          'status': 'quarantine',
          'error':
              'Asignación retirada. Pendiente cifrado para revisión autorizada.',
        },
        where: 'person_id = ? AND status NOT IN (?, ?, ?)',
        whereArgs: [id, 'confirmed', 'reviewed', 'cancelled'],
      );
    }
  });

  Future<void> reviewRejected(String id, String reason) async {
    final explanation = reviewReason(reason);
    await db.transaction((txn) async {
      final rows = await txn.query('outbox', where: 'id = ?', whereArgs: [id]);
      if (rows.length != 1 || !canReviewOperation(rows.single['status'])) {
        throw StateError('Solo se pueden revisar rechazos definitivos.');
      }
      final original = rows.single;
      await txn.update(
        'outbox',
        {
          'status': 'reviewed',
          'result': jsonEncode({
            'reviewedAt': DateTime.now().toUtc().toIso8601String(),
            'reason': explanation,
            'previousStatus': original['status'],
            'previousError': original['error'],
          }),
          'error': 'Revisado localmente. El original se conserva sin enviarlo.',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> resumeQuarantined(String id) => db.transaction((txn) async {
    final rows = await txn.query(
      'outbox',
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'quarantine'],
    );
    if (rows.length != 1) {
      throw StateError('El registro ya no está en cuarentena.');
    }
    final people = await txn.query(
      'people',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [rows.single['person_id']],
    );
    if (people.isEmpty) {
      throw StateError('La persona todavía no está asignada a tu cuenta.');
    }
    // Keep the exact command and UUID: an earlier request may have committed
    // before permission was withdrawn and its ACK may have been lost.
    await txn.update(
      'outbox',
      {'status': 'pending', 'retry_at': 0, 'error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  Future<void> close() => db.close();
}
