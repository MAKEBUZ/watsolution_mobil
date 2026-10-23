import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'field_store.dart';

/// Legacy rows have no reliable account scope. Preserve them encrypted, never
/// attach or upload them as the next user to log in.
Future<void> quarantineLegacyDatabase() async {
  final directory = await getDatabasesPath();
  final sourcePath = p.join(directory, 'watsolution_local.db');
  if (!await databaseExists(sourcePath)) return;
  final targetPath = p.join(directory, 'legacy_quarantine.db');
  var key = await secureKeys.read(key: 'legacy_quarantine');
  if (key == null) {
    if (await databaseExists(targetPath)) {
      throw StateError(
        'No se encontró la clave de recuperación. No se borraron los datos anteriores.',
      );
    }
    key = FieldStore.randomKey();
    await secureKeys.write(key: 'legacy_quarantine', value: key);
  }
  final legacy = await openDatabase(
    sourcePath,
    readOnly: true,
    singleInstance: false,
  );
  final target = await openDatabase(
    targetPath,
    password: key,
    version: 1,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE archive (table_name TEXT PRIMARY KEY, payload TEXT NOT NULL, row_count INTEGER NOT NULL)',
      );
    },
  );
  try {
    final tables = await legacy.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    const supported = {
      'people',
      'addresses',
      'meters',
      'sync_queue',
      'android_metadata',
      'sqlite_sequence',
    };
    if (tables.any((row) => !supported.contains(row['name']))) {
      throw StateError(
        'Hay tablas heredadas desconocidas. Se conserva la base original para recuperación autorizada.',
      );
    }
    if ((await target.rawQuery('PRAGMA cipher_version')).isEmpty) {
      throw StateError(
        'No se pudo verificar el cifrado. Se conserva la base original.',
      );
    }
    final names = tables
        .map((r) => r['name'])
        .whereType<String>()
        .where(
          (n) => ['people', 'addresses', 'meters', 'sync_queue'].contains(n),
        )
        .toList();
    final snapshots = <String, List<Map<String, Object?>>>{};
    for (final name in names) {
      snapshots[name] = await legacy.query(name);
    }
    await target.transaction((txn) async {
      for (final entry in snapshots.entries) {
        await txn.insert('archive', {
          'table_name': entry.key,
          'payload': jsonEncode(entry.value),
          'row_count': entry.value.length,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    for (final entry in snapshots.entries) {
      final rows = await target.query(
        'archive',
        where: 'table_name = ?',
        whereArgs: [entry.key],
      );
      if (rows.single['payload'] != jsonEncode(entry.value)) {
        throw StateError(
          'No se pudo verificar la copia cifrada. Se conserva el original.',
        );
      }
    }
  } finally {
    await target.close();
    await legacy.close();
  }
  // Only after the full encrypted copy has been verified and both files closed.
  await deleteDatabase(sourcePath);
}
