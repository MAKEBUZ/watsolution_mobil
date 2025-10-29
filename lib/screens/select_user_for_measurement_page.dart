import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';

class SelectUserForMeasurementPage extends StatefulWidget {
  const SelectUserForMeasurementPage({super.key});

  @override
  State<SelectUserForMeasurementPage> createState() => _SelectUserForMeasurementPageState();
}

class _SelectUserForMeasurementPageState extends State<SelectUserForMeasurementPage> {
  late Stream<List<Map<String, dynamic>>> _peopleStream;

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
                                  await client.from('meters').insert({
                                    'people_id': personId,
                                    'address_id': addressId,
                                    'water_measure': wm,
                                    'reading_date': fmtDate(readingDate),
                                    'observation': obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                                  });
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Medición registrada')),
                                    );
                                  }
                                } catch (e) {
                                  setInnerState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(loc.errorLoading)),
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
                style: TextStyle(color: cs.onBackground.withOpacity(0.7)),
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