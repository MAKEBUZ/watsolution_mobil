import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/local_database/unified_database_service.dart';
import 'measurement_registration_simple_page.dart';

class UserSelectionForMeasurementPage extends StatefulWidget {
  const UserSelectionForMeasurementPage({super.key});

  @override
  State<UserSelectionForMeasurementPage> createState() => _UserSelectionForMeasurementPageState();
}

class _UserSelectionForMeasurementPageState extends State<UserSelectionForMeasurementPage> {
  final UnifiedDatabaseService _unifiedService = UnifiedDatabaseService.instance;
  bool _isScanning = false;

  // Función para escanear QR
  Future<void> _scanQR() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerForMeasurement(),
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
          _isScanning = false;
        });
      }
    }
  }

  // Función para seleccionar de lista
  Future<void> _selectFromList() async {
    try {
      final users = await _unifiedService.getPeople();
      
      if (!mounted) return;
      
      final selectedUser = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => UserSelectionDialog(users: users),
      );

      if (selectedUser != null && mounted) {
        // Obtener el ID del usuario seleccionado
        final userId = selectedUser['id'] as int;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeasurementRegistrationSimplePage(userId: userId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar usuarios: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Usuario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¿Cómo deseas seleccionar al usuario?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Opción de escanear QR
            Card(
              elevation: 4,
              child: InkWell(
                onTap: _isScanning ? null : _scanQR,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        size: 64,
                        color: cs.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Escanear QR',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Escanea el código QR del usuario',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      if (_isScanning) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'o',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
            ),
            
            const SizedBox(height: 24),
            
            // Opción de seleccionar de lista
            Card(
              elevation: 4,
              child: InkWell(
                onTap: _selectFromList,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.list,
                        size: 64,
                        color: cs.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Seleccionar de Lista',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Elige de una lista de usuarios registrados',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Diálogo para seleccionar usuario de lista
class UserSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  
  const UserSelectionDialog({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Seleccionar Usuario',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final name = user['full_name'] ?? 'Sin nombre';
                  final doc = user['document_number'] ?? 'Sin documento';
                  final address = user['addresses'];
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Documento: $doc'),
                        if (address != null) ...[
                          Text(
                            '${address['neighborhood'] ?? ''}, ${address['city'] ?? ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    onTap: () => Navigator.pop(context, user),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Escáner QR simplificado para medición
class QRScannerForMeasurement extends StatelessWidget {
  const QRScannerForMeasurement({super.key});

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
                        // Validar QR y volver con el ID del usuario
                        Navigator.pop(context, decodedData);
                        return;
                      }
                    } catch (e) {
                      // Ignorar códigos QR no válidos
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('QR inválido: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
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

