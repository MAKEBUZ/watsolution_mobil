import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../../l10n/app_localizations.dart';
import '../../services/api/person_service.dart';
import '../../services/local_database/unified_database_service.dart';
import 'measurement_registration_simple_page.dart';
import 'select_user_for_measurement_page/widgets/measurement_form_sheet.dart';

class SelectUserForMeasurementPageV2 extends StatefulWidget {
  const SelectUserForMeasurementPageV2({super.key});

  @override
  State<SelectUserForMeasurementPageV2> createState() => _SelectUserForMeasurementPageV2State();
}

class _SelectUserForMeasurementPageV2State extends State<SelectUserForMeasurementPageV2> {
  final UnifiedDatabaseService _unifiedService = UnifiedDatabaseService.instance;
  late Stream<List<Map<String, dynamic>>> _peopleStream;
  bool _isScanningQR = false;

  @override
  void initState() {
    super.initState();
    _peopleStream = _streamPeople();
  }

  void _refresh() {
    setState(() {
      _peopleStream = _streamPeople();
    });
  }

  Stream<List<Map<String, dynamic>>> _streamPeople() async* {
    while (true) {
      try {
        // 1. Intentar traer del backend primero
        final people = await PersonService.instance.getAll(page: 0, size: 500);
        yield people.cast<Map<String, dynamic>>();
      } catch (e) {
        // 2. Fallback: base de datos local
        try {
          final people = await _unifiedService.getPeople();
          yield people;
        } catch (_) {
          yield [];
        }
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  // Función para escanear QR
  Future<void> _scanQR() async {
    setState(() {
      _isScanningQR = true;
    });

    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerForMeasurementV2(),
        ),
      );

      if (result != null && mounted) {
        // Soportar formato nuevo (personId) y formato antiguo (user_id / id / userId)
        final rawUserId = result['personId'] ?? result['user_id'] ?? result['id'] ?? result['userId'];
        final userId = rawUserId is int ? rawUserId : int.tryParse(rawUserId?.toString() ?? '');
        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR sin usuario válido')),
          );
        } else {
          double? initialWater;
          final wmRaw = result['water_measure'] ?? result['waterMeasure'] ?? result['measure'] ?? result['consumo'];
          if (wmRaw is num) {
            initialWater = wmRaw.toDouble();
          } else if (wmRaw is String) {
            initialWater = double.tryParse(wmRaw.replaceAll(',', '.'));
          }

          String? initialObs;
          final obsRaw = result['observation'] ?? result['obs'] ?? result['observacion'];
          if (obsRaw is String && obsRaw.trim().isNotEmpty) {
            initialObs = obsRaw;
          }

          DateTime? initialDate;
          final dateRaw = result['reading_date'] ?? result['date'] ?? result['fecha'];
          if (dateRaw is String && dateRaw.isNotEmpty) {
            initialDate = DateTime.tryParse(dateRaw);
          }

          // Extraer tarifas del QR (formato nuevo)
          final rateRaw = result['rate'];
          final fixedChargeRaw = result['fixedCharge'] ?? result['fixed_charge'];
          final subsidyRaw = result['subsidy'];

          Map<String, dynamic>? person;
          try {
            // 1. Intentar traer del backend directamente
            person = await PersonService.instance.getById(userId);
          } catch (_) {
            // 2. Fallback: buscar en base de datos local
            try {
              final localPeople = await _unifiedService.getPeople();
              person = localPeople.firstWhere(
                (p) => (p['server_id'] ?? p['id']) == userId,
                orElse: () => <String, dynamic>{},
              );
            } catch (_) {}
          }
          if (!mounted) return;
          if (person == null || (person['id'] == null && person['server_id'] == null)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuario no encontrado')),
            );
            return;
          }

          if (!mounted) return;
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
                child: MeasurementFormSheet(
                  person: person!,
                  initialWaterMeasure: initialWater,
                  initialObservation: initialObs,
                  initialReadingDate: initialDate,
                  initialRate: rateRaw != null ? (rateRaw is num ? rateRaw.toDouble() : double.tryParse(rateRaw.toString())) : null,
                  initialFixedCharge: fixedChargeRaw != null ? (fixedChargeRaw is num ? fixedChargeRaw.toDouble() : double.tryParse(fixedChargeRaw.toString())) : null,
                  initialSubsidy: subsidyRaw != null ? (subsidyRaw is num ? subsidyRaw.toDouble() : double.tryParse(subsidyRaw.toString())) : null,
                ),
              );
            },
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanningQR = false;
        });
      }
    }
  }

  // Función para seleccionar usuario de la lista
  void _selectUser(Map<String, dynamic> user) async {
    final userId = user['id'] as int;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeasurementRegistrationSimplePage(userId: userId),
      ),
    );
    if (result == true && mounted) {
      // Notificar a la pantalla anterior que se debe refrescar
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.homeUsers),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear QR',
            onPressed: _isScanningQR ? null : _scanQR,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: cs.primaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: cs.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selecciona un usuario para registrar su medición de agua',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de usuarios
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _peopleStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: cs.error),
                    ),
                  );
                }

                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: cs.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay usuarios registrados',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Puedes escanear un QR para registrar una medición',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final name = user['fullName'] ?? user['full_name'] ?? 'Sin nombre';
                    final doc = user['documentNumber'] ?? user['document_number'] ?? 'Sin documento';
                    final address = user['addresses'];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _selectUser(user),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: cs.primaryContainer,
                                child: Icon(
                                  Icons.person,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Documento: $doc',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: cs.onSurface.withValues(alpha: 0.7),
                                          ),
                                    ),
                                    if (address != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${address['neighborhood'] ?? ''}, ${address['city'] ?? ''}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: cs.onSurface.withValues(alpha: 0.5),
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanningQR ? null : _scanQR,
        icon: _isScanningQR 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_scanner),
        label: Text(_isScanningQR ? 'Escaneando...' : 'Escanear QR'),
      ),
    );
  }
}

// Escáner QR simplificado para selección de usuario
class QRScannerForMeasurementV2 extends StatelessWidget {
  const QRScannerForMeasurementV2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR del Usuario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final raw = barcode.rawValue;
                  if (raw == null) continue;
                  try {
                    final decodedData = json.decode(raw);
                    // Soportar formato nuevo (personId) y antiguo (user_id / id / userId)
                    final rawUserId = decodedData['personId'] ?? decodedData['user_id'] ?? decodedData['id'] ?? decodedData['userId'];
                    final userId = rawUserId is int ? rawUserId : int.tryParse(rawUserId?.toString() ?? '');
                    if (userId != null) {
                      Navigator.pop(context, decodedData);
                      return;
                    }
                  } catch (_) {}
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Text(
                  'Alinea el código QR dentro del marco',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'El código QR debe pertenecer a un usuario registrado',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}