import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../app.dart';

class UsersMeasurementsPage extends StatefulWidget {
  const UsersMeasurementsPage({super.key});

  @override
  State<UsersMeasurementsPage> createState() => _UsersMeasurementsPageState();
}

class _UsersMeasurementsPageState extends State<UsersMeasurementsPage> {
  late Future<List<dynamic>> _usersFuture;

  Future<List<dynamic>> _fetchUsersWithMeters() async {
    final client = Supabase.instance.client;
    final res = await client
        .from('users')
        .select(
            'id, full_name, document_number, status, meters(id, reading_date, water_measure, consumption_m3, observation)')
        .order('full_name');
    return res as List<dynamic>;
  }

  

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsersWithMeters();
  }

  Future<void> _refresh() async {
    setState(() {
      _usersFuture = _fetchUsersWithMeters();
    });
  }

  Future<void> _openCreateUserForm() async {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    // Address controllers
    final neighborhoodCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final houseNumberCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final latitudeCtrl = TextEditingController();
    final longitudeCtrl = TextEditingController();

    bool isSaving = false;

    String? emailValidator(String? v) {
      if (v == null || v.isEmpty) return null; // opcional
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(v)) return loc.invalidEmail;
      return null;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setInnerState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          loc.createUser,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: cs.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: loc.fullName,
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: docCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: loc.documentNumber,
                                prefixIcon: const Icon(Icons.badge_outlined),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: phoneCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: loc.phone,
                                prefixIcon: const Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: emailCtrl,
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: loc.email,
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              validator: emailValidator,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.address,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: cs.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: neighborhoodCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: loc.neighborhood,
                                prefixIcon: const Icon(Icons.location_city),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: streetCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: loc.street,
                                prefixIcon: const Icon(Icons.signpost_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: houseNumberCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: loc.houseNumber,
                                prefixIcon: const Icon(Icons.tag_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: cityCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: loc.city,
                                prefixIcon: const Icon(Icons.location_on_outlined),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: latitudeCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                              decoration: InputDecoration(
                                labelText: loc.latitude,
                                prefixIcon: const Icon(Icons.explore_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: longitudeCtrl,
                              textInputAction: TextInputAction.done,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                              decoration: InputDecoration(
                                labelText: loc.longitude,
                                prefixIcon: const Icon(Icons.explore),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(loc.cancel),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setInnerState(() => isSaving = true);
                                  try {
                                    final client = Supabase.instance.client;
                                    final fullName = nameCtrl.text.trim();
                                    final documentNumber = docCtrl.text.trim();
                                    final phone = phoneCtrl.text.trim();
                                    final email = emailCtrl.text.trim();

                                    // Address values
                                    final neighborhood = neighborhoodCtrl.text.trim();
                                    final street = streetCtrl.text.trim();
                                    final houseNumber = houseNumberCtrl.text.trim();
                                    final city = cityCtrl.text.trim();
                                    final latitude = latitudeCtrl.text.trim();
                                    final longitude = longitudeCtrl.text.trim();

                                    final addrInsert = await client
                                        .from('addresses')
                                        .insert({
                                          'neighborhood': neighborhood,
                                          'street': street.isEmpty ? null : street,
                                          'house_number': houseNumber.isEmpty ? null : houseNumber,
                                          'city': city,
                                          'latitude': latitude.isEmpty ? null : double.tryParse(latitude),
                                          'longitude': longitude.isEmpty ? null : double.tryParse(longitude),
                                        })
                                        .select('id')
                                        .single();

                                    final addressId = addrInsert['id'] as int;

                                    await client.from('users').insert({
                                      'full_name': fullName,
                                      'document_number': documentNumber,
                                      'phone': phone.isEmpty ? null : phone,
                                      'email': email.isEmpty ? null : email,
                                      'status': 'active',
                                      'address_id': addressId,
                                    });

                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(loc.userCreated)),
                                      );
                                      await _refresh();
                                    }
                                  } catch (e) {
                                    setInnerState(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(loc.userCreateError)),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.save_outlined),
                          label: Text(loc.save),
                        ),
                      ],
                    ),
                  ],
                ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateUserForm,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(AppLocalizations.of(context).createUser),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _usersFuture,
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