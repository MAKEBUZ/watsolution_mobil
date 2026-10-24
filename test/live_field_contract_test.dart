// Explicit opt-in: connects only to the disposable loopback backend fixture.
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/config/api_config.dart';
import 'package:watsolution_mobil/field/field_session.dart';
import 'package:watsolution_mobil/field/receipt_printer.dart';
import 'secure_offline_session_test.dart' show SecureTestStore;

class FixtureHttpOverrides extends HttpOverrides {}

class LoopbackAdapter implements HttpClientAdapter {
  final Uri base;
  final HttpClient client = HttpOverrides.runWithHttpOverrides(
    () => HttpClient(),
    FixtureHttpOverrides(),
  );
  bool offline = false, loseFirstAcknowledgement = true;
  LoopbackAdapter(this.base);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final path = Uri.parse(options.path).path;
    final request = await client.openUrl(options.method, base.resolve(path));
    options.headers.forEach((key, value) => request.headers.set(key, value));
    if (options.data != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(options.data));
    }
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      [],
      (all, part) => all..addAll(part),
    );
    if (path == '/api/mobile/capture-billing' &&
        loseFirstAcknowledgement &&
        response.statusCode == 200) {
      loseFirstAcknowledgement = false;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return ResponseBody.fromBytes(
      bytes,
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) => client.close(force: force);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configured = Platform.environment['FIELD_CONTRACT_BASE'];
  test(
    'Flutter offline capture and receipt reach real PostgreSQL once after a lost acknowledgement',
    () async {
      final base = Uri.parse(configured!);
      expect(base.scheme, 'http');
      expect(base.host, '127.0.0.1');
      expect(base.port, 58080);
      final adapter = LoopbackAdapter(base);
      final probe = Dio()..httpClientAdapter = adapter;
      final fixture = (await probe.get('$base/fixture')).data as Map;
      final temp = await Directory.systemTemp.createTemp(
        'watsolution-contract-',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final storage = <String, String>{};
      const secure = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(paths, (_) async => temp.path);
      messenger.setMockMethodCallHandler(secure, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'read') return storage[args['key']];
        if (call.method == 'containsKey') {
          return storage.containsKey(args['key']);
        }
        if (call.method == 'write') {
          storage[args['key'] as String] = args['value'] as String;
        }
        if (call.method == 'delete') storage.remove(args['key']);
        return null;
      });
      addTearDown(() async {
        adapter.close(force: true);
        messenger.setMockMethodCallHandler(secure, null);
        messenger.setMockMethodCallHandler(paths, null);
        expect(
          temp.absolute.path.startsWith(
            '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}watsolution-contract-',
          ),
          true,
        );
        await temp.delete(recursive: true);
      });
      await ApiConfig.load(origin: 'https://example.invalid');
      final session = FieldSession(verificationKey: fixture['publicKey']);
      session.api.httpClientAdapter = adapter;
      await session.initialize();
      final store = SecureTestStore()
        ..persistedPerson.addAll(Map<String, dynamic>.from(fixture['person']));
      session.store = store;
      session.onlineOnly = true;
      session.locked = false;
      final now = DateTime.now().toUtc();
      session.credentials = {
        'id': '2',
        'login': 'contract-synthetic',
        'id_token': fixture['token'],
        'authorities': ['ROLE_ADMIN'],
        'offlineIssued': now.toIso8601String(),
        'offlineUntil': now.add(const Duration(hours: 12)).toIso8601String(),
      };
      await session.reload();
      adapter.offline = true;
      await session.saveOnlineReading(
        fixture['person']['id'] as int,
        110,
        'Synthetic contract',
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
      final lines = receiptLines(
        jsonDecode(original as String),
        'Contract synthetic',
      );
      expect(lines.any((line) => line.contains('10 m³')), true);
      adapter.offline = false;
      await session.sync();
      expect(store.rows.single['status'], 'retry');
      await session.sync();
      expect(store.rows.single['status'], 'confirmed');
      expect(store.rows.single['command'], original);
      final result = jsonDecode(store.rows.single['result'] as String);
      expect(result['amountDue'], 6000);
      final counts = (await probe.get(
        '$base/fixture/counts',
        options: Options(
          headers: {'Authorization': 'Bearer ${fixture['token']}'},
        ),
      )).data;
      expect(counts, {'meters': 2, 'invoices': 1});
      await session.lock();
      expect(store.rows.single['command'], original);
    },
    skip: configured == null,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
