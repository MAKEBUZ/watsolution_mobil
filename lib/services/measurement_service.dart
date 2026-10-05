import '../../services/api/meter_service.dart';
import '../../services/api/invoice_service.dart';
import '../../services/local_database/unified_database_service.dart';
import '../../services/local_database/sync_service.dart';

class MeasurementService {
  static final MeasurementService instance = MeasurementService._init();

  MeasurementService._init();

  /// Obtiene la última medición de un usuario para calcular consumo
  Future<double?> getLastWaterMeasure(int personId) async {
    try {
      final meters = await MeterService.instance.getByPersonId(personId);
      if (meters.isEmpty) return null;
      // Ordenar por fecha descendente y tomar la primera
      meters.sort((a, b) {
        final dateA = DateTime.tryParse((a['readingDate'] ?? a['reading_date'] ?? '').toString()) ?? DateTime(1970);
        final dateB = DateTime.tryParse((b['readingDate'] ?? b['reading_date'] ?? '').toString()) ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      final last = meters.first;
      final wmRaw = last['waterMeasure'] ?? last['water_measure'];
      if (wmRaw is num) return wmRaw.toDouble();
      if (wmRaw is String) return double.tryParse(wmRaw);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Crea medición + factura en el backend y guarda en local
  Future<Map<String, dynamic>> createMeasurementAndInvoice({
    required int personId,
    int? addressId,
    required double currentReading,
    double? prevReading,
    required DateTime readingDate,
    String? observation,
    required double ratePerM3,
    required double fixedCharge,
    double subsidyPercent = 0.0,
    double additionalCharges = 0.0,
  }) async {
    final isOnline = await SyncService.instance.isOnline();

    // 1. Crear medición (meter)
    final meterPayload = <String, dynamic>{
      'waterMeasure': currentReading,
      'readingDate': '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}',
      'observation': observation,
      'person': {'id': personId},
    };
    if (addressId != null) {
      meterPayload['address'] = {'id': addressId};
    }

    late final Map<String, dynamic> meter;
    if (isOnline) {
      meter = await MeterService.instance.create(meterPayload);
    } else {
      // Offline: guardar en local y retornar datos simulados
      final localMeter = await UnifiedDatabaseService.instance.createMeter(
        personId: personId,
        addressId: addressId,
        waterMeasure: currentReading,
        readingDate: readingDate,
        observation: observation,
      );
      if (localMeter == null) throw Exception('No se pudo guardar medición local');
      meter = localMeter;
    }

    final meterId = meter['id'] as int?;
    if (meterId == null) throw Exception('La medición no retornó ID');

    // 2. Calcular factura
    final previous = prevReading ?? 0.0;
    final consumption = currentReading - previous;
    final subtotal = consumption * ratePerM3 + fixedCharge;
    final subsidyApplied = subtotal * subsidyPercent;
    final total = subtotal - subsidyApplied + additionalCharges;
    final dueDate = readingDate.add(const Duration(days: 30));

    // 3. Crear factura (invoice)
    final invoicePayload = <String, dynamic>{
      'issueDate': '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}',
      'dueDate': '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
      'consumptionM3': consumption < 0 ? 0 : consumption,
      'amountDue': total.round(),
      'ratePerM3': ratePerM3,
      'fixedCharge': fixedCharge,
      'subsidyPercent': subsidyPercent,
      'additionalCharges': additionalCharges,
      'status': 'PENDING',
      'person': {'id': personId},
      'meter': {'id': meterId},
    };

    late Map<String, dynamic> invoice;
    if (isOnline) {
      try {
        invoice = await InvoiceService.instance.create(invoicePayload);
        // 4. Generar PDF en el backend y subir a S3
        final invoiceId = invoice['id'] as int?;
        if (invoiceId != null) {
          try {
            final updatedInvoice = await InvoiceService.instance.generatePdf(invoiceId);
            invoice = updatedInvoice;
          } catch (e) {
            // Si falla la generación de PDF, la factura ya existe
            invoice = {...invoice, 'pdfError': e.toString()};
          }
        }
      } catch (e) {
        // Si falla la factura, la medición ya se guardó. No propagamos error para no perder la medición.
        invoice = {'error': e.toString(), ...invoicePayload};
      }
    } else {
      invoice = invoicePayload;
    }

    return {
      'meter': meter,
      'invoice': invoice,
      'consumption': consumption < 0 ? 0 : consumption,
      'total': total.round(),
    };
  }
}
