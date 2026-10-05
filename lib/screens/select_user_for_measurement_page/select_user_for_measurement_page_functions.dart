import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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
    if (personId == null) {
      throw Exception('Usuario no valido para generar sugerencia');
    }
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final since = DateTime(DateTime.now().year, DateTime.now().month - 3, 1);

    // 1. Obtener mediciones del usuario
    List<dynamic> meters;
    try {
      meters = await MeterService.instance.getByPersonId(personId);
    } catch (e) {
      throw Exception(isEs ? 'Error al cargar mediciones: $e' : 'Error loading measurements: $e');
    }

    final Map<String, double> monthly = {};
    for (final r in meters) {
      final dStr = (r['readingDate'] ?? r['reading_date'] ?? '').toString();
      final d = DateTime.tryParse(dStr);
      if (d == null || d.isBefore(since)) continue;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final wmRaw = r['waterMeasure'] ?? r['water_measure'];
      final double wm;
      if (wmRaw is num) {
        wm = wmRaw.toDouble();
      } else if (wmRaw is String) {
        wm = double.tryParse(wmRaw) ?? 0.0;
      } else {
        wm = 0.0;
      }
      monthly[key] = (monthly[key] ?? 0) + wm;
    }

    // 2. Obtener direccion del usuario
    int? userAddressId;
    Map<String, dynamic>? address;
    try {
      final person = await PersonService.instance.getById(personId);
      userAddressId = person['addressId'] ?? person['address_id'];
      if (userAddressId != null) {
        address = await AddressService.instance.getById(userAddressId);
      }
    } catch (_) {}

    final Map<String, double> neighborhoodMonthlyAvg = {};
    try {
      final neighborhood = address?['neighborhood']?.toString();
      if (neighborhood != null && neighborhood.isNotEmpty) {
        // Nota: El backend no tiene un endpoint para buscar addresses por neighborhood.
        // Esta funcionalidad queda simplificada.
      }
    } catch (_) {}

    final data = {
      'person': {'id': personId, 'name': name, 'document': document},
      'address': address,
      'user_monthly_totals_m3': monthly,
      'neighborhood_monthly_avg_m3': neighborhoodMonthlyAvg,
    };
    final jsonData = jsonEncode(data);

    final prompt = isEs
        ? 'Eres un asistente de consumo de agua para facturacion. Con el CONTEXTO estructurado (JSON) que te doy, genera un mensaje CORTO (max. 2 frases) para la factura: resume el consumo reciente del usuario y comparalo brevemente con el promedio del vecindario si esta disponible. Anade una recomendacion practica si aplica. Evita alarmismo y tecnicismos. CONTEXTO:\n$jsonData'
        : "You are a water consumption assistant for invoicing. Using the structured CONTEXT (JSON) provided, generate a SHORT message (max 2 sentences) for the invoice: summarize the user's recent consumption and briefly compare it to the neighborhood average if available. Add a practical recommendation when appropriate. Avoid alarmism and jargon. CONTEXT:\n$jsonData";

    // 3. Verificar API Key
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(isEs ? 'API Key de OpenAI no configurada. Agrega OPENAI_API_KEY al archivo .env' : 'OpenAI API Key not configured. Add OPENAI_API_KEY to .env file');
    }

    // 4. Llamar a OpenAI
    const model = 'gpt-4o-mini';
    String? text;
    try {
      final r1 = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': isEs ? 'Eres un asistente de consumo de agua para facturacion.' : 'You are a water consumption assistant for invoicing.'},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (r1.statusCode >= 200 && r1.statusCode < 300) {
        final b = jsonDecode(r1.body);
        text = b['choices']?[0]?['message']?['content']?.toString();
      } else if (r1.statusCode == 401) {
        throw Exception(isEs ? 'API Key de OpenAI invalida' : 'Invalid OpenAI API Key');
      } else if (r1.statusCode == 429) {
        throw Exception(isEs ? 'Limite de uso de OpenAI alcanzado' : 'OpenAI rate limit reached');
      } else {
        throw Exception(isEs ? 'Error de OpenAI (${r1.statusCode}): ${r1.body}' : 'OpenAI error (${r1.statusCode}): ${r1.body}');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('OpenAI')) rethrow;
      throw Exception(isEs ? 'Error de conexion con OpenAI: $e' : 'Connection error with OpenAI: $e');
    }

    if (text == null || text.trim().isEmpty) {
      throw Exception(isEs ? 'La IA no genero ninguna respuesta' : 'The AI did not generate any response');
    }
    return text.trim();
  }
}
