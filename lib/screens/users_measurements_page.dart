import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../app.dart';

class UsersMeasurementsPage extends StatelessWidget {
  final bool useMockData;
  const UsersMeasurementsPage({super.key, this.useMockData = true});

  Future<List<dynamic>> _fetchUsersWithMeters() async {
    final client = Supabase.instance.client;
    final res = await client
        .from('users')
        .select(
            'id, full_name, document_number, status, meters(id, reading_date, water_measure, consumption_m3, observation)')
        .order('full_name');
    return res as List<dynamic>;
  }

  List<Map<String, dynamic>> _mockData() {
    return [
      {
        'id': 1,
        'full_name': 'Ana Pérez',
        'document_number': 'DNI-001',
        'status': 'active',
        'meters': [
          {
            'id': 101,
            'reading_date': '2025-06-12',
            'water_measure': 135.80,
            'consumption_m3': 12.50,
            'observation': 'Sin novedades',
          },
          {
            'id': 102,
            'reading_date': '2025-07-12',
            'water_measure': 148.30,
            'consumption_m3': 12.50,
            'observation': 'Consumo estable',
          },
        ],
      },
      {
        'id': 2,
        'full_name': 'Bruno García',
        'document_number': 'DNI-002',
        'status': 'active',
        'meters': [
          {
            'id': 201,
            'reading_date': '2025-07-01',
            'water_measure': 90.00,
            'consumption_m3': 8.25,
            'observation': 'Fuga reparada recientemente',
          },
        ],
      },
      {
        'id': 3,
        'full_name': 'Carla López',
        'document_number': 'DNI-003',
        'status': 'inactive',
        'meters': [],
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color tileBg() => cs.surface;
    Color tileFg() => cs.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeUsers),
        actions: [
          // Idioma: Español / Inglés
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (value) {
              switch (value) {
                case 'lang_es':
                  appState.setLocale(const Locale('es'));
                  break;
                case 'lang_en':
                  appState.setLocale(const Locale('en'));
                  break;
              }
            },
            itemBuilder: (context) {
              final currentLang = appState.locale.languageCode;
              Color selectedColor(String code) => currentLang == code ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;
              return [
                PopupMenuItem(
                  value: 'lang_es',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: selectedColor('es'), size: 18),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).languageSpanish),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'lang_en',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: selectedColor('en'), size: 18),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).languageEnglish),
                    ],
                  ),
                ),
              ];
            },
          ),
          // Cerrar sesión (NO IMPLEMENTAR: botón deshabilitado)
          IconButton(
            tooltip: AppLocalizations.of(context).logout + ' (no activo)',
            onPressed: null,
            icon: const Icon(Icons.logout),
          ),
          // Cambiar tema
          IconButton(
            tooltip: AppLocalizations.of(context).toggleTheme,
            onPressed: () => appState.toggleTheme(),
            icon: const Icon(Icons.brightness_6),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: useMockData ? Future.value(_mockData()) : _fetchUsersWithMeters(),
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
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context).noMeasurements,
                style: TextStyle(color: cs.onBackground.withOpacity(0.7)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final u = users[index] as Map<String, dynamic>;
              final name = (u['full_name'] ?? '').toString();
              final doc = (u['document_number'] ?? '').toString();
              final status = (u['status'] ?? '').toString();
              final meters = (u['meters'] ?? []) as List<dynamic>;

              return Container(
                decoration: BoxDecoration(
                  color: tileBg(),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    leading: CircleAvatar(
                      backgroundColor: cs.primary.withOpacity(0.15),
                      foregroundColor: cs.primary,
                      child: const Icon(Icons.person_outline),
                    ),
                    title: Text(
                      name.isEmpty ? '—' : name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: tileFg(), fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Doc: ${doc.isEmpty ? '—' : doc} · ${status.isEmpty ? '—' : status}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tileFg().withOpacity(0.7),
                          ),
                    ),
                    children: [
                      if (meters.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: tileFg().withOpacity(0.7)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).noMeasurements,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: tileFg().withOpacity(0.8)),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: meters.map((m) {
                              final mm = m as Map<String, dynamic>;
                              final readingDateStr = (mm['reading_date'] ?? '').toString();
                              DateTime? readingDate;
                              try {
                                readingDate = readingDateStr.isNotEmpty ? DateTime.parse(readingDateStr) : null;
                              } catch (_) {}
                              final waterMeasure = mm['water_measure']?.toString() ?? '—';
                              final consumption = mm['consumption_m3']?.toString() ?? '—';
                              final obs = (mm['observation'] ?? '').toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? cs.surface : cs.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 40,
                                      width: 52,
                                      decoration: BoxDecoration(
                                        color: cs.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.stacked_line_chart, color: cs.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${AppLocalizations.of(context).measurement} • ${readingDate != null ? '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}' : '—'}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: tileFg(),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Agua: $waterMeasure  |  Consumo m³: $consumption',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: tileFg().withOpacity(0.75)),
                                          ),
                                          if (obs.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              obs,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: tileFg().withOpacity(0.6)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}