import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/config/api_config.dart';
import 'package:watsolution_mobil/field/storage_migration.dart';

void main() {
  test('AWS defaults to a provider-independent local scope', () async {
    await ApiConfig.load();
    expect(ApiConfig.baseUrl, ApiConfig.productionOrigin);
    expect(ApiConfig.storageOrigin, ApiConfig.productionStorage);
    await ApiConfig.load(origin: 'https://test.example.com');
    expect(ApiConfig.storageOrigin, 'https://test.example.com');
    for (final origin in [
      'http://test.example.com',
      '${ApiConfig.awsProductionOrigin}/api',
      'https://user:password@test.example.com',
    ]) {
      await expectLater(ApiConfig.load(origin: origin), throwsStateError);
      expect(() => ApiConfig.baseUrl, throwsA(isA<TypeError>()));
    }
  });
  test(
    'domain change keeps account database, session and outbox namespaces',
    () async {
      for (final accountId in ['7', '13']) {
        await ApiConfig.load(origin: ApiConfig.awsProductionOrigin);
        final oldOrigin = ApiConfig.storageOrigin;
        final oldScope = await storageScope(oldOrigin, accountId);
        final oldPublishedScope = await storageScope(
          '$oldOrigin|published',
          accountId,
        );
        await ApiConfig.load(origin: '${ApiConfig.productionOrigin}/');
        expect(ApiConfig.storageOrigin, oldOrigin);
        expect(
          await storageScope(ApiConfig.storageOrigin, accountId),
          oldScope,
        );
        expect(
          await storageScope('${ApiConfig.storageOrigin}|published', accountId),
          oldPublishedScope,
        );
        final storedEntries = {
          'session:$oldOrigin': jsonEncode({'id': accountId}),
          'submission:$oldOrigin:$accountId:3': 'pending-reading',
          'field-scope-alias:$oldScope': 'existing-encrypted-database',
        };
        final plan = await planProductionStorageMigration(storedEntries);
        expect(plan.writes, isEmpty);
        expect(plan.removals, isEmpty);
      }
      // A similarly named but untrusted server must never inherit production data.
      await ApiConfig.load(
        origin: 'https://api.watsolution.online.example.com',
      );
      expect(ApiConfig.storageOrigin, isNot(ApiConfig.productionStorage));
    },
  );
  test(
    'migration preserves encrypted scope and uncertain submissions',
    () async {
      const source = 'https://previous.example.com';
      final hash = (await Sha256().hash(
        utf8.encode(source),
      )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final entries = {
        'published-session:$source': jsonEncode({
          'id': '7',
          'login': 'operator',
        }),
        'submission:$source:7:3': 'uncertain-operation',
        'session:https://other.example.com': 'unrelated',
      };
      final plan = await planProductionStorageMigration(
        entries,
        sourceDigests: {hash},
      );
      final scope = await storageScope(
        '${ApiConfig.productionStorage}|published',
        '7',
      );
      expect(
        plan.writes['field-scope-alias:$scope'],
        await storageScope('$source|published', '7'),
      );
      expect(
        plan.writes['submission:${ApiConfig.productionStorage}:7:3'],
        'uncertain-operation',
      );
      expect(plan.removals, contains('published-session:$source'));
      expect(
        plan.removals,
        isNot(contains('session:https://other.example.com')),
      );
      final resumed = await planProductionStorageMigration(
        {...entries, ...plan.writes},
        sourceDigests: {hash},
      );
      expect(resumed.writes, plan.writes);
      final completed = {...entries, ...plan.writes}
        ..removeWhere((key, value) => plan.removals.contains(key));
      expect(
        (await planProductionStorageMigration(
          completed,
          sourceDigests: {hash},
        )).writes,
        isEmpty,
      );
      await expectLater(
        planProductionStorageMigration(
          {
            ...entries,
            'submission:${ApiConfig.productionStorage}:7:3':
                'different-operation',
          },
          sourceDigests: {hash},
        ),
        throwsStateError,
      );
    },
  );
  test('unknown origins cannot import production sessions', () async {
    final plan = await planProductionStorageMigration({
      'published-session:https://unknown.example.com': jsonEncode({'id': '7'}),
    });
    expect(plan.writes, isEmpty);
    expect(plan.removals, isEmpty);
  });
}
