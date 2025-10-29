import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/storage_service.dart';
import '../utils/invoice_pdf.dart';
import '../l10n/app_localizations.dart';

class SelectUserForMeasurementPage extends StatefulWidget {
  const SelectUserForMeasurementPage({super.key});

  @override
  State<SelectUserForMeasurementPage> createState() => _SelectUserForMeasurementPageState();
}

class _SelectUserForMeasurementPageState extends State<SelectUserForMeasurementPage> {
  late Stream<List<Map<String, dynamic>>> _peopleStream;
  String? _aiText;
  bool _aiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _peopleStream = Supabase.instance.client
        .from('people')
        .stream(primaryKey: ['id'])
        .order('full_name');
  }

  Future<void> _openMeasurementForm(Map<String, dynamic> person) async {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final name = (person['full_name'] ?? '').toString();
        final doc = (person['document_number'] ?? '').toString();
        final personId = person['id'] as int?;
        final addressId = person['address_id'] as int?;
        final waterCtrl = TextEditingController();
        final obsCtrl = TextEditingController();
        DateTime readingDate = DateTime.now();
        bool isSaving = false;

        String fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setInnerState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.water_drop_outlined, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${loc.measurement} • ${name.isEmpty ? '—' : name}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Doc: ${doc.isEmpty ? '—' : doc}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: waterCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Medición de agua (m³)',
                      prefixIcon: const Icon(Icons.stacked_line_chart),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: readingDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setInnerState(() => readingDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Fecha: ${fmtDate(readingDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observación (opcional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  // AI suggestion block (bilingual, respects theme)
                  _aiSuggestionBlock(
                    context,
                    setInnerState,
                    personId: personId,
                    name: name,
                    document: doc,
                    obsCtrl: obsCtrl,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (personId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(loc.errorLoading)),
                                  );
                                  return;
                                }
                                final wm = double.tryParse(waterCtrl.text.trim());
                                if (wm == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ingrese una medición válida')),
                                  );
                                  return;
                                }
                                setInnerState(() => isSaving = true);
                                try {
                                  final client = Supabase.instance.client;
                                  // Insertar y recuperar la fila insertada para obtener el ID
                                  final inserted = await client
                                      .from('meters')
                                      .insert({
                                        'people_id': personId,
                                        'address_id': addressId,
                                        'water_measure': wm,
                                        'reading_date': fmtDate(readingDate),
                                        'observation': obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                                      })
                                      .select('id, people_id, address_id, water_measure, reading_date, observation')
                                      .single();

                                  // Obtener datos de dirección para la factura si existen
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

                                  // Generar factura PDF
                                  final pdfBytes = await buildInvoicePdf(
                                    InvoiceData(person: person, meter: inserted, address: addrData),
                                  );

                                  // Subir al bucket con una ruta organizada por persona
                                  final personIdStr = personId.toString();
                                  final readingStr = inserted['reading_date']?.toString() ?? fmtDate(readingDate);
                                  final meterIdStr = inserted['id']?.toString() ?? '0';
                                  final fileName = 'factura_${meterIdStr}_$readingStr.pdf';
                                  final path = 'people/$personIdStr/$fileName';
                                  await StorageService().uploadBytes(
                                    path,
                                    pdfBytes,
                                    contentType: 'application/pdf',
                                    upsert: true,
                                  );

                                  // Guardar la ruta de la factura en la medición (si existe la columna)
                                  try {
                                    await client
                                        .from('meters')
                                        .update({'invoice_path': path})
                                        .eq('id', inserted['id']);
                                  } catch (_) {
                                    // Ignorar si la columna no existe o hay restricción de políticas
                                  }

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(loc.invoiceUploaded)),
                                    );
                                  }
                                } catch (e) {
                                  setInnerState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${loc.errorLoading}: ${e.toString()}')),
                                  );
                                }
                              },
                        icon: const Icon(Icons.save_outlined),
                        label: Text(loc.save),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  bool _isEs(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'es';
  }

  Future<void> _loadAiSuggestion({
    required BuildContext context,
    required void Function(void Function()) setState,
    required int? personId,
    required String name,
    required String document,
    required void Function() onLoading,
    required void Function(String text) onResult,
    required void Function(String err) onError,
  }) async {
    try {
      onLoading();
      if (personId == null) {
        onError(_isEs(context) ? 'Usuario no válido.' : 'Invalid user.');
        return;
      }
      final client = Supabase.instance.client;
      final since = DateTime(DateTime.now().year, DateTime.now().month - 3, 1);
      final sinceStr = '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
      final rows = await client
          .from('meters')
          .select('water_measure, reading_date')
          .eq('people_id', personId)
          .gte('reading_date', sinceStr)
          .order('reading_date');

      final Map<String, double> monthly = {};
      for (final r in (rows as List)) {
        final dStr = (r['reading_date'] ?? '').toString();
        final d = DateTime.tryParse(dStr);
        if (d == null) continue;
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        final wm = (r['water_measure'] as num?)?.toDouble() ?? 0.0;
        monthly[key] = (monthly[key] ?? 0) + wm;
      }

      // RAG: enriquecer el contexto con dirección del usuario y promedio del vecindario
      int? userAddressId;
      Map<String, dynamic>? address;
      try {
        final personRow = await client
            .from('people')
            .select('id, full_name, document_number, address_id')
            .eq('id', personId)
            .limit(1);
        if (personRow.isNotEmpty) {
          final p = personRow.first;
          userAddressId = p['address_id'] as int?;
        }
        if (userAddressId != null) {
          final addrList = await client
              .from('addresses')
              .select('id, neighborhood, street, house_number, city')
              .eq('id', userAddressId)
              .limit(1);
          if (addrList.isNotEmpty) {
            address = addrList.first;
          }
        }
      } catch (_) {}

      // Última observación registrada del usuario
      String? lastObservation;
      try {
        final lastRows = await client
            .from('meters')
            .select('observation, reading_date')
            .eq('people_id', personId)
            .order('reading_date', ascending: false)
            .limit(1);
        if (lastRows.isNotEmpty) {
          final m = lastRows.first;
          final obs = m['observation'];
          if (obs != null && obs.toString().trim().isNotEmpty) {
            lastObservation = obs.toString().trim();
          }
        }
      } catch (_) {}

      // Promedio mensual del vecindario (si se conoce el barrio del usuario)
      final Map<String, double> neighborhoodMonthlyAvg = {};
      try {
        final neighborhood = address?['neighborhood']?.toString();
        if (neighborhood != null && neighborhood.isNotEmpty) {
          final addrIdsRes = await client
              .from('addresses')
              .select('id')
              .eq('neighborhood', neighborhood)
              .limit(500);
          final addrIds = <int>[];
          for (final a in addrIdsRes) {
            final id = (a as Map<String, dynamic>)['id'] as int?;
            if (id != null) addrIds.add(id);
          }
                  if (addrIds.isNotEmpty) {
            final rows2 = await client
                .from('meters')
                .select('address_id, water_measure, reading_date')
                .inFilter('address_id', addrIds)
                .gte('reading_date', sinceStr)
                .order('reading_date');
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
        'person': {
          'id': personId,
          'name': name,
          'document': document,
        },
        'address': address,
        'user_monthly_totals_m3': monthly,
        'neighborhood_monthly_avg_m3': neighborhoodMonthlyAvg,
        'last_observation': lastObservation,
      };
      final jsonData = jsonEncode(data);

      final isEs = _isEs(context);
      final prompt = isEs
          ? 'Eres un asistente de consumo de agua para facturación. Con el CONTEXTO estructurado (JSON) que te doy, genera un mensaje CORTO (máx. 2 frases) para la factura: resume el consumo reciente del usuario y compáralo brevemente con el promedio del vecindario si está disponible. Añade una recomendación práctica si aplica. Evita alarmismo y tecnicismos. CONTEXTO:\n$jsonData'
          : 'You are a water consumption assistant for invoicing. Using the structured CONTEXT (JSON) provided, generate a SHORT message (max 2 sentences) for the invoice: summarize the user\'s recent consumption and briefly compare it to the neighborhood average if available. Add a practical recommendation when appropriate. Avoid alarmism and jargon. CONTEXT:\n$jsonData';

      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        onError(isEs ? 'Falta OPENAI_API_KEY en .env' : 'Missing OPENAI_API_KEY in .env');
        return;
      }
      const model = 'gpt-4o-mini';

      final r1 = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': isEs ? 'Eres un asistente de consumo de agua para facturación.' : 'You are a water consumption assistant for invoicing.'
            },
            {
              'role': 'user',
              'content': prompt,
            }
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
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content': isEs ? 'Eres un analista de consumo de agua.' : 'You are a water consumption analyst.'
              },
              {
                'role': 'user',
                'content': prompt,
              }
            ],
          }),
        );
        if (r2.statusCode >= 200 && r2.statusCode < 300) {
          final b2 = jsonDecode(r2.body);
          text = b2['choices']?[0]?['message']?['content']?.toString();
        }
      }

      if (text == null || text.trim().isEmpty) {
        onResult(isEs ? 'No se pudo generar el mensaje.' : 'Could not generate the message.');
      } else {
        onResult(text.trim());
      }
    } catch (e) {
      onError(e.toString());
    }
  }

  Widget _aiSuggestionBlock(BuildContext context, void Function(void Function()) setState, {required int? personId, required String name, required String document, required TextEditingController obsCtrl}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final title = _isEs(context) ? 'Sugerencia AI' : 'AI Suggestion';
    final btn = _isEs(context) ? (_aiText == null ? 'Generar' : 'Actualizar') : (_aiText == null ? 'Generate' : 'Refresh');

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _aiLoading
                    ? null
                    : () {
                        _loadAiSuggestion(
                          context: context,
                          setState: setState,
                          personId: personId,
                          name: name,
                          document: document,
                          onLoading: () => setState(() {
                            _aiLoading = true;
                            _aiError = null;
                            _aiText = null;
                          }),
                          onResult: (t) => setState(() {
                            _aiLoading = false;
                            _aiText = t;
                          }),
                          onError: (e) => setState(() {
                            _aiLoading = false;
                            _aiError = e;
                          }),
                        );
                      },
                icon: _aiLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(btn),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: (_aiLoading || _aiText == null)
                    ? null
                    : () {
                        final t = _aiText!.trim();
                        if (t.isEmpty) return;
                        setState(() {
                          if (obsCtrl.text.trim().isEmpty) {
                            obsCtrl.text = t;
                          } else {
                            obsCtrl.text = '${obsCtrl.text}\n$t';
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_isEs(context) ? 'Copiado a Observación' : 'Copied to Observation')),
                        );
                      },
                icon: const Icon(Icons.copy),
                label: Text(_isEs(context) ? 'Copiar' : 'Copy'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_aiError != null)
            Text(
              _aiError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_aiText != null && _aiError == null)
            Text(
              _aiText!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (_aiText == null && _aiError == null && !_aiLoading)
            Text(
              _isEs(context)
                  ? 'Pulsa el botón para generar una recomendación basada en tu consumo mensual.'
                  : 'Press the button to generate a recommendation based on your monthly consumption.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeUsers),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _peopleStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context).errorLoading,
                  style: TextStyle(color: cs.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final people = snapshot.data ?? [];
          if (people.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context).noMeasurements,
                style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: people.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final u = people[index];
              final name = (u['full_name'] ?? '').toString();
              final doc = (u['document_number'] ?? '').toString();
              final status = (u['status'] ?? '').toString();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: cs.primary.withOpacity(0.15),
                  foregroundColor: cs.primary,
                  child: const Icon(Icons.person_outline),
                ),
                title: Text(name.isEmpty ? '—' : name),
                subtitle: Text('Doc: ${doc.isEmpty ? '—' : doc} · ${status.isEmpty ? '—' : status}'),
                trailing: FilledButton.icon(
                  onPressed: () => _openMeasurementForm(u),
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text('Registrar medición'),
                ),
                onTap: () => _openMeasurementForm(u),
              );
            },
          );
        },
      ),
    );
  }
}