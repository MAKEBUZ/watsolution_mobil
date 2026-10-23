import 'package:flutter/material.dart';
import '../../services/local_database/unified_database_service.dart';
import '../../services/api/person_service.dart';
import '../../services/api/meter_service.dart';
import '../../services/api/address_service.dart';
import '../../utils/invoice_pdf.dart';

class SelectUserForMeasurementFunctions {
  static Stream<List<Map<String, dynamic>>> streamPeople() async* {
    while (true) {
      try {
        // 1. Intentar traer del backend primero
        final people = await PersonService.instance.getAll(page: 0, size: 500);
        yield people.cast<Map<String, dynamic>>();
      } catch (e) {
        // 2. Fallback: base de datos local
        try {
          final localPeople = await UnifiedDatabaseService.instance.getPeople();
          yield localPeople;
        } catch (_) {
          yield [];
        }
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  static Future<Map<String, dynamic>> saveMeasurementAndInvoice({
    required Map<String, dynamic> person,
    required int? addressId,
    required double waterMeasure,
    required DateTime readingDate,
    String? observation,
  }) async {
    final personId = person['id'] as int?;
    if (personId == null) throw Exception('Persona sin ID');

    // 1. Guardar medición usando UnifiedDatabaseService (envía al backend con formato correcto y guarda en local)
    final inserted = await UnifiedDatabaseService.instance.createMeter(
      personId: personId,
      addressId: addressId,
      waterMeasure: waterMeasure,
      readingDate: readingDate,
      observation: observation,
    );

    if (inserted == null) {
      throw Exception('No se pudo guardar la medición');
    }

    // 2. Generar PDF localmente para referencia (el backend maneja la generación y subida a S3)
    Map<String, dynamic>? addrData;
    final addrId = inserted['addressId'] ?? inserted['address_id'] ?? addressId;
    if (addrId != null) {
      try {
        addrData = await AddressService.instance.getById(addrId as int);
      } catch (_) {}
    }

    // ignore: unused_local_variable
    final pdfBytes = await buildInvoicePdf(InvoiceData(person: person, meter: inserted, address: addrData));
    final personIdStr = personId.toString();
    final readingStr = (inserted['readingDate'] ?? inserted['reading_date'])?.toString() ?? '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}';
    final meterIdStr = (inserted['id'])?.toString() ?? '0';
    final fileName = 'factura_${meterIdStr}_$readingStr.pdf';
    final path = 'people/$personIdStr/$fileName';

    // Nota: El backend maneja la subida de PDFs a S3. En la app movil,
    // guardamos la referencia del path para compatibilidad.
    try {
      await MeterService.instance.updateById(int.parse(meterIdStr), {
        'id': int.parse(meterIdStr),
        'invoicePath': path,
      });
    } catch (_) {}

    return {'inserted': inserted, 'invoicePath': path};
  }

  static Future<String> generateAiSuggestion(BuildContext context, {required int? personId, required String name, required String document}) async {
    throw StateError('Las recomendaciones se gestionan desde el backend. No se envían datos personales desde el móvil.');
  }
}
