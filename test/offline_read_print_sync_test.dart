import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:watsolution_mobil/config/api_config.dart';
import 'package:watsolution_mobil/field/receipt_printer.dart';
import 'offline_capture_test.dart' show MemoryStore;
import 'published_session_test.dart' show fixture, jsonResponse;

class SyncMemoryStore extends MemoryStore {
  late final Database _database = OutboxDatabase(rows);
  @override
  Database get db => _database;
  @override
  Future<void> acknowledge(String id, Map<String, dynamic> result) async {
    rows.singleWhere((r) => r['id'] == id).addAll({
      'status': 'confirmed',
      'result': jsonEncode(result),
      'error': null,
    });
    persistedPerson.addAll({
      'previousMeterId': result['meterId'],
      'previousReading': result['waterMeasure'],
      'previousDate': result['readingDate'],
    });
  }
}

class OutboxDatabase implements Database {
  final List<Map<String, Object?>> rows;
  OutboxDatabase(this.rows);
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    expect(table, 'outbox');
    final matches = rows
        .where(
          (r) =>
              r['id'] == whereArgs!.first &&
              (whereArgs.length == 1 || r['status'] == whereArgs[1]),
        )
        .toList();
    for (final row in matches) {
      row.addAll(values);
    }
    return matches.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'capture offline, print without HTTP, reconnect and issue exactly one invoice',
    (tester) async {
      await ApiConfig.load(origin: 'https://example.invalid');
      var offline = true;
      var requests = 0;
      final posts = <Map>[];
      final printJobs = <Map>[];
      final store = SyncMemoryStore();
      store.persistedPerson.addAll({
        'previousReading': 100,
        'previousMeterId': 9,
        'previousDate': '2026-10-01',
      });
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'containsKey' ? false : null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('watsolution/printer'),
        (call) async {
          if (call.method == 'devices') {
            return [
              {'name': 'KPrinter de prueba', 'address': '00:00:00:00:00:01'},
            ];
          }
          expect(call.method, 'print');
          expect(offline, isTrue);
          printJobs.add(Map.from(call.arguments as Map));
          return null;
        },
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('watsolution/printer'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
      });
      final session = fixture((options) async {
        requests++;
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
        if (path == '/api/meters/by-person/7') {
          return jsonResponse([
            {
              'id': 9,
              'person': {'id': 7},
              'waterMeasure': 100,
              'readingDate': '2026-10-01',
            },
          ]);
        }
        if (options.method == 'POST') {
          expect(path, '/api/admin/billing/generate');
          expect(store.rows.single['status'], 'sending');
          posts.add(Map.from(options.data as Map));
          return jsonResponse({
            'id': 100,
            'person': {'id': 7},
            'meter': {'id': 10},
            'amountDue': 1500,
          });
        }
        if (path == '/api/meters/10') {
          return jsonResponse({
            'id': 10,
            'person': {'id': 7},
            'waterMeasure': 110,
            'readingDate': '2026-10-23',
          });
        }
        fail('Unexpected request: ${options.method} $path');
      })..store = store;
      final now = DateTime.now().toUtc();
      session.credentials!.addAll({
        'offlineIssued': now.toIso8601String(),
        'offlineUntil': now.add(const Duration(hours: 12)).toIso8601String(),
      });
      await tester.runAsync(() async {
        await session.reload();
        expect(
          (await session.measurementReference(
            session.people.single,
          )).single['waterMeasure'],
          100,
        );
        final saved = await session.saveOnlineReading(
          7,
          110,
          '',
          billing: {
            'rate': 100,
            'fixedCharge': 500,
            'subsidy': 0,
            'surcharges': 0,
          },
        );
        expect(saved['kind'], 'local');
        await session.sync();
      });
      expect(session.locked, isFalse);
      expect(store.rows.single['status'], 'pending');
      expect(posts, isEmpty);
      final command = Map<String, dynamic>.from(
        jsonDecode(store.rows.single['command'] as String),
      );
      final originalCommand = store.rows.single['command'];
      final beforePrint = requests;
      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptPrinterScreen(
            session: session,
            command: command,
            personName: command['personName'] as String,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('KPrinter de prueba'));
      await tester.pumpAndSettle();
      final printButton = find.text('Imprimir comprobante de medición');
      await tester.ensureVisible(printButton);
      await tester.tap(printButton);
      await tester.pumpAndSettle();
      expect(printJobs, hasLength(1));
      expect(
        (printJobs.single['lines'] as List).join('\n'),
        contains(r'TOTAL ESTIMADO: $1.500 COP'),
      );
      expect(
        requests,
        beforePrint,
        reason: 'Bluetooth printing must not use HTTP',
      );
      expect(store.rows.single['command'], originalCommand);
      offline = false;
      await tester.runAsync(() async {
        await session.sync();
        await session.sync();
      });
      expect(posts, hasLength(1));
      expect(posts.single, {
        'personId': 7,
        'prevReading': 100,
        'currentReading': 110,
        'rate': 100.0,
        'fixedCharge': 500.0,
        'subsidy': 0.0,
        'surcharges': 0.0,
      });
      expect(store.rows.single['status'], 'confirmed');
      expect(
        jsonDecode(store.rows.single['result'] as String)['invoiceId'],
        100,
      );
      expect(session.pendingOperations, isEmpty);
      expect(store.persistedPerson['previousReading'], 110);
      expect(
        (await session.invoiceReceipt(100))['operationId'],
        command['operationId'],
      );
      await tester.pumpWidget(const SizedBox());
      await session.lock();
    },
  );
}
