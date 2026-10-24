import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:watsolution_mobil/config/api_config.dart';
import 'package:watsolution_mobil/field/field_session.dart';
import 'offline_read_print_sync_test.dart' show SyncMemoryStore, OutboxDatabase;
import 'published_session_test.dart' show FixtureAdapter, jsonResponse;

class SecureTestDatabase extends OutboxDatabase {
  SecureTestDatabase(super.rows);
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final row = rows.singleWhere((r) => r['id'] == arguments![2]);
    if (row['status'] == 'cancelled') return 0;
    row.addAll({'status': 'sending', 'transport': 'field-v2'});
    return 1;
  }
}

class SecureTestStore extends SyncMemoryStore {
  @override
  Database get db => SecureTestDatabase(rows);
  @override
  Future<void> withdrawPeople(List<int> ids) async {
    expect(ids, isEmpty);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline logout preserves pending originals and queues remote revocation until reconnection',
    () async {
      await ApiConfig.load(origin: 'https://example.invalid');
      final storage = <String, String>{'database-key:synthetic': 'preserve'};
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        switch (call.method) {
          case 'read':
            return storage[args['key']];
          case 'write':
            storage[args['key'] as String] = args['value'] as String;
            return null;
          case 'delete':
            storage.remove(args['key']);
            return null;
          default:
            throw StateError('Unexpected storage mutation: ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final store = SecureTestStore();
      final original = jsonEncode({
        'operationId': 'synthetic',
        'waterMeasure': 110,
      });
      store.rows.add({
        'id': 'synthetic',
        'status': 'pending',
        'command': original,
      });
      final session = FieldSession()
        ..store = store
        ..onlineOnly = true
        ..locked = false;
      session.credentials = {
        'id': '2',
        'id_token': 'synthetic',
        'refresh_token': 'synthetic-refresh',
        'authorities': ['ROLE_ADMIN'],
      };
      var offline = true;
      session.api.httpClientAdapter = FixtureAdapter((options) async {
        expect(Uri.parse(options.path).path, '/api/session/logout');
        expect(options.data, {'refresh_token': 'synthetic-refresh'});
        if (offline) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponse({'revoked': true});
      });
      await session.logout();
      expect(session.locked, true);
      expect(store.rows.single['status'], 'pending');
      expect(store.rows.single['command'], original);
      expect(storage['database-key:synthetic'], 'preserve');
      expect(
        storage.keys.any((key) => key.startsWith('pending-revocations:')),
        true,
      );
      offline = false;
      expect(await session.retryRemoteLogout(), true);
      expect(
        storage.keys.any((key) => key.startsWith('pending-revocations:')),
        false,
      );
      expect(store.rows.single['command'], original);
    },
  );
  test(
    'new field session preserves offline original, renews permit, and reconciles a lost invoice response',
    () async {
      await ApiConfig.load(origin: 'https://example.invalid');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'containsKey' ? false : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        ),
      );
      final key = await Ed25519().newKeyPair();
      final publicKey = base64Encode((await key.extractPublicKey()).bytes);
      final store = SecureTestStore();
      store.persistedPerson.addAll({
        'previousReading': 100,
        'previousMeterId': 8,
        'previousDate': '2026-10-01',
        'referencePrepared': true,
      });
      final session = FieldSession(verificationKey: publicKey)
        ..store = store
        ..onlineOnly = true
        ..locked = false;
      final now = DateTime.now().toUtc();
      session.credentials = {
        'id': '2',
        'login': 'synthetic',
        'authorities': ['ROLE_ADMIN'],
        'id_token': 'synthetic',
        'offlineIssued': now.toIso8601String(),
        'offlineUntil': now.add(const Duration(hours: 12)).toIso8601String(),
      };
      var offline = true, lost = true;
      final committed = <String, Map<String, dynamic>>{};
      final commands = <Map>[];
      session.api.httpClientAdapter = FixtureAdapter((options) async {
        if (offline) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        final path = Uri.parse(options.path).path;
        if (path == '/api/account') {
          return jsonResponse({
            'id': 2,
            'login': 'synthetic',
            'authorities': ['ROLE_ADMIN'],
          });
        }
        if (path == '/api/mobile/permit') {
          String encode(Object v) =>
              base64UrlEncode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
          final content =
              '${encode({'alg': 'EdDSA', 'typ': 'JWT'})}.${encode({'iss': 'watsolution-api', 'aud': 'watsolution-offline', 'sub': '2', 'installationId': options.data['installationId'], 'iat': now.millisecondsSinceEpoch ~/ 1000, 'exp': now.add(const Duration(hours: 12)).millisecondsSinceEpoch ~/ 1000})}';
          final signature = await Ed25519().sign(
            utf8.encode(content),
            keyPair: key,
          );
          return jsonResponse({
            'permit':
                '$content.${base64UrlEncode(signature.bytes).replaceAll('=', '')}',
          });
        }
        if (path == '/api/mobile/access/check') {
          return jsonResponse({
            'allowedIds': [7],
          });
        }
        expect(path, '/api/mobile/capture-billing');
        final command = Map<String, dynamic>.from(options.data as Map);
        commands.add(command);
        final result = committed.putIfAbsent(
          command['operationId'],
          () => {
            'operationId': command['operationId'],
            'personId': 7,
            'meterId': 9,
            'waterMeasure': 110,
            'readingDate': command['readingDate'],
            'invoiceId': 22,
            'amountDue': 6000,
          },
        );
        if (lost) {
          lost = false;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return jsonResponse(result);
      });
      await session.reload();
      await session.saveOnlineReading(
        7,
        110,
        '',
        billing: {
          'rate': 100,
          'fixedCharge': 5000,
          'subsidy': 0,
          'surcharges': 0,
        },
      );
      await session.sync();
      expect(store.rows.single['status'], 'pending');
      final original = store.rows.single['command'];
      expect(
        (await session.measurementReference(
          session.people.single,
        )).single['waterMeasure'],
        100,
      );
      offline = false;
      await session.sync();
      expect(store.rows.single['status'], 'retry');
      expect(store.rows.single['command'], original);
      await session.sync();
      expect(store.rows.single['status'], 'confirmed');
      expect(store.rows.single['command'], original);
      expect(committed.length, 1);
      expect(commands, hasLength(2));
      expect(commands[0], commands[1]);
      await session.lock();
      expect(store.rows.single['command'], original);
    },
  );
}
