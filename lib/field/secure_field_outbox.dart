import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_contract.dart';
import 'billing_calculation.dart';
import 'published_work.dart';
import 'published_outbox.dart';

/// Writes intent durably before the first request. A v2 attempt is safe to retry
/// after a lost response; an old, uncertain attempt is never blindly resubmitted.
class SecureFieldOutbox {
  final WorkRequest request;
  final Future<List<Map<String, Object?>>> Function() load;
  final Future<bool> Function(String id) claim;
  final Future<void> Function(String id, String state, String message) update;
  final Future<void> Function(String id, Map<String, dynamic> result)
  acknowledge;
  final void Function() ensureActive;
  SecureFieldOutbox({
    required this.request,
    required this.load,
    required this.claim,
    required this.update,
    required this.acknowledge,
    required this.ensureActive,
  });

  Future<void> sync() async {
    for (final row in await load()) {
      ensureActive();
      if (![
        'pending',
        'sending',
        'retry',
        'uncertain',
        'session',
      ].contains(row['status'])) {
        continue;
      }
      final id = row['id'] as String;
      final command = Map<String, dynamic>.from(
        jsonDecode(row['command'] as String),
      );
      if (command['billing'] is! Map) {
        await update(
          id,
          'correction',
          'Lectura anterior conservada: requiere completar facturación antes del envío.',
        );
        continue;
      }
      // Earlier versions lacked a server idempotency key. Keep their originals.
      if (row['transport'] != 'field-v2' && row['status'] != 'pending') {
        // Recover known old acknowledgements using reads only. Never issue the
        // previous non-idempotent billing POST during an upgrade.
        if (row['result'] is String) {
          final saved = jsonDecode(row['result'] as String);
          if (saved is Map &&
              saved['invoiceId'] is int &&
              saved['invoiceId'] > 0) {
            await PublishedOutbox(
              request: (method, path, {data}) {
                if (method != 'GET') {
                  throw StateError('Solo conciliación de lectura.');
                }
                return request(method, path, data: data);
              },
              load: () async => [
                {...row, 'status': 'uncertain'},
              ],
              ensureActive: ensureActive,
              update: (id, state, message) => update(id, state, message ?? ''),
              rememberInvoice: (_, __) async {},
              acknowledge: acknowledge,
            ).sync();
            continue;
          }
        }
        await update(
          id,
          'uncertain',
          'Envío de una versión anterior conservado. Requiere conciliar la factura antes de reenviar.',
        );
        continue;
      }
      final payload = <String, dynamic>{
        for (final key in [
          'operationId',
          'personId',
          'previousMeterId',
          'waterMeasure',
          'readingDate',
          'observation',
          'billing',
          'tariffId',
        ])
          if (command.containsKey(key)) key: command[key],
      };
      if (!await claim(id)) continue;
      ensureActive();
      try {
        final response = await request(
          'POST',
          '/api/mobile/capture-billing',
          data: payload,
        );
        ensureActive();
        final result = readingAcknowledgement(response.data, command);
        final billing = command['billing'] as Map;
        final expected = BillingCalculation(
          previous: command['previousReading'] as num,
          current: command['waterMeasure'] as num,
          rate: billing['rate'] as num,
          fixedCharge: billing['fixedCharge'] as num,
          subsidy: billing['subsidy'] as num,
          surcharges: billing['surcharges'] as num,
        ).total;
        if (result['invoiceId'] is! int ||
            result['invoiceId'] < 1 ||
            result['amountDue'] != expected) {
          throw const FormatException(
            'La factura no coincide con el comprobante.',
          );
        }
        await acknowledge(id, result);
      } on DioException catch (e) {
        ensureActive();
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
        await update(
          id,
          state,
          state == 'retry'
              ? 'Guardado en la tablet. Se confirmará al recuperar conexión.'
              : 'Original conservado. Revisa sesión, asignación o datos del envío.',
        );
        if (code == 401 || state == 'retry') rethrow;
      } on FormatException {
        await update(
          id,
          'uncertain',
          'Respuesta no coincidente. Original conservado para revisión.',
        );
      }
    }
  }
}
