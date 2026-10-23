import 'package:dio/dio.dart';
import 'billing_calculation.dart';

typedef WorkRequest =
    Future<Response<dynamic>> Function(
      String method,
      String path, {
      dynamic data,
    });

class PublishedWork {
  final WorkRequest request;
  PublishedWork(this.request);

  static Map<String, dynamic> record(dynamic value) {
    if (value is! Map || value['id'] is! int || value['id'] < 1) {
      throw const FormatException(
        'El servidor no confirmó el identificador del registro.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  static Map<String, dynamic> reading(dynamic value) {
    final row = record(value);
    final amount = num.tryParse('${row['waterMeasure']}');
    if (amount == null ||
        !amount.isFinite ||
        amount < 0 ||
        DateTime.tryParse('${row['readingDate']}') == null) {
      throw const FormatException('Lectura inválida.');
    }
    final person = row['person'];
    return {
      'id': row['id'],
      'waterMeasure': amount,
      'readingDate': row['readingDate'].toString().substring(0, 10),
      'personId': person is Map ? person['id'] : null,
      'personName': person is Map ? person['fullName']?.toString() : null,
      'createdBy': row['createdBy']?.toString(),
    };
  }

  static Map<String, dynamic> invoice(dynamic value) {
    final row = record(value);
    final amount = num.tryParse('${row['amountDue']}');
    if (amount == null || !amount.isFinite || amount < 0) {
      throw const FormatException('Factura inválida.');
    }
    final person = row['person'];
    return {
      'id': row['id'],
      'amountDue': amount,
      'status': row['status']?.toString() ?? 'PENDING',
      'issueDate': row['issueDate']?.toString().split('T').first ?? '',
      'personName': person is Map ? person['fullName']?.toString() : null,
      'personId': person is Map ? person['id'] : null,
    };
  }

  Future<List<Map<String, dynamic>>> readings({
    int page = 0,
    int? personId,
  }) async {
    final path = personId == null
        ? '/api/meters?page=$page&size=20&sort=readingDate,DESC'
        : '/api/meters/by-person/$personId';
    final response = await request('GET', path);
    if (response.data is! List) {
      throw const FormatException('Historial inválido.');
    }
    final rows = (response.data as List).map(reading).toList();
    rows.sort((a, b) {
      final order = (b['readingDate'] as String).compareTo(
        a['readingDate'] as String,
      );
      return order != 0 ? order : (b['id'] as int).compareTo(a['id'] as int);
    });
    return rows;
  }

  Future<List<Map<String, dynamic>>> invoices({
    int page = 0,
    int? personId,
  }) async {
    final response = await request(
      'GET',
      personId == null
          ? '/api/invoices?page=$page&size=20&sort=id,DESC'
          : '/api/invoices/by-person/$personId',
    );
    if (response.data is! List) {
      throw const FormatException('Listado de facturas inválido.');
    }
    return (response.data as List).map(invoice).toList();
  }

  Future<Uri> invoiceDownload(int id) async {
    if (id < 1) throw StateError('Factura inválida.');
    final response = await request('GET', '/api/invoices/download/$id');
    final raw = response.data is Map ? response.data['url'] : null;
    final uri = raw is String ? Uri.tryParse(raw) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException(
        'El servidor no devolvió un enlace HTTPS válido.',
      );
    }
    return uri;
  }

  Future<Map<String, dynamic>> invoiceReceipt(int id) async {
    final raw = record((await request('GET', '/api/invoices/$id')).data);
    final bill = invoice(raw);
    if (bill['id'] != id || bill['personId'] is! int) {
      throw const FormatException('La factura no coincide.');
    }
    final meter = raw['meter'];
    if (meter is! Map || meter['id'] is! int) {
      throw StateError('Esta factura no incluye una medición asociada.');
    }
    final measure = reading(
      (await request('GET', '/api/meters/${meter['id']}')).data,
    );
    if (measure['id'] != meter['id'] ||
        measure['personId'] != bill['personId']) {
      throw const FormatException('La medición no corresponde a esta factura.');
    }
    num requiredNumber(String key) {
      final value = num.tryParse('${raw[key]}');
      if (value == null || !value.isFinite || value < 0) {
        throw StateError(
          'La factura no conserva todos los datos necesarios para imprimir el comprobante.',
        );
      }
      return value;
    }

    final consumption = requiredNumber('consumptionM3');
    final current = measure['waterMeasure'] as num;
    final previous = ((current - consumption) * 100).round() / 100;
    final billing = {
      'rate': requiredNumber('ratePerM3'),
      'fixedCharge': requiredNumber('fixedCharge'),
      'subsidy': requiredNumber('subsidyPercent'),
      'surcharges': requiredNumber('additionalCharges'),
    };
    final calculation = BillingCalculation(
      previous: previous,
      current: current,
      rate: billing['rate']!,
      fixedCharge: billing['fixedCharge']!,
      subsidy: billing['subsidy']!,
      surcharges: billing['surcharges']!,
    );
    if (calculation.total != bill['amountDue']) {
      throw StateError(
        'El desglose no coincide con la factura. Descarga el PDF original.',
      );
    }
    return {
      'operationId': 'Factura $id',
      'personId': bill['personId'],
      'personName': bill['personName'],
      'readingDate': measure['readingDate'],
      'previousReading': previous,
      'waterMeasure': current,
      'billing': billing,
    };
  }

  Future<Map<String, dynamic>> person(int id) async {
    final row = record((await request('GET', '/api/people/$id')).data);
    if (row['id'] != id) throw const FormatException('La persona no coincide.');
    final address = row['address'];
    return {
      for (final key in [
        'id',
        'fullName',
        'subscriberNumber',
        'documentNumber',
        'phone',
        'email',
      ])
        key: row[key],
      'address': address is Map
          ? [
              address['neighborhood'],
              address['street'],
              address['houseNumber'],
              address['city'],
            ].where((v) => v != null && v.toString().isNotEmpty).join(', ')
          : null,
    };
  }

  Future<Map<String, dynamic>> save({
    required int personId,
    required double measure,
    required String observation,
    Map<String, double>? billing,
  }) async {
    if (personId < 1 ||
        !measure.isFinite ||
        measure < 0 ||
        measure > 99999999.99 ||
        (measure * 100 - (measure * 100).round()).abs() > 0.00001 ||
        observation.length > 500) {
      throw StateError(
        'Revisa la lectura y la observación (máximo 500 caracteres).',
      );
    }
    final previous = await readings(personId: personId);
    final baseline = previous.isEmpty
        ? 0.0
        : (previous.first['waterMeasure'] as num).toDouble();
    if (measure < baseline) {
      throw StateError(
        'La lectura debe ser igual o mayor que la anterior ($baseline m³).',
      );
    }
    if (billing != null) {
      for (final key in ['rate', 'fixedCharge', 'subsidy', 'surcharges']) {
        final value = billing[key];
        if (value == null ||
            !value.isFinite ||
            value < 0 ||
            value > (key == 'subsidy' ? 1 : 99999999.99)) {
          throw StateError('Revisa los valores de facturación.');
        }
      }
      if (previous.isEmpty) {
        throw StateError(
          'Primero registra una lectura inicial; no hay referencia para facturar consumo.',
        );
      }
      // The deployed billing route creates the reading itself. Never POST a
      // meter first, and never automatically retry this non-idempotent request.
      final response = await request(
        'POST',
        '/api/admin/billing/generate',
        data: {
          'personId': personId,
          'prevReading': baseline,
          'currentReading': measure,
          ...billing,
        },
      );
      return {'kind': 'invoice', ...invoice(response.data)};
    }
    final detail = record((await request('GET', '/api/people/$personId')).data);
    if (detail['id'] != personId) {
      throw const FormatException('La persona devuelta no coincide.');
    }
    final address = detail['address'];
    final now = DateTime.now();
    final response = await request(
      'POST',
      '/api/meters',
      data: {
        'waterMeasure': measure,
        'readingDate':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'observation': observation.trim(),
        'person': {'id': personId},
        if (address is Map && address['id'] is int)
          'address': {'id': address['id']},
      },
    );
    return {'kind': 'reading', ...reading(response.data)};
  }
}
