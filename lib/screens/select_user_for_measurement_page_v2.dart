import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../../l10n/app_localizations.dart';
import '../../services/local_database/unified_database_service.dart';
import 'measurement_registration_simple_page.dart';

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

  Stream<List<Map<String, dynamic>>> _streamPeople() async* {
    while (true) {
      try {
        final people = await _unifiedService.getPeople();
        yield people;
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        print('Error en stream de personas: $e');
        yield [];
        await Future.delayed(const Duration(seconds: 5));
      }
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
        // Obtener el ID del usuario del resultado
        final userId = result['id'] as int;
        
        // Ir directamente a la página de registro simplificada
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeasurementRegistrationSimplePage(userId: userId),
          ),
        );
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
  void _selectUser(Map<String, dynamic> user) {
    // Obtener el ID del usuario seleccionado
    final userId = user['id'] as int;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MeasurementRegistrationSimplePage(userId: userId),
      ),
    );
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
                    final name = user['full_name'] ?? 'Sin nombre';
                    final doc = user['document_number'] ?? 'Sin documento';
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
                  if (barcode.rawValue != null) {
                    try {
                      final decodedData = json.decode(barcode.rawValue!);
                      if (decodedData['type'] == 'user' && decodedData['id'] != null) {
                        Navigator.pop(context, decodedData);
                        return;
                      }
                    } catch (e) {
                      // Ignorar códigos QR no válidos
                    }
                  }
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