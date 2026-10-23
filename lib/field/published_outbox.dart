import 'dart:convert';
import 'published_work.dart';
import 'billing_calculation.dart';

typedef OutboxUpdate =
    Future<void> Function(String id, String status, String? error);

/// The published API has no idempotency key. Persist intent before POST and
/// reconcile uncertain outcomes by the exact operation marker; never repost.
class PublishedOutbox {
  final WorkRequest request;
  final Future<List<Map<String, Object?>>> Function() load;
  final OutboxUpdate update;
  final Future<void> Function(String, Map<String, dynamic>) acknowledge;
  final void Function() ensureActive;
  final Future<void> Function(String, Map<String, dynamic>)? rememberInvoice;
  PublishedOutbox({
    required this.request,
    required this.load,
    required this.update,
    required this.acknowledge,
    required this.ensureActive,
    this.rememberInvoice,
  });

  static String marker(String id) => '[ws:$id]';

  Future<void> sync() async {
    for (final row in await load()) {
      ensureActive();
      final state = row['status'];
      if (!['pending', 'sending', 'uncertain'].contains(state)) continue;
      final id = row['id'] as String;
      final command = Map<String, dynamic>.from(
        jsonDecode(row['command'] as String),
      );
      final personId = command['personId'] as int;
      if (command['billing'] is Map) {
        await _syncInvoice(row, command);
        continue;
      }
      final response = await request('GET', '/api/meters/by-person/$personId');
      ensureActive();
      if (response.data is! List) {
        throw const FormatException('Historial inválido');
      }
      final rows = response.data as List;
      final matches = rows
          .where(
            (r) =>
                r is Map &&
                r['observation'] is String &&
                (r['observation'] as String).startsWith('${marker(id)} '),
          )
          .toList();
      Map<String, dynamic> ack(dynamic value) {
        final reading = PublishedWork.reading(value);
        if (reading['personId'] != personId ||
            reading['waterMeasure'] != command['waterMeasure'] ||
            reading['readingDate'] != command['readingDate']) {
          throw const FormatException(
            'La confirmación no coincide con la lectura.',
          );
        }
        return {
          'personId': personId,
          'meterId': reading['id'],
          'waterMeasure': reading['waterMeasure'],
          'readingDate': reading['readingDate'],
        };
      }

      if (matches.length == 1) {
        await acknowledge(id, ack(matches.single));
        continue;
      }
      if (matches.length > 1 || state != 'pending') {
        await update(
          id,
          'uncertain',
          'Resultado sin confirmar. No se repetirá el envío; requiere revisión.',
        );
        continue;
      }
      final readings = rows.map(PublishedWork.reading).toList();
      readings.sort((a, b) {
        final date = (b['readingDate'] as String).compareTo(
          a['readingDate'] as String,
        );
        return date != 0 ? date : (b['id'] as int).compareTo(a['id'] as int);
      });
      if (readings.isNotEmpty &&
          ((readings.first['waterMeasure'] as num) >
                  (command['waterMeasure'] as num) ||
              (readings.first['readingDate'] as String).compareTo(
                    command['readingDate'] as String,
                  ) >
                  0)) {
        await update(
          id,
          'conflict',
          'Hay una lectura posterior o mayor en el servidor. Revisa antes de continuar.',
        );
        continue;
      }
      final person = PublishedWork.record(
        (await request('GET', '/api/people/$personId')).data,
      );
      ensureActive();
      if (person['id'] != personId) {
        throw const FormatException('Persona inválida');
      }
      final address = person['address'];
      await update(id, 'sending', null);
      ensureActive();
      try {
        final saved = await request(
          'POST',
          '/api/meters',
          data: {
            'person': {'id': personId},
            if (address is Map && address['id'] is int)
              'address': {'id': address['id']},
            'waterMeasure': command['waterMeasure'],
            'readingDate': command['readingDate'],
            'observation': '${marker(id)} ${command['observation'] ?? ''}',
          },
        );
        ensureActive();
        await acknowledge(id, ack(saved.data));
      } catch (_) {
        ensureActive();
        await update(
          id,
          'uncertain',
          'Confirmación pendiente. Se consultará el resultado sin repetir el envío.',
        );
        rethrow;
      }
    }
  }

  Future<void> _syncInvoice(
    Map<String, Object?> row,
    Map<String, dynamic> command,
  ) async {
    final id = row['id'] as String;
    final personId = command['personId'];
    final billing = Map<String, dynamic>.from(command['billing'] as Map);
    Future<void> confirm(dynamic value) async {
      final invoice = PublishedWork.invoice(value);
      final raw = PublishedWork.record(value);
      final meter = raw['meter'];
      final expected = BillingCalculation(
        previous: command['previousReading'] as num,
        current: command['waterMeasure'] as num,
        rate: billing['rate'] as num,
        fixedCharge: billing['fixedCharge'] as num,
        subsidy: billing['subsidy'] as num,
        surcharges: billing['surcharges'] as num,
      ).total;
      if (invoice['personId'] != personId ||
          invoice['amountDue'] != expected ||
          meter is! Map ||
          meter['id'] is! int ||
          meter['id'] < 1) {
        throw const FormatException('La factura no coincide con la solicitud.');
      }
      await rememberInvoice!(id, {'invoiceId': invoice['id']});
      ensureActive();
      final reading = PublishedWork.reading(
        (await request('GET', '/api/meters/${meter['id']}')).data,
      );
      ensureActive();
      if (reading['personId'] != personId ||
          reading['waterMeasure'] != command['waterMeasure']) {
        throw const FormatException('La medición facturada no coincide.');
      }
      await acknowledge(id, {
        'personId': personId,
        'meterId': reading['id'],
        'waterMeasure': reading['waterMeasure'],
        'readingDate': reading['readingDate'],
        'invoiceId': invoice['id'],
        'amountDue': invoice['amountDue'],
      });
    }

    if (rememberInvoice == null) {
      throw StateError('No hay almacenamiento de confirmación.');
    }
    if (row['result'] is String) {
      final saved = jsonDecode(row['result'] as String);
      if (saved is Map && saved['invoiceId'] is int) {
        await confirm(
          (await request('GET', '/api/invoices/${saved['invoiceId']}')).data,
        );
        return;
      }
    }
    if (row['status'] != 'pending') {
      await update(
        id,
        'uncertain',
        'Factura sin confirmación. Revisa Facturas; no se repetirá automáticamente para evitar duplicados.',
      );
      return;
    }
    final readings = await PublishedWork(
      request,
    ).readings(personId: personId as int);
    ensureActive();
    if (readings.isEmpty ||
        readings.first['id'] != command['previousMeterId'] ||
        readings.first['waterMeasure'] != command['previousReading'] ||
        (command['waterMeasure'] as num) <
            (command['previousReading'] as num)) {
      await update(
        id,
        'conflict',
        'La lectura anterior cambió o falta. Revisa la solicitud de factura antes de enviarla.',
      );
      return;
    }
    await update(id, 'sending', null);
    ensureActive();
    try {
      // This endpoint creates BOTH reading and invoice. Never POST a meter first.
      final response = await request(
        'POST',
        '/api/admin/billing/generate',
        data: {
          'personId': personId,
          'prevReading': command['previousReading'],
          'currentReading': command['waterMeasure'],
          ...billing,
        },
      );
      ensureActive();
      await confirm(response.data);
    } catch (_) {
      ensureActive();
      await update(
        id,
        'uncertain',
        'Factura pendiente de confirmación. Los datos se conservan; no se repetirá el envío.',
      );
      rethrow;
    }
  }
}
