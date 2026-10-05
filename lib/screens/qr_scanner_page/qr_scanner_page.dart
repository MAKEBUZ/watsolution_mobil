import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../../l10n/app_localizations.dart';
import '../../app.dart';
import '../select_user_for_measurement_page/select_user_for_measurement_page.dart';
import '../select_user_for_measurement_page/widgets/measurement_form_sheet.dart';
import '../../services/local_database/unified_database_service.dart';
import '../../services/api/person_service.dart';
import './qr_scanner_page_functions.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    torchEnabled: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _navigating = false;
  final UnifiedDatabaseService _unifiedService = UnifiedDatabaseService.instance;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_navigating) return;
    final code = QrScannerPageFunctions.extractFirstCode(capture);
    if (code == null) return;
    Map<String, dynamic>? data;
    try {
      data = json.decode(code) as Map<String, dynamic>;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR inválido')),
        );
      }
      return;
    }

    // Soportar formato nuevo (personId) y antiguo (user_id / id / userId)
    final rawUserId = data['personId'] ?? data['user_id'] ?? data['id'] ?? data['userId'];
    final userId = rawUserId is int ? rawUserId : int.tryParse(rawUserId?.toString() ?? '');
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR sin usuario válido')),
        );
      }
      return;
    }

    double? initialWater;
    final wmRaw = data['water_measure'] ?? data['waterMeasure'] ?? data['measure'] ?? data['consumo'];
    if (wmRaw is num) {
      initialWater = wmRaw.toDouble();
    } else if (wmRaw is String) {
      initialWater = double.tryParse(wmRaw.replaceAll(',', '.'));
    }

    String? initialObs;
    final obsRaw = data['observation'] ?? data['obs'] ?? data['observacion'];
    if (obsRaw is String && obsRaw.trim().isNotEmpty) {
      initialObs = obsRaw;
    }

    DateTime? initialDate;
    final dateRaw = data['reading_date'] ?? data['date'] ?? data['fecha'];
    if (dateRaw is String && dateRaw.isNotEmpty) {
      initialDate = DateTime.tryParse(dateRaw);
    }

    // Extraer tarifas del QR (formato nuevo del backend)
    final rateRaw = data['rate'];
    final fixedChargeRaw = data['fixedCharge'] ?? data['fixed_charge'];
    final subsidyRaw = data['subsidy'];

    _navigating = true;
    try {
      await _controller.stop();
    } catch (_) {}

    Map<String, dynamic>? person;
    try {
      // 1. Intentar traer del backend directamente (más confiable)
      person = await PersonService.instance.getById(userId);
    } catch (_) {
      // 2. Fallback: buscar en base de datos local
      try {
        final people = await _unifiedService.getPeople();
        person = people.firstWhere(
          (p) => (p['server_id'] ?? p['id']) == userId,
          orElse: () => <String, dynamic>{},
        );
      } catch (_) {}
    }

    if (person == null || (person['id'] == null && person['server_id'] == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario no encontrado')),
        );
      }
      _navigating = false;
      try {
        await _controller.start();
      } catch (_) {}
      return;
    }
    if (!mounted) return;
    final result = await showDialog<bool>(
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
    _navigating = false;
    try {
      await _controller.start();
    } catch (_) {}
    if (result == true && mounted) {
      // Notificar éxito a la pantalla anterior para refrescar home
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeScanQR),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).homeUsers,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SelectUserForMeasurementPage()),
              );
            },
            icon: const Icon(Icons.people_outline),
          ),
          IconButton(
            tooltip: 'Linterna',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).toggleTheme,
            onPressed: () => appState.toggleTheme(),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: _onDetect,
          ),
          // Overlay de guía
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.9), width: 2),
                ),
              ),
            ),
          ),
          // Texto guía
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Text(
              'Apunta al código QR',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}