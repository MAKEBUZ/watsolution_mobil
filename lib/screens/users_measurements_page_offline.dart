import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../l10n/app_localizations.dart';
import '../app.dart';
import '../utils/storage_service.dart';
import '../utils/qr_service.dart';
import '../config/storage_config.dart';
import '../services/local_database/unified_database_service.dart';

class UsersMeasurementsPageOffline extends StatefulWidget {
  const UsersMeasurementsPageOffline({super.key});

  @override
  State<UsersMeasurementsPageOffline> createState() => _UsersMeasurementsPageOfflineState();
}

class _UsersMeasurementsPageOfflineState extends State<UsersMeasurementsPageOffline> {
  late Stream<List<Map<String, dynamic>>> _peopleStream;
  final UnifiedDatabaseService _unifiedService = UnifiedDatabaseService.instance;
  bool _isOnline = true;

  Stream<List<Map<String, dynamic>>> _streamPeople() async* {
    while (true) {
      try {
        final people = await _unifiedService.getPeople();
        yield people;
        
        // Verificar conectividad
        _checkConnectivity();
        
        // Esperar 5 segundos antes de actualizar
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        print('Error en stream de personas: $e');
        yield [];
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _unifiedService.syncService.isOnline();
    if (mounted && isOnline != _isOnline) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _peopleStream = _streamPeople();
    _checkConnectivity();
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
                    // Indicador de modo offline
                    if (!_isOnline)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off, color: cs.error, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Modo offline - Los datos se sincronizarán cuando haya conexión',
                              style: TextStyle(color: cs.error, fontSize: 12),
                            ),
                          ],
                        ),
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
                                  if (!context.mounted) return;
                                  if (!formKey.currentState!.validate()) return;
                                  setInnerState(() => isSaving = true);
                                  try {
                                    final fullName = nameCtrl.text.trim();
                                    final documentNumber = docCtrl.text.trim();
                                    final phone = phoneCtrl.text.trim();
                                    final email = emailCtrl.text.trim();

                                    // Address values
                                    final neighborhood = neighborhoodCtrl.text.trim();
                                    final street = streetCtrl.text.trim();
                                    final houseNumber = houseNumberCtrl.text.trim();
                                    final city = cityCtrl.text.trim();

                                    // Crear persona usando el servicio unificado
                                    final result = await _unifiedService.createPerson(
                                      fullName: fullName,
                                      documentNumber: documentNumber,
                                      phone: phone.isEmpty ? null : phone,
                                      email: email.isEmpty ? null : email,
                                      neighborhood: neighborhood,
                                      street: street.isEmpty ? null : street,
                                      houseNumber: houseNumber.isEmpty ? null : houseNumber,
                                      city: city,
                                    );

                                    if (result != null) {
                                      // Generar QR si está online
                                      if (_isOnline && result['id'] != null) {
                                        try {
                                          await QrService.createAndUploadUserQr(personId: result['id']);
                                        } catch (_) {}
                                      }
                                    }

                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(loc.userCreated)),
                                    );
                                  } catch (e) {
                                    setInnerState(() => isSaving = false);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${loc.userCreateError}: $e')),
                                    );
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
          // Indicador de conexión
          IconButton(
            icon: Icon(_isOnline ? Icons.wifi : Icons.wifi_off),
            color: _isOnline ? cs.primary : cs.error,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isOnline ? 'Conectado a internet' : 'Sin conexión a internet'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // Botón de sincronización manual
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              try {
                await _unifiedService.syncData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sincronización completada')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al sincronizar: $e')),
                  );
                }
              }
            },
          ),
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
            tooltip: '${AppLocalizations.of(context).logout} (no activo)',
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
                  '${AppLocalizations.of(context).errorLoading}: ${snapshot.error}',
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
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final u = users[index];
              final name = (u['full_name'] ?? '').toString();
              final doc = (u['document_number'] ?? '').toString();
              final status = (u['status'] ?? '').toString();
              final personId = u['id'] as int?;

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
                      backgroundColor: cs.primary.withValues(alpha: 0.15),
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
                            color: tileFg().withValues(alpha: 0.7),
                          ),
                    ),
                    children: [
                      if (personId != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        if (_isOnline) {
                                          await QrService.createAndUploadUserQr(personId: personId);
                                        } else {
                                          // Guardar en cola para generar QR cuando esté online
                                          messenger.showSnackBar(
                                            const SnackBar(content: Text('QR se generará cuando haya conexión')),
                                          );
                                          return;
                                        }
                                        messenger.showSnackBar(const SnackBar(content: Text('QR generado')));
                                      } catch (e) {
                                        messenger.showSnackBar(SnackBar(content: Text('Error al generar QR: $e')));
                                      }
                                    },
                                    icon: const Icon(Icons.qr_code_2),
                                    label: const Text('Generar QR'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        if (!_isOnline) {
                                          messenger.showSnackBar(
                                            const SnackBar(content: Text('Función no disponible en modo offline')),
                                          );
                                          return;
                                        }
                                        final path = 'users/$personId/qr.png';
                                        final url = await StorageService(bucketName: kUsersQrBucket).createSignedUrl(path, const Duration(minutes: 15));
                                        final ok = await launchUrlString(url, webOnlyWindowName: '_blank');
                                        if (!ok) {
                                          messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir el QR')));
                                        }
                                      } catch (_) {
                                        messenger.showSnackBar(const SnackBar(content: Text('No se pudo obtener el QR')));
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Ver QR'),
                                  ),
                                ],
                              ),
                        ),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: personId == null
                            ? null
                            : _streamMetersForPerson(personId),
                        builder: (context, mSnap) {
                          if (mSnap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          if (mSnap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: tileFg().withValues(alpha: 0.7)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context).errorLoading,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: tileFg().withValues(alpha: 0.8)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final meters = mSnap.data ?? const [];
                          if (meters.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: tileFg().withValues(alpha: 0.7)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context).noMeasurements,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: tileFg().withValues(alpha: 0.8)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: meters.map((mm) {
                                final readingDateStr = (mm['reading_date'] ?? '').toString();
                                DateTime? readingDate;
                                try {
                                  readingDate = readingDateStr.isNotEmpty ? DateTime.parse(readingDateStr) : null;
                                } catch (_) {}
                                final waterMeasure = mm['water_measure']?.toString() ?? '—';
                                final obs = (mm['observation'] ?? '').toString();
                                final meterId = mm['id'] as int?;
                                String? invoicePath;
                                final ip = mm['invoice_path'];
                                if (ip is String && ip.isNotEmpty) {
                                  invoicePath = ip;
                                } else if (meterId != null && personId != null) {
                                  final readingLabel = readingDate != null
                                      ? '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}'
                                      : '—';
                                  final fileName = 'factura_${meterId}_$readingLabel.pdf';
                                  invoicePath = 'people/$personId/$fileName';
                                }

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
                                          color: cs.primary.withValues(alpha: 0.15),
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
                                              '${AppLocalizations.of(context).measurementWater}: $waterMeasure',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: tileFg().withValues(alpha: 0.75)),
                                            ),
                                            if (obs.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                obs,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(color: tileFg().withValues(alpha: 0.6)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.download_outlined),
                                        color: tileFg().withValues(alpha: 0.75),
                                onPressed: invoicePath == null || !_isOnline
                                        ? null
                                        : () async {
                                                final messenger = ScaffoldMessenger.of(context);
                                                final loc = AppLocalizations.of(context);
                                                try {
                                                  final url = await StorageService().createSignedUrl(invoicePath!, const Duration(minutes: 15));
                                                  final ok = await launchUrlString(url, webOnlyWindowName: '_blank');
                                                  if (!ok) {
                                                    messenger.showSnackBar(SnackBar(content: Text(loc.invoiceOpenFailed)));
                                                  }
                                                } catch (e) {
                                                  messenger.showSnackBar(SnackBar(content: Text(loc.invoiceFetchFailed)));
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
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

  // Stream para medidores de una persona específica
  Stream<List<Map<String, dynamic>>> _streamMetersForPerson(int personId) async* {
    while (true) {
      try {
        final meters = await _unifiedService.getMetersByPersonId(personId);
        yield meters;
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        print('Error en stream de medidores: $e');
        yield [];
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  @override
  void dispose() {
    _unifiedService.dispose();
    super.dispose();
  }
}