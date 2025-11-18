import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app.dart';
import 'select_user_for_measurement_page.dart';

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

  String? _lastCode;
  bool _showingResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchUserById(int id) async {
    final client = Supabase.instance.client;
    final list = await client
        .from('people')
        .select('id, full_name, document_number, phone, email, address_id')
        .eq('id', id)
        .limit(1);
    if (list is List && list.isNotEmpty) {
      final p = list.first as Map<String, dynamic>;
      final addrId = p['address_id'] as int?;
      Map<String, dynamic>? addr;
      if (addrId != null) {
        final addrList = await client
            .from('addresses')
            .select('neighborhood, street, house_number, city')
            .eq('id', addrId)
            .limit(1);
        if (addrList is List && addrList.isNotEmpty) {
          addr = addrList.first as Map<String, dynamic>;
        }
      }
      return {'person': p, 'address': addr};
    }
    return null;
  }

  int? _parseUserIdFromCode(String code) {
    final trimmed = code.trim();
    if (trimmed.startsWith('people:')) {
      final idStr = trimmed.split(':').last;
      final id = int.tryParse(idStr);
      return id;
    }
    return null;
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_showingResult) return;
    final codes = capture.barcodes
        .map((b) => b.rawValue)
        .where((v) => v != null && v!.isNotEmpty)
        .cast<String>()
        .toList();
    if (codes.isEmpty) return;
    _lastCode = codes.first;
    _showingResult = true;
    if (!mounted) return;
    Map<String, dynamic>? userData;
    final parsedId = _parseUserIdFromCode(_lastCode!);
    if (parsedId != null) {
      try {
        userData = await _fetchUserById(parsedId);
      } catch (_) {}
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_2, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).homeScanQR,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (userData == null) ...[
                Text(
                  _lastCode ?? '—',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                ),
              ] else ...[
                Builder(builder: (context) {
                  final loc = AppLocalizations.of(context);
                  final p = userData!['person'] as Map<String, dynamic>;
                  final a = userData!['address'] as Map<String, dynamic>?;
                  final name = (p['full_name'] ?? '').toString();
                  final doc = (p['document_number'] ?? '').toString();
                  final phone = (p['phone'] ?? '').toString();
                  final email = (p['email'] ?? '').toString();
                  final neighborhood = (a?['neighborhood'] ?? '').toString();
                  final street = (a?['street'] ?? '').toString();
                  final houseNumber = (a?['house_number'] ?? '').toString();
                  final city = (a?['city'] ?? '').toString();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? '—' : name, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurface)),
                      const SizedBox(height: 6),
                      Text('Doc: ${doc.isEmpty ? '—' : doc}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.9))),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${loc.phone}: $phone', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.8))),
                      ],
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${loc.email}: $email', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.8))),
                      ],
                      const SizedBox(height: 8),
                      Text(loc.address, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          neighborhood,
                          [street, houseNumber].where((s) => s.isNotEmpty).join(' '),
                          city,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.85)),
                      ),
                    ],
                  );
                }),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _showingResult = false;
                        _lastCode = null;
                      });
                    },
                    child: const Text('Escanear otra vez'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (mounted) {
      setState(() {});
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
            icon: const Icon(Icons.brightness_6),
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
                  border: Border.all(color: cs.primary.withOpacity(0.9), width: 2),
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
                    color: cs.onBackground,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}