import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

// Fingerprint identifies only the former production namespace, never a server
// to contact. Existing encrypted database filenames and keys remain unchanged.
const legacyProductionDigests = {
  'b13e80f90fdd558792f7c463615971f4f941a63b8b5e1c3d072794bb689e98f6',
};

Future<String> storageScope(String environment, String accountId) async =>
    base64UrlEncode(
      (await Sha256().hash(utf8.encode('$environment|$accountId'))).bytes,
    ).replaceAll('=', '');

class StorageMigrationPlan {
  final Map<String, String> writes = {};
  final Set<String> removals = {};
}

Future<StorageMigrationPlan> planProductionStorageMigration(
  Map<String, String> entries, {
  Set<String> sourceDigests = legacyProductionDigests,
}) async {
  final plan = StorageMigrationPlan();
  void copy(String key, String value) {
    final previous = entries[key] ?? plan.writes[key];
    if (previous != null && previous != value) {
      throw StateError(
        'Hay datos locales distintos; no se sobrescribió tu jornada.',
      );
    }
    plan.writes[key] = value;
  }

  for (final entry in entries.entries) {
    final match = RegExp(
      r'^(published-session|session):(.+)$',
    ).firstMatch(entry.key);
    if (match == null) continue;
    final origin = match.group(2)!;
    final digest = (await Sha256().hash(
      utf8.encode(origin),
    )).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    if (!sourceDigests.contains(digest)) continue;
    final saved = jsonDecode(entry.value) as Map<String, dynamic>;
    final id = saved['id']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('La sesión local necesita recuperación.');
    }
    final published = match.group(1) == 'published-session';
    final suffix = published ? '|published' : '';
    final oldScope = await storageScope('$origin$suffix', id);
    final newScope = await storageScope(
      '${ApiConfig.productionStorage}$suffix',
      id,
    );
    copy('field-scope-alias:$newScope', oldScope);
    copy('${match.group(1)}:${ApiConfig.productionStorage}', entry.value);

    final prefix = 'submission:$origin:';
    for (final pending in entries.entries.where(
      (item) => item.key.startsWith(prefix),
    )) {
      copy(
        'submission:${ApiConfig.productionStorage}:${pending.key.substring(prefix.length)}',
        pending.value,
      );
      plan.removals.add(pending.key);
    }
    // Keep the discovery key until all associated old names are removed.
    plan.removals.add(entry.key);
  }
  return plan;
}

Future<void> migrateProductionStorage(FlutterSecureStorage storage) async {
  if (ApiConfig.baseUrl != ApiConfig.awsProductionOrigin) return;
  final plan = await planProductionStorageMigration(await storage.readAll());
  // Copy and verify every key before removing old names. Repeating after a
  // process interruption is safe and never overwrites differing submissions.
  for (final entry in plan.writes.entries) {
    await storage.write(key: entry.key, value: entry.value);
  }
  for (final entry in plan.writes.entries) {
    if (await storage.read(key: entry.key) != entry.value) {
      throw StateError(
        'No se pudo verificar la migración de los datos locales.',
      );
    }
  }
  for (final key in plan.removals) {
    await storage.delete(key: key);
  }
}
