import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/storage_service.dart';
import '../../utils/invoice_pdf.dart';

class SelectUserForMeasurementFunctions {
  static Stream<List<Map<String, dynamic>>> streamPeople() {
    return Supabase.instance.client.from('people').stream(primaryKey: ['id']).order('full_name');
  }

  static Future<Map<String, dynamic>> saveMeasurementAndInvoice({
    required Map<String, dynamic> person,
    required int? addressId,
    required double waterMeasure,
    required DateTime readingDate,
    String? observation,
  }) async {
    final client = Supabase.instance.client;
    final inserted = await client
        .from('meters')
        .insert({
          'people_id': person['id'],
          'address_id': addressId,
          'water_measure': waterMeasure,
          'reading_date': '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}',
          'observation': observation?.trim().isEmpty == true ? null : observation,
        })
        .select('id, people_id, address_id, water_measure, reading_date, observation')
        .single();

    Map<String, dynamic>? addrData;
    final addrId = inserted['address_id'] as int?;
    if (addrId != null) {
      final addrList = await client
          .from('addresses')
          .select('neighborhood, street, house_number, city')
          .eq('id', addrId)
          .limit(1);
      if (addrList.isNotEmpty) {
        addrData = addrList.first;
      }
    }

    final pdfBytes = await buildInvoicePdf(InvoiceData(person: person, meter: inserted, address: addrData));
    final personIdStr = inserted['people_id'].toString();
    final readingStr = inserted['reading_date']?.toString() ?? '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}'
        ;
    final meterIdStr = inserted['id']?.toString() ?? '0';
    final fileName = 'factura_${meterIdStr}_$readingStr.pdf';
    final path = 'people/$personIdStr/$fileName';
    await StorageService().uploadBytes(path, pdfBytes, contentType: 'application/pdf', upsert: true);

    try {
      await client.from('meters').update({'invoice_path': path}).eq('id', inserted['id']);
    } catch (_) {}

    return {'inserted': inserted, 'invoicePath': path};
  }

  static Future<String> generateAiSuggestion(BuildContext context, {required int? personId, required String name, required String document}) async {
    if (personId == null) {
      throw Exception('invalid_user');
    }
    final isEs = Localizations.localeOf(context).languageCode == 'es';
    final client = Supabase.instance.client;
    final since = DateTime(DateTime.now().year, DateTime.now().month - 3, 1);
    final sinceStr = '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
    final rows = await client.from('meters').select('water_measure, reading_date').eq('people_id', personId).gte('reading_date', sinceStr).order('reading_date');
    final Map<String, double> monthly = {};
    for (final r in (rows as List)) {
      final dStr = (r['reading_date'] ?? '').toString();
      final d = DateTime.tryParse(dStr);
      if (d == null) continue;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final wm = (r['water_measure'] as num?)?.toDouble() ?? 0.0;
      monthly[key] = (monthly[key] ?? 0) + wm;
    }

    int? userAddressId;
    Map<String, dynamic>? address;
    try {
      final personRow = await client.from('people').select('id, full_name, document_number, address_id').eq('id', personId).limit(1);
      if (personRow.isNotEmpty) {
        final p = personRow.first;
        userAddressId = p['address_id'] as int?;
      }
      if (userAddressId != null) {
        final addrList = await client.from('addresses').select('id, neighborhood, street, house_number, city').eq('id', userAddressId).limit(1);
        if (addrList.isNotEmpty) {
          address = addrList.first;
        }
      }
    } catch (_) {}

    final Map<String, double> neighborhoodMonthlyAvg = {};
    try {
      final neighborhood = address?['neighborhood']?.toString();
      if (neighborhood != null && neighborhood.isNotEmpty) {
        final addrIdsRes = await client.from('addresses').select('id').eq('neighborhood', neighborhood).limit(500);
        final addrIds = <int>[];
        for (final a in addrIdsRes) {
          final id = (a)['id'] as int?;
          if (id != null) addrIds.add(id);
        }
        if (addrIds.isNotEmpty) {
          final rows2 = await client.from('meters').select('address_id, water_measure, reading_date').inFilter('address_id', addrIds).gte('reading_date', sinceStr).order('reading_date');
          final Map<String, double> sums = {};
          final Map<String, int> counts = {};
          for (final r in (rows2 as List)) {
            final dStr = (r['reading_date'] ?? '').toString();
            final d = DateTime.tryParse(dStr);
            if (d == null) continue;
            final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
            final wm = (r['water_measure'] as num?)?.toDouble() ?? 0.0;
            sums[key] = (sums[key] ?? 0) + wm;
            counts[key] = (counts[key] ?? 0) + 1;
          }
          for (final k in sums.keys) {
            final c = counts[k] ?? 1;
            neighborhoodMonthlyAvg[k] = c > 0 ? (sums[k]! / c) : sums[k]!;
          }
        }
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
        ? 'Eres un asistente de consumo de agua para facturación. Con el CONTEXTO estructurado (JSON) que te doy, genera un mensaje CORTO (máx. 2 frases) para la factura: resume el consumo reciente del usuario y compáralo brevemente con el promedio del vecindario si está disponible. Añade una recomendación práctica si aplica. Evita alarmismo y tecnicismos. CONTEXTO:\n$jsonData'
        : "You are a water consumption assistant for invoicing. Using the structured CONTEXT (JSON) provided, generate a SHORT message (max 2 sentences) for the invoice: summarize the user's recent consumption and briefly compare it to the neighborhood average if available. Add a practical recommendation when appropriate. Avoid alarmism and jargon. CONTEXT:\n$jsonData";

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('missing_api_key');
    }
    const model = 'gpt-4o-mini';
    final r1 = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': isEs ? 'Eres un asistente de consumo de agua para facturación.' : 'You are a water consumption assistant for invoicing.'},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    String? text;
    if (r1.statusCode >= 200 && r1.statusCode < 300) {
      final b = jsonDecode(r1.body);
      text = b['choices']?[0]?['message']?['content']?.toString();
    }
    if (text == null) {
      final r2 = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': isEs ? 'Eres un analista de consumo de agua.' : 'You are a water consumption analyst.'},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );
      if (r2.statusCode >= 200 && r2.statusCode < 300) {
        final b2 = jsonDecode(r2.body);
        text = b2['choices']?[0]?['message']?['content']?.toString();
      }
    }
    if (text == null || text.trim().isEmpty) {
      throw Exception('ai_generate_failed');
    }
    return text.trim();
  }
}