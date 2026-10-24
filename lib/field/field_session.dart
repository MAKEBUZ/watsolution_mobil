import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/api_config.dart';
import 'field_store.dart';
import 'offline_permit.dart';
import 'legacy_quarantine.dart';
import 'operation_policy.dart';
import 'api_contract.dart';
import 'published_work.dart';
import 'published_outbox.dart';
import 'secure_field_outbox.dart';
import 'billing_calculation.dart';
import 'storage_migration.dart';

class FieldSession extends ChangeNotifier {
  static const publicKey = String.fromEnvironment('OFFLINE_VERIFY_KEY_BASE64');
  static const profile = String.fromEnvironment(
    'MOBILE_API_PROFILE',
    defaultValue: 'field-v2',
  );
  final String apiProfile;
  final String verificationKey;
  FieldSession({this.apiProfile = profile, this.verificationKey = publicKey});
  final Dio api = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: false,
    ),
  );
  FieldStore? store;
  Map<String, dynamic>? credentials;
  List<Map<String, dynamic>> people = [];
  List<Map<String, Object?>> operations = [];
  bool busy = false, locked = true, hasSavedSession = false, onlineOnly = false;
  String status = 'Inicia sesión para preparar tu jornada';
  String? error;
  DateTime? preparedAt, permitExpires;
  double? defaultRate, defaultFixedCharge;
  int _generation = 0;
  Timer? _syncTimer, _permitTimer;
  Future<void>? _syncing, _refreshing, _preparing;
  String _installation = '';
  String get _sessionKey => 'session:${ApiConfig.storageOrigin}';
  String get _publishedSessionKey =>
      'published-session:${ApiConfig.storageOrigin}';
  String get _activeSessionKey =>
      onlineOnly ? _publishedSessionKey : _sessionKey;
  String get _revocationsKey =>
      'pending-revocations:${ApiConfig.storageOrigin}';
  bool get secureField => apiProfile == 'field-v2';
  String? tariffId;
  bool get offlineReady => onlineOnly && store != null && preparedAt != null;
  String get login => credentials?['login']?.toString() ?? '';
  bool get isAdmin =>
      (credentials?['authorities'] as List?)?.contains('ROLE_ADMIN') ?? false;
  bool get canWork =>
      isAdmin ||
      ((credentials?['authorities'] as List?)?.contains('ROLE_OPERATOR') ??
          false);
  bool get canAssign => (!onlineOnly || secureField) && isAdmin;
  int get pending =>
      operations.where((o) => isPendingOperation(o['status'])).length;

  Future<dynamic> routeRequest(
    String method,
    String path, {
    dynamic data,
  }) async {
    if (locked || !isAdmin) {
      throw StateError('Solo administradores pueden gestionar recorridos.');
    }
    if (!(path.startsWith('/api/admin/routes/') ||
        (method == 'GET' && path.startsWith('/api/people?')))) {
      throw StateError('Solicitud de recorridos inválida.');
    }
    final response = await _request(method, path, data: data);
    if (locked || !isAdmin) {
      throw StateError('La sesión ya no está disponible.');
    }
    if (path.startsWith('/api/people?')) {
      return {
        'items': response.data,
        'total':
            int.tryParse(response.headers.value('x-total-count') ?? '') ??
            (response.data as List).length,
      };
    }
    return response.data;
  }

  List<Map<String, Object?>> get pendingOperations =>
      operations.where((o) => isPendingOperation(o['status'])).toList();

  Future<Map<String, dynamic>> invoiceReceipt(int invoiceId) async {
    if (locked || !canWork) throw StateError('Inicia sesión para imprimir.');
    for (final op in operations) {
      if (op['status'] != 'confirmed' || op['result'] is! String) continue;
      final result = jsonDecode(op['result'] as String);
      if (result is Map && result['invoiceId'] == invoiceId) {
        final command = Map<String, dynamic>.from(
          jsonDecode(op['command'] as String),
        );
        if (command['billing'] is Map) return command;
      }
    }
    return published.invoiceReceipt(invoiceId);
  }

  PublishedWork get published {
    if (locked || !canWork) {
      throw StateError('Se requiere una sesión administrativa vigente.');
    }
    return PublishedWork(_request);
  }

  Future<List<Map<String, dynamic>>> measurementReference(
    Map<String, dynamic> person,
  ) async {
    if (locked || !canWork || !people.any((p) => p['id'] == person['id'])) {
      throw StateError('Persona no disponible.');
    }
    final generation = _generation;
    var prepared = people.firstWhere((p) => p['id'] == person['id']);
    if (prepared['previousMeterId'] == null && store != null) {
      prepared = await store!.person(person['id'] as int) ?? prepared;
      _requireGeneration(generation);
    }
    if (prepared['previousMeterId'] is int &&
        prepared['previousReading'] is num) {
      person.addAll(prepared);
      for (final row in people.where((p) => p['id'] == person['id'])) {
        row.addAll(prepared);
      }
      return [
        {
          'id': prepared['previousMeterId'],
          'waterMeasure': prepared['previousReading'],
          'readingDate': prepared['previousDate'],
        },
      ];
    }
    if (prepared['referencePrepared'] == true) return [];
    final readings = await published.readings(personId: person['id'] as int);
    _requireGeneration(generation);
    if (readings.isNotEmpty) {
      final latest = readings.first;
      if (latest['personId'] != person['id']) {
        throw const FormatException(
          'La medición no corresponde a esta persona.',
        );
      }
      final reference = <String, dynamic>{
        'referencePrepared': true,
        'previousMeterId': latest['id'],
        'previousReading': latest['waterMeasure'],
        'previousDate': latest['readingDate'],
      };
      if (store != null) {
        await store!.updateReference(person['id'] as int, reference);
      }
      _requireGeneration(generation);
      person.addAll(reference);
      for (final row in people.where((p) => p['id'] == person['id'])) {
        row.addAll(reference);
      }
    }
    return readings;
  }

  String _submissionKey(int personId) =>
      'submission:${ApiConfig.storageOrigin}:${credentials?['id']}:$personId';

  Future<void> resolveSubmission(int personId) async {
    if (locked || !isAdmin) throw StateError('Inicia sesión de nuevo.');
    await secureSession.delete(key: _submissionKey(personId));
  }

  Future<void> cancelPending(String id) => run(() async {
    await checkAccess();
    await store!.cancelPending(id);
    await reload();
    status = 'Registro cancelado antes del envío. No se subirá al servidor.';
  });

  Future<void> savePricing(double rate, double fixedCharge) => run(() async {
    if (!isAdmin) throw StateError('Se requiere administrador.');
    await checkAccess();
    BillingCalculation(
      previous: 0,
      current: 0,
      rate: rate,
      fixedCharge: fixedCharge,
    );
    if (secureField) {
      final response = await _request(
        'POST',
        '/api/mobile/tariff',
        data: {'rate': rate, 'fixedCharge': fixedCharge},
      );
      tariffId = response.data['id'] as String;
    }
    await store!.setMeta(
      'billingPrices',
      jsonEncode({
        'rate': rate,
        'fixedCharge': fixedCharge,
        if (tariffId != null) 'tariffId': tariffId,
      }),
    );
    await reload();
    status = 'Tarifas guardadas para nuevas facturas en esta tablet.';
  });

  Future<Map<String, dynamic>> saveOnlineReading(
    int personId,
    double measure,
    String observation, {
    Map<String, double>? billing,
  }) async {
    if (billing == null) {
      throw StateError(
        'Toda nueva medición debe incluir factura. Completa el precio por m³ y la tarifa fija.',
      );
    }
    if (!onlineOnly ||
        locked ||
        !canWork ||
        !people.any((p) => p['id'] == personId)) {
      throw StateError('Persona no disponible para registro online.');
    }
    if (busy) throw StateError('Espera a que termine la operación actual.');
    if (offlineReady) {
      final generation = _generation;
      final current = store!;
      busy = true;
      notifyListeners();
      try {
        await checkAccess();
        if (!measure.isFinite ||
            measure < 0 ||
            measure > 99999999.99 ||
            (measure * 100 - (measure * 100).round()).abs() > 0.00001 ||
            observation.trim().length > 450) {
          throw StateError(
            'Lectura inválida u observación de más de 450 caracteres.',
          );
        }
        final person = people.firstWhere((p) => p['id'] == personId);
        if (!isAdmin &&
            (tariffId == null ||
                billing['rate'] != defaultRate ||
                billing['fixedCharge'] != defaultFixedCharge ||
                billing['subsidy'] != 0 ||
                billing['surcharges'] != 0)) {
          throw StateError('Usa la tarifa preparada por administración.');
        }
        final previous = person['previousReading'] as num?;
        for (final key in ['rate', 'fixedCharge', 'subsidy', 'surcharges']) {
          final value = billing[key];
          if (value == null ||
              !value.isFinite ||
              value < 0 ||
              value > (key == 'subsidy' ? 1 : 99999999.99)) {
            throw StateError('Revisa los valores de facturación.');
          }
        }
        if (previous == null || person['previousMeterId'] == null) {
          throw StateError(
            'Falta una lectura anterior válida para facturar. Prepara los datos con internet y revisa la referencia del medidor.',
          );
        }
        if (measure < previous) {
          throw StateError('La lectura es menor que la anterior.');
        }
        if (await secureSession.containsKey(key: _submissionKey(personId))) {
          throw StateError(
            'Revisa el envío online sin confirmar de esta persona antes de registrar otra lectura.',
          );
        }
        final now = DateTime.now();
        final id = const Uuid().v4();
        _requireGeneration(generation);
        await current.capture({
          'operationId': id,
          'personId': personId,
          'personName': person['fullName'],
          'waterMeasure': measure,
          'readingDate':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'observation': observation.trim(),
          'billing': Map<String, double>.of(billing),
          if (tariffId != null &&
              billing['rate'] == defaultRate &&
              billing['fixedCharge'] == defaultFixedCharge)
            'tariffId': tariffId,
          'previousMeterId': person['previousMeterId'],
          'previousReading': previous,
          'billingSummary': BillingCalculation(
            previous: previous,
            current: measure,
            rate: billing['rate']!,
            fixedCharge: billing['fixedCharge']!,
            subsidy: billing['subsidy']!,
            surcharges: billing['surcharges']!,
          ).toJson(),
        });
        _requireGeneration(generation);
        await reload();
        status =
            'Medición y solicitud de factura guardadas cifradas. Se enviarán al recuperar conexión.';
        notifyListeners();
        unawaited(sync());
        return {'kind': 'local', 'id': id, 'billing': true};
      } finally {
        busy = false;
        notifyListeners();
      }
    }
    if (operations.any(
      (o) => o['person_id'] == personId && isPendingOperation(o['status']),
    )) {
      throw StateError(
        'Hay una lectura pendiente para esta persona. Revisa Envíos antes de facturar.',
      );
    }
    final key = _submissionKey(personId);
    final generation = _generation;
    busy = true;
    notifyListeners();
    var sent = false;
    try {
      if (await secureSession.containsKey(key: key)) {
        throw StateError(
          'Hay un envío sin confirmar. Revisa el historial y las facturas antes de habilitar otro envío.',
        );
      }
      _requireGeneration(generation);
      final work = PublishedWork((method, path, {data}) async {
        _requireGeneration(generation);
        if (method == 'POST') {
          await secureSession.write(
            key: key,
            value: DateTime.now().toUtc().toIso8601String(),
          );
          _requireGeneration(generation);
          sent = true;
        }
        return _request(method, path, data: data);
      });
      final result = await work.save(
        personId: personId,
        measure: measure,
        observation: observation,
        billing: billing,
      );
      await secureSession.delete(key: key);
      _requireGeneration(generation);
      status = 'Lectura y factura confirmadas en el servidor';
      return result;
    } catch (e) {
      if (sent) {
        throw StateError(
          'No se pudo confirmar el resultado. No se reenviará automáticamente. Revisa Historial y Facturas antes de volver a registrar.',
        );
      }
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _requireGeneration(int value) {
    if (value != _generation) throw StateError('La sesión cambió.');
  }

  Future<void> initialize() async {
    await migrateProductionStorage(secureSession);
    unawaited(retryRemoteLogout());
    await Hive.initFlutter();
    if (await Hive.boxExists('app')) {
      final preferences = await Hive.openBox('app');
      await preferences.delete('jwt_token');
      await preferences.compact();
      await preferences.close();
    }
    _installation =
        await secureSession.read(key: 'installation') ?? const Uuid().v4();
    await secureSession.write(key: 'installation', value: _installation);
    hasSavedSession = await secureSession.containsKey(
      key: apiProfile == 'secure-mobile-v1'
          ? _sessionKey
          : _publishedSessionKey,
    );
    notifyListeners();
  }

  Future<bool> _authenticateDevice() => LocalAuthentication().authenticate(
    localizedReason: 'Desbloquea tus datos de trabajo',
    persistAcrossBackgrounding: true,
  );

  Future<void> signIn(
    String username,
    String password, {
    String? code,
  }) => run(() async {
    if (!await _authenticateDevice()) {
      throw StateError('No se desbloqueó el dispositivo');
    }
    final initialGeneration = _generation;
    unawaited(retryRemoteLogout());
    final response = await api.post(
      '${ApiConfig.baseUrl}/api/authenticate',
      data: {
        'username': username.trim(),
        'password': password,
        if (code != null && code.isNotEmpty) 'code': code.trim(),
      },
    );
    _requireGeneration(initialGeneration);
    final token = accessToken(response.data);
    final accountResponse = await api.get(
      '${ApiConfig.baseUrl}/api/account',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    _requireGeneration(initialGeneration);
    final account = FieldAccount.parse(accountResponse.data);
    await _close();
    final generation = _generation;
    credentials = {
      'id_token': token,
      'id': account.id,
      'login': account.login,
      'authorities': account.roles,
    };
    if (response.data['refresh_token'] is String) {
      credentials!['refresh_token'] = response.data['refresh_token'];
    }
    onlineOnly = apiProfile != 'secure-mobile-v1';
    if (onlineOnly) {
      if (!canWork || (!secureField && !isAdmin)) {
        throw StateError(
          'El contrato publicado requiere administrador para preparar personas.',
        );
      }
      final opened = await FieldStore.open(
        '${ApiConfig.storageOrigin}|published',
        account.id,
        deviceProtected: true,
      );
      if (generation != _generation) {
        await opened.close();
        throw StateError('La sesión cambió.');
      }
      store = opened;
      await quarantineLegacyDatabase();
      _requireGeneration(generation);
      credentials!['offlineUntil'] = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 12))
          .toIso8601String();
      credentials!['offlineIssued'] = DateTime.now().toUtc().toIso8601String();
      if (secureField) await _renewPermit();
      await store!.setMeta(
        'lastSeen',
        DateTime.now().toUtc().toIso8601String(),
      );
      await secureSession.write(
        key: _publishedSessionKey,
        value: jsonEncode(credentials),
      );
      hasSavedSession = true;
      locked = false;
      try {
        await reload();
        await prepare();
        await checkAccess();
        _startTimer();
        unawaited(sync());
      } catch (_) {
        await lock();
        rethrow;
      }
      return;
    }
    if (publicKey.isEmpty) {
      throw StateError('Falta la clave pública para el perfil offline.');
    }
    await quarantineLegacyDatabase();
    _requireGeneration(generation);
    final opened = await FieldStore.open(ApiConfig.storageOrigin, account.id);
    if (generation != _generation) {
      await opened.close();
      throw StateError('La sesión cambió.');
    }
    store = opened;
    await _renewPermit();
    _requireGeneration(generation);
    await secureSession.write(key: _sessionKey, value: jsonEncode(credentials));
    _requireGeneration(generation);
    hasSavedSession = true;
    locked = false;
    await reload();
    _startTimer();
    try {
      await prepare();
    } on DioException catch (e) {
      if ([401, 403].contains(e.response?.statusCode)) rethrow;
      status = 'Sesión abierta. Falta preparar los datos.';
    }
  });

  Future<void> unlock() => run(() async {
    if (apiProfile != 'secure-mobile-v1') {
      if (!await _authenticateDevice()) return;
      final generation = _generation;
      final raw = await secureSession.read(key: _publishedSessionKey);
      _requireGeneration(generation);
      if (raw == null) {
        throw StateError(
          'Inicia sesión con internet para preparar la jornada.',
        );
      }
      final saved = Map<String, dynamic>.from(jsonDecode(raw));
      if (!(saved['authorities'] as List).any(
        (r) => r == 'ROLE_ADMIN' || (secureField && r == 'ROLE_OPERATOR'),
      )) {
        throw StateError('Acceso no permitido.');
      }
      final opened = await FieldStore.open(
        '${ApiConfig.storageOrigin}|published',
        saved['id'] as String,
        deviceProtected: true,
      );
      if (generation != _generation) {
        await opened.close();
        throw StateError('La sesión cambió.');
      }
      credentials = saved;
      store = opened;
      onlineOnly = true;
      try {
        await checkAccess();
      } catch (_) {
        await _close();
        rethrow;
      }
      locked = false;
      await reload();
      _startTimer();
      status = 'Jornada desbloqueada. Puedes guardar lecturas sin internet.';
      unawaited(sync());
      return;
    }
    if (!await _authenticateDevice()) return;
    final generation = _generation;
    final raw = await secureSession.read(key: _sessionKey);
    _requireGeneration(generation);
    if (raw == null) throw StateError('Inicia sesión con internet');
    final saved = Map<String, dynamic>.from(jsonDecode(raw));
    final opened = await FieldStore.open(ApiConfig.storageOrigin, saved['id']);
    if (generation != _generation) {
      await opened.close();
      throw StateError('La sesión cambió.');
    }
    onlineOnly = false;
    credentials = saved;
    store = opened;
    try {
      await checkAccess();
    } catch (_) {
      await _close();
      rethrow;
    }
    _requireGeneration(generation);
    locked = false;
    await reload();
    _startTimer();
    unawaited(sync());
  });

  Future<void> _renewPermit() async {
    final response = await _request(
      'POST',
      '/api/mobile/permit',
      data: {'installationId': _installation},
    );
    credentials!['permit'] = response.data['permit'];
    await checkAccess();
    if (!locked) _startTimer();
  }

  Future<void> checkAccess() async {
    final current = store;
    final session = credentials;
    if (current == null || session == null) {
      throw StateError('Desbloquea la aplicación');
    }
    final generation = _generation;
    final last = await current.meta('lastSeen');
    if (onlineOnly && (!secureField || session['permit'] == null)) {
      final now = DateTime.now().toUtc();
      final expires = DateTime.tryParse('${session['offlineUntil']}');
      final issued = DateTime.tryParse('${session['offlineIssued']}');
      final seen = DateTime.tryParse(last ?? '');
      if (!canWork ||
          expires == null ||
          issued == null ||
          !now.isBefore(expires) ||
          expires.difference(issued) > const Duration(hours: 12) ||
          now.isBefore(issued.subtract(const Duration(minutes: 2))) ||
          (seen != null &&
              now.isBefore(seen.subtract(const Duration(minutes: 2))))) {
        throw StateError(
          'La jornada sin conexión venció. Inicia sesión con internet; las lecturas se conservan.',
        );
      }
      _requireGeneration(generation);
      permitExpires = expires;
      await current.setMeta('lastSeen', now.toIso8601String());
      return;
    }
    final permit = await OfflinePermit.verify(
      token: session['permit'] ?? '',
      publicKey: verificationKey,
      accountId: session['id'],
      installationId: _installation,
      now: DateTime.now().toUtc(),
      lastSeen: last == null ? null : DateTime.tryParse(last),
    );
    _requireGeneration(generation);
    permitExpires = permit.expiresAt;
    await current.setMeta('lastSeen', DateTime.now().toUtc().toIso8601String());
  }

  Future<void> _refresh() async {
    final generation = _generation;
    final response = await api.post(
      '${ApiConfig.baseUrl}/api/session/refresh',
      data: {'refresh_token': credentials?['refresh_token']},
    );
    _requireGeneration(generation);
    final token = accessToken(response.data);
    final refresh = response.data['refresh_token'];
    if (refresh is! String || refresh.isEmpty) {
      throw const FormatException('Renovación de sesión inválida.');
    }
    credentials!['id_token'] = token;
    credentials!['refresh_token'] = refresh;
    await secureSession.write(
      key: _activeSessionKey,
      value: jsonEncode(credentials),
    );
  }

  Future<void> verifyOnlineSession() async {
    if (!onlineOnly || locked) return;
    final generation = _generation;
    try {
      final account = FieldAccount.parse(
        (await _request('GET', '/api/account')).data,
      );
      _requireGeneration(generation);
      if (account.id != credentials?['id'] ||
          !account.roles.any(
            (r) => r == 'ROLE_ADMIN' || (secureField && r == 'ROLE_OPERATOR'),
          )) {
        await _invalidate();
        return;
      }
    } on DioException catch (e) {
      if (generation != _generation) return;
      if (![401, 403].contains(e.response?.statusCode)) {
        status =
            'Sin conexión con el servidor. Puedes guardar lecturas en este dispositivo.';
        notifyListeners();
        return;
      }
      await _invalidate();
      status =
          'Inicia sesión con internet para revalidar el acceso. Las lecturas se conservan.';
      notifyListeners();
    } catch (_) {
      if (generation == _generation) {
        await lock();
        status = 'La consulta online requiere conexión y una sesión vigente.';
        notifyListeners();
      }
    }
  }

  Future<Response<dynamic>> _request(
    String method,
    String path, {
    dynamic data,
  }) async {
    final generation = _generation;
    Future<Response<dynamic>> send() => api.request(
      '${ApiConfig.baseUrl}$path',
      data: data,
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer ${credentials?['id_token']}'},
      ),
    );
    try {
      final response = await send();
      _requireGeneration(generation);
      return response;
    } on DioException catch (e) {
      _requireGeneration(generation);
      if (e.response?.statusCode != 401 ||
          credentials?['refresh_token'] == null) {
        rethrow;
      }
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
      await _refreshing;
      _requireGeneration(generation);
      final response = await send();
      _requireGeneration(generation);
      return response;
    }
  }

  Future<void> prepare() =>
      _preparing ??= _prepare().whenComplete(() => _preparing = null);
  Future<void> _prepare() async {
    if (onlineOnly) {
      await _preparePublished();
      return;
    }
    await _syncing;
    await _renewPermit();
    final generation = _generation;
    final all = <Map<String, dynamic>>[];
    final seen = <int>{};
    int? cursor = 0;
    do {
      final response = await _request(
        'GET',
        '/api/mobile/bootstrap?after=$cursor',
      );
      _requireGeneration(generation);
      if (response.data is! Map || response.data['people'] is! List) {
        throw const FormatException('Preparación inválida.');
      }
      for (final value in response.data['people']) {
        final person = preparedPerson(value);
        if (!seen.add(person['id'])) {
          throw const FormatException('Persona repetida en la preparación.');
        }
        all.add(person);
      }
      final next = response.data['next'] as int?;
      if (next != null && next <= cursor!) {
        throw const FormatException('Paginación inválida');
      }
      cursor = next;
      status = 'Preparando ${all.length} personas…';
      notifyListeners();
    } while (cursor != null);
    _requireGeneration(generation);
    await store!.replacePeople(all);
    _requireGeneration(generation);
    await secureSession.write(key: _sessionKey, value: jsonEncode(credentials));
    status = 'Datos preparados para trabajar sin conexión';
    await reload();
  }

  Future<void> _preparePublished() async {
    if (secureField) {
      await _renewPermit();
      final generation = _generation;
      final rows = <Map<String, dynamic>>[];
      final seen = <int>{};
      int? cursor = 0;
      do {
        final response = await _request(
          'GET',
          '/api/mobile/bootstrap?after=$cursor',
        );
        _requireGeneration(generation);
        for (final value in response.data['people'] as List) {
          final person = preparedPerson(value)..['referencePrepared'] = true;
          if (!seen.add(person['id'])) {
            throw const FormatException('Persona repetida.');
          }
          rows.add(person);
        }
        final next = response.data['next'] as int?;
        if (next != null && next <= cursor!) {
          throw const FormatException('Paginación inválida.');
        }
        cursor = next;
      } while (cursor != null);
      final tariff = (await _request('GET', '/api/mobile/tariff')).data;
      _requireGeneration(generation);
      if (tariff is Map) {
        await store!.setMeta(
          'billingPrices',
          jsonEncode({
            'rate': tariff['rate'],
            'fixedCharge': tariff['fixedCharge'],
            'tariffId': tariff['id'],
          }),
        );
      }
      final previous = await store!.people();
      await store!.withdrawPeople(
        previous
            .map((p) => p['id'] as int)
            .where((id) => !seen.contains(id))
            .toList(),
      );
      await store!.replacePeople(rows);
      await secureSession.write(
        key: _activeSessionKey,
        value: jsonEncode(credentials),
      );
      await reload();
      status = 'Jornada preparada: lecturas y tarifa disponibles sin internet.';
      return;
    }
    if (!isAdmin) {
      throw StateError(
        'La API publicada no documenta asignaciones de operadores. No se descargará el listado global.',
      );
    }
    final generation = _generation;
    final rows = <Map<String, dynamic>>[];
    final seen = <int>{};
    for (var page = 0; page < 1000; page++) {
      final response = await _request(
        'GET',
        '/api/people?page=$page&size=100&sort=id,ASC',
      );
      if (response.data is! List) {
        throw const FormatException('Listado de personas inválido.');
      }
      for (final value in response.data) {
        final person = publicPerson(value);
        if (!seen.add(person['id'])) {
          throw const FormatException('La API no respeta la paginación.');
        }
        rows.add(person);
      }
      if ((response.data as List).length < 100) {
        _requireGeneration(generation);
        if (locked) return;
        if (store != null) {
          for (var index = 0; index < rows.length; index++) {
            final person = rows[index];
            final readings = await published.readings(
              personId: person['id'] as int,
            );
            _requireGeneration(generation);
            if (readings.any((r) => r['personId'] != person['id'])) {
              throw const FormatException(
                'Historial de otra persona en la preparación.',
              );
            }
            person['referencePrepared'] = true;
            if (readings.isNotEmpty) {
              final reference = readings.first;
              person.addAll({
                'previousMeterId': reference['id'],
                'previousReading': reference['waterMeasure'],
                'previousDate': reference['readingDate'],
              });
            }
            status =
                'Preparando mediciones: ${index + 1}/${rows.length} personas';
            notifyListeners();
          }
          _requireGeneration(generation);
          await store!.replacePeople(rows);
          _requireGeneration(generation);
          await reload();
        } else {
          people = rows;
        }
        status = store == null
            ? 'Datos consultados'
            : 'Personas preparadas. Puedes registrar lecturas sin internet.';
        notifyListeners();
        return;
      }
    }
    throw StateError('El listado supera el límite de preparación.');
  }

  Future<void> capture(
    Map<String, dynamic> person,
    double reading,
    String observation,
  ) => run(() async {
    if (onlineOnly) {
      throw StateError(
        'La API publicada no permite confirmar reintentos sin duplicados. La captura offline permanece deshabilitada.',
      );
    }
    await checkAccess();
    if (preparedAt == null) {
      throw StateError('Prepara los datos antes de registrar');
    }
    if (!reading.isFinite ||
        reading < 0 ||
        reading > 99999999.99 ||
        (reading * 100 - (reading * 100).round()).abs() > 0.00001) {
      throw StateError('Ingresa una lectura válida con máximo dos decimales');
    }
    final previous = person['previousReading'] as num?;
    if (previous != null && reading < previous) {
      throw StateError(
        'La lectura es menor que la anterior. Requiere revisión del medidor.',
      );
    }
    if (observation.trim().length > 500) {
      throw StateError('La observación supera 500 caracteres.');
    }
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await store!.capture({
      'operationId': const Uuid().v4(),
      'personId': person['id'],
      'previousMeterId': person['previousMeterId'],
      'waterMeasure': reading,
      'readingDate': date,
      'observation': observation.trim(),
    });
    await reload();
    status = 'Lectura guardada en este dispositivo';
    unawaited(sync());
  });

  Future<List<Map<String, dynamic>>> readingHistory(int personId) async {
    if (locked || !canWork || !people.any((p) => p['id'] == personId)) {
      throw StateError('Persona no disponible en esta sesión.');
    }
    final response = await _request('GET', '/api/meters/by-person/$personId');
    if (response.data is! List) {
      throw const FormatException('Historial inválido.');
    }
    final rows = <Map<String, dynamic>>[];
    for (final value in response.data) {
      if (value is! Map) throw const FormatException('Lectura inválida.');
      final measure = num.tryParse('${value['waterMeasure']}');
      final date = DateTime.tryParse('${value['readingDate']}');
      if (measure == null || !measure.isFinite || measure < 0 || date == null) {
        throw const FormatException('Lectura inválida.');
      }
      rows.add({
        'waterMeasure': measure,
        'readingDate': date.toIso8601String().substring(0, 10),
      });
    }
    rows.sort(
      (a, b) =>
          (b['readingDate'] as String).compareTo(a['readingDate'] as String),
    );
    return rows;
  }

  Future<void> sync() => _preparing != null
      ? Future<void>.value()
      : _syncing ??= (onlineOnly ? _synchronizePublished() : _synchronize())
            .whenComplete(() => _syncing = null);

  Future<void> purgeConfirmedCopies() => run(() async {
    final current = store;
    if (locked || current == null) throw StateError('Desbloquea tu jornada.');
    final generation = _generation;
    final account = FieldAccount.parse(
      (await _request('GET', '/api/account')).data,
    );
    _requireGeneration(generation);
    if (account.id != credentials?['id']) throw StateError('La sesión cambió.');
    final removed = await current.purgeConfirmedCopies(DateTime.now().toUtc());
    _requireGeneration(generation);
    await reload();
    status =
        '$removed copias confirmadas de más de 90 días retiradas de esta tablet. Las lecturas pendientes se conservan; las facturas siguen en Historial.';
  });

  Future<void> _synchronizePublished() async {
    final current = store;
    if (locked || current == null) return;
    final generation = _generation;
    try {
      // A successful account call is required immediately before sending.
      final account = FieldAccount.parse(
        (await _request('GET', '/api/account')).data,
      );
      if (account.id != credentials?['id'] ||
          !account.roles.any(
            (r) => r == 'ROLE_ADMIN' || (secureField && r == 'ROLE_OPERATOR'),
          )) {
        await _invalidate();
        return;
      }
      credentials!['authorities'] = account.roles;
      if (secureField) {
        await _renewPermit();
        final ids = (await current.people())
            .map((p) => p['id'] as int)
            .toList();
        for (var offset = 0; offset < ids.length; offset += 100) {
          final batch = ids.sublist(offset, min(offset + 100, ids.length));
          final response = await _request(
            'POST',
            '/api/mobile/access/check',
            data: {'personIds': batch},
          );
          _requireGeneration(generation);
          final allowed = (response.data['allowedIds'] as List)
              .cast<int>()
              .toSet();
          if (allowed.any((id) => !batch.contains(id))) {
            throw const FormatException('Respuesta de permisos inválida.');
          }
          await current.withdrawPeople(
            batch.where((id) => !allowed.contains(id)).toList(),
          );
        }
        await secureSession.write(
          key: _activeSessionKey,
          value: jsonEncode(credentials),
        );
        await SecureFieldOutbox(
          request: _request,
          load: current.operations,
          ensureActive: () {
            _requireGeneration(generation);
            if (locked) throw StateError('Sesión bloqueada.');
          },
          claim: (id) async =>
              await current.db.rawUpdate(
                'UPDATE outbox SET status = ?, transport = ? WHERE id = ? AND (status = ? OR (transport = ? AND status IN (?, ?, ?, ?)))',
                [
                  'sending',
                  'field-v2',
                  id,
                  'pending',
                  'field-v2',
                  'sending',
                  'retry',
                  'uncertain',
                  'session',
                ],
              ) ==
              1,
          update: (id, state, message) async {
            await current.db.update(
              'outbox',
              {'status': state, 'error': message},
              where: 'id = ?',
              whereArgs: [id],
            );
          },
          acknowledge: current.acknowledge,
        ).sync();
      } else {
        await checkAccess();
        await PublishedOutbox(
          request: _request,
          load: current.operations,
          ensureActive: () {
            _requireGeneration(generation);
            if (locked) throw StateError('Sesión bloqueada');
          },
          update: (id, state, message) async {
            final count = await current.db.update(
              'outbox',
              {'status': state, 'error': message},
              where: state == 'sending' ? 'id = ? AND status = ?' : 'id = ?',
              whereArgs: state == 'sending' ? [id, 'pending'] : [id],
            );
            if (state == 'sending' && count != 1) {
              throw StateError(
                'El registro fue cancelado o cambió antes del envío.',
              );
            }
          },
          acknowledge: current.acknowledge,
          rememberInvoice: (id, result) async {
            await current.db.update(
              'outbox',
              {'result': jsonEncode(result)},
              where: 'id = ?',
              whereArgs: [id],
            );
          },
        ).sync();
      }
      _requireGeneration(generation);
      await reload();
      final confirmed = operations
          .where((o) => o['status'] == 'confirmed')
          .length;
      final waiting = operations.where((o) => o['status'] == 'pending').length;
      final review = operations
          .where(
            (o) => ![
              'confirmed',
              'pending',
              'cancelled',
              'reviewed',
            ].contains(o['status']),
          )
          .length;
      status = operations.isEmpty
          ? 'No hay registros guardados para enviar.'
          : 'Revisión terminada: $confirmed confirmados, $waiting por enviar y $review por revisar.'
                '${review > 0 ? ' Los registros por revisar no se repiten automáticamente para evitar facturas duplicadas.' : ''}';
    } on DioException catch (e) {
      if (generation != _generation) return;
      final code = e.response?.statusCode;
      if ([401, 403].contains(code)) {
        await _invalidate();
        status =
            'El servidor rechazó la sesión o sus permisos. Inicia sesión nuevamente; los registros locales se conservan.';
      } else {
        status = code == null
            ? 'No se pudo conectar con el servidor. Comprueba internet e inténtalo de nuevo. Los registros siguen guardados en la tablet.'
            : 'El servidor respondió HTTP $code. No se completó la sincronización. Los registros se conservan; revisa el estado de cada envío.';
      }
    } catch (_) {
      if (generation == _generation) {
        status =
            'Lecturas conservadas. Revisa la jornada y los estados en Envíos.';
      }
    } finally {
      if (generation == _generation) await reload();
      notifyListeners();
    }
  }

  Future<void> _synchronize() async {
    final current = store;
    if (locked || current == null) return;
    final generation = _generation;
    try {
      await checkAccess();
      final account = FieldAccount.parse(
        (await _request('GET', '/api/account')).data,
      );
      _requireGeneration(generation);
      if (account.id != credentials!['id']) {
        throw const FormatException('La identidad de la sesión cambió.');
      }
      credentials!['authorities'] = account.roles;
      final ids = (await current.people()).map((p) => p['id'] as int).toList();
      for (var offset = 0; offset < ids.length; offset += 100) {
        final batch = ids.sublist(offset, min(offset + 100, ids.length));
        final response = await _request(
          'POST',
          '/api/mobile/access/check',
          data: {'personIds': batch},
        );
        _requireGeneration(generation);
        final allowed = (response.data['allowedIds'] as List)
            .cast<int>()
            .toSet();
        if (allowed.any((id) => !batch.contains(id))) {
          throw const FormatException('Respuesta de permisos inválida');
        }
        await current.withdrawPeople(
          batch.where((id) => !allowed.contains(id)).toList(),
        );
        await reload();
      }
      for (final op in await current.operations()) {
        _requireGeneration(generation);
        if (locked) return;
        if (!['pending', 'retry', 'sending'].contains(op['status']) ||
            (op['retry_at'] as int) > DateTime.now().millisecondsSinceEpoch) {
          continue;
        }
        final id = op['id'] as String;
        try {
          await current.db.update(
            'outbox',
            {'status': 'sending'},
            where: 'id = ?',
            whereArgs: [id],
          );
          final command = jsonDecode(op['command'] as String) as Map;
          final response = await _request(
            'POST',
            '/api/mobile/sync/push',
            data: command,
          );
          _requireGeneration(generation);
          await current.acknowledge(
            id,
            readingAcknowledgement(response.data, command),
          );
        } on DioException catch (e) {
          _requireGeneration(generation);
          final code = e.response?.statusCode;
          final state = code == 401
              ? 'session'
              : code == 403
              ? 'quarantine'
              : code == 409
              ? 'conflict'
              : [400, 422].contains(code)
              ? 'correction'
              : 'retry';
          final attempts = (op['attempts'] as int) + 1;
          final seconds = retryDelaySeconds(
            attempts,
            e.response?.headers.value('retry-after'),
          );
          await current.db.update(
            'outbox',
            {
              'status': state,
              'attempts': attempts,
              'retry_at': DateTime.now()
                  .add(Duration(seconds: seconds))
                  .millisecondsSinceEpoch,
              'error': state == 'retry'
                  ? 'No se pudo confirmar el envío. Se reintentará.'
                  : 'Requiere revisión autorizada.',
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          if (code == 401 || code == 403) {
            await _invalidate();
            return;
          }
          if (state == 'retry') break;
        }
      }
      _requireGeneration(generation);
      await reload();
      status = pending == 0
          ? 'No hay envíos pendientes; consulta el estado de cada registro.'
          : '$pending registros pendientes';
    } on DioException catch (e) {
      if (generation != _generation) return;
      if ([401, 403].contains(e.response?.statusCode)) await _invalidate();
      status = 'Trabajo conservado. Revisa conexión o inicia sesión de nuevo.';
    } on FormatException {
      if (generation == _generation) await lock();
      status = 'Trabajo conservado. Revisa permiso o respuesta del servidor.';
    } on StateError {
      if (generation == _generation) {
        await lock();
        status = 'Revisa acceso y sesión. Los pendientes se conservan.';
      }
    } catch (_) {
      if (generation == _generation) {
        status = 'Trabajo conservado. Revisa conexión y acceso.';
      }
    } finally {
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> operators() async {
    if (!canAssign) {
      throw StateError('Asignaciones no disponibles en esta sesión.');
    }
    await checkAccess();
    final result = <Map<String, dynamic>>[];
    int? cursor = 0;
    do {
      final response = await _request(
        'GET',
        '/api/mobile/operators?after=$cursor',
      );
      result.addAll(
        (response.data['operators'] as List).map(
          (row) => Map<String, dynamic>.from(row),
        ),
      );
      final next = response.data['next'] as int?;
      if (next != null && next <= cursor!) {
        throw const FormatException('Paginación inválida');
      }
      cursor = next;
    } while (cursor != null);
    return result;
  }

  Future<void> assign(int personId, int? operatorId) => run(() async {
    if (!canAssign) {
      throw StateError('Asignaciones no disponibles en esta sesión.');
    }
    await checkAccess();
    await _request(
      'POST',
      '/api/mobile/assign',
      data: {'personId': personId, 'operatorId': operatorId},
    );
    status = 'Asignación actualizada en el servidor';
  });
  Future<void> reviewRejected(String id, String reason) => run(() async {
    final explanation = reviewReason(reason);
    await checkAccess();
    await prepare();
    await checkAccess();
    await store!.reviewRejected(id, explanation);
    await reload();
    status =
        'Original conservado. Revisa la lectura actual antes de registrar otra.';
  });
  Future<void> resumeQuarantined(String id) => run(() async {
    await checkAccess();
    await prepare();
    await checkAccess();
    await store!.resumeQuarantined(id);
    await reload();
    await sync();
  });
  Future<void> retry() => run(() async {
    status = 'Sincronizando: comprobando conexión y registros pendientes…';
    notifyListeners();
    if (_preparing != null) {
      status =
          'Se están preparando los datos. Espera a que termine y vuelve a sincronizar.';
      return;
    }
    if (onlineOnly) {
      await sync();
      return;
    }
    await checkAccess();
    await store!.db.update(
      'outbox',
      {'status': 'pending', 'retry_at': 0},
      where: 'status IN (?, ?)',
      whereArgs: ['retry', 'session'],
    );
    await sync();
  });
  Future<void> reload() async {
    final current = store;
    final generation = _generation;
    if (current == null) return;
    final nextPeople = await current.people();
    final nextOperations = await current.operations();
    final pricingRaw = await current.meta('billingPrices');
    final pricing = pricingRaw == null ? null : jsonDecode(pricingRaw) as Map;
    final nextPrepared = DateTime.tryParse(
      await current.meta('preparedAt') ?? '',
    );
    if (generation != _generation || current != store) return;
    people = nextPeople;
    operations = nextOperations;
    preparedAt = nextPrepared;
    defaultRate = (pricing?['rate'] as num?)?.toDouble();
    defaultFixedCharge = (pricing?['fixedCharge'] as num?)?.toDouble();
    tariffId = pricing?['tariffId'] as String?;
    notifyListeners();
  }

  void _startTimer() {
    _syncTimer?.cancel();
    _permitTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(sync()),
    );
    if (permitExpires != null) {
      _permitTimer = Timer(
        permitExpires!.difference(DateTime.now().toUtc()),
        () => unawaited(lock()),
      );
    }
  }

  Future<void> _close() async {
    _generation++;
    _syncTimer?.cancel();
    _permitTimer?.cancel();
    final closing = store;
    store = null;
    people = [];
    operations = [];
    preparedAt = null;
    credentials = null;
    defaultRate = defaultFixedCharge = null;
    tariffId = null;
    permitExpires = null;
    await closing?.close();
  }

  Future<void> lock() async {
    locked = true;
    notifyListeners();
    await _close();
    notifyListeners();
  }

  Future<void> _invalidate() async {
    final key = onlineOnly ? _publishedSessionKey : _sessionKey;
    hasSavedSession = false;
    await lock();
    await secureSession.delete(key: key);
  }

  Future<bool> retryRemoteLogout() async {
    try {
      final raw = await secureSession.read(key: _revocationsKey);
      if (raw == null) return true;
      final tokens = (jsonDecode(raw) as List).cast<String>();
      for (final refresh in tokens) {
        await api.post(
          '${ApiConfig.baseUrl}/api/session/logout',
          data: {'refresh_token': refresh},
        );
      }
      // Never remove a revocation appended while this request was running.
      if (await secureSession.read(key: _revocationsKey) == raw) {
        await secureSession.delete(key: _revocationsKey);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() => run(() async {
    final refresh = credentials?['refresh_token'];
    final token = credentials?['id_token'];
    final sessionKey = _activeSessionKey;
    await lock();
    hasSavedSession = false;
    try {
      if (refresh is String) {
        final raw = await secureSession.read(key: _revocationsKey);
        final pending = raw == null
            ? <String>[]
            : (jsonDecode(raw) as List).cast<String>();
        if (!pending.contains(refresh)) pending.add(refresh);
        await secureSession.write(
          key: _revocationsKey,
          value: jsonEncode(pending),
        );
      }
    } finally {
      await secureSession.delete(key: sessionKey);
    }
    var revoked = false;
    if (refresh is String) {
      revoked = await retryRemoteLogout();
    } else if (token is String) {
      try {
        await api.post(
          '${ApiConfig.baseUrl}/api/session/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        revoked = true;
      } catch (_) {
        /* Older sessions may have no refresh token. */
      }
    }
    status = revoked
        ? 'Sesión cerrada. Las lecturas pendientes permanecen cifradas.'
        : 'Datos bloqueados en la tablet. Cierre remoto pendiente de conexión; las lecturas se conservan.';
  });
  Future<void> run(Future<void> Function() task) async {
    if (busy) {
      error = 'Espera a que termine la operación actual.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await task();
    } catch (e) {
      error = e is StateError
          ? e.message.toString()
          : e is FormatException
          ? e.message
          : 'No se pudo completar la operación. Revisa conexión y acceso; los datos se conservan.';
      if (e is FormatException) await lock();
      if (!locked &&
          e is DioException &&
          [401, 403].contains(e.response?.statusCode)) {
        await _invalidate();
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
