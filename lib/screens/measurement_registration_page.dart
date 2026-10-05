import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/local_database/unified_database_service.dart';
import '../services/api/person_service.dart';

class MeasurementRegistrationPage extends StatefulWidget {
  const MeasurementRegistrationPage({super.key});

  @override
  State<MeasurementRegistrationPage> createState() => _MeasurementRegistrationPageState();
}

class _MeasurementRegistrationPageState extends State<MeasurementRegistrationPage> {
  final UnifiedDatabaseService _unifiedService = UnifiedDatabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  final _waterMeasureController = TextEditingController();
  final _observationController = TextEditingController();
  
  // Datos del usuario escaneado
  Map<String, dynamic>? _scannedUser;
  bool _isOnline = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _unifiedService.syncService.isOnline();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  // Función para procesar el QR escaneado
  Future<void> _processScannedQR(String qrData) async {
    try {
      final decodedData = json.decode(qrData);
      
      // Soportar formato nuevo (personId) y antiguo (type == 'user' + id)
      final rawUserId = decodedData['personId'] ?? decodedData['id'];
      if (rawUserId == null) {
        throw Exception('QR inválido: no es un usuario válido');
      }

      // Buscar el usuario en la base de datos local o remota
      final userId = rawUserId is int ? rawUserId : int.tryParse(rawUserId.toString()) ?? 0;
      Map<String, dynamic>? user;

      if (_isOnline) {
        // Buscar en backend
        user = await PersonService.instance.getById(userId);
      } else {
        // Buscar en base de datos local
        final localPeople = await _unifiedService.getPeople();
        user = localPeople.firstWhere(
          (person) => (person['server_id'] ?? person['id']) == userId,
          orElse: () => <String, dynamic>{},
        );
      }

      if (user.isEmpty) {
        throw Exception('Usuario no encontrado');
      }

      if (mounted) {
        setState(() {
          _scannedUser = user;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario encontrado: ${user['fullName'] ?? user['full_name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Función para guardar la medición
  Future<void> _saveMeasurement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scannedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escanee el QR del usuario primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final waterMeasure = double.parse(_waterMeasureController.text);
      final observation = _observationController.text.isEmpty ? null : _observationController.text;
      final readingDate = DateTime.now();

      // Obtener el ID de la persona (local o server)
      final personId = _scannedUser!['id'] as int;

      await _unifiedService.createMeter(
        personId: personId,
        waterMeasure: waterMeasure,
        readingDate: readingDate,
        observation: observation,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline 
              ? 'Medición guardada exitosamente' 
              : 'Medición guardada localmente - se sincronizará cuando haya conexión'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Limpiar formulario
        setState(() {
          _scannedUser = null;
          _waterMeasureController.clear();
          _observationController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar medición: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Widget para mostrar los datos del usuario
  Widget _buildUserInfo() {
    if (_scannedUser == null) return const SizedBox.shrink();

    final user = _scannedUser!;
    final address = user['address'] ?? user['addresses'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Usuario Seleccionado',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => setState(() => _scannedUser = null),
                  tooltip: 'Escanear otro usuario',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              user['fullName'] ?? user['full_name'] ?? 'Sin nombre',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Documento: ${user['documentNumber'] ?? user['document_number'] ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (user['phone'] != null) ...[
              const SizedBox(height: 2),
              Text(
                'Teléfono: ${user['phone']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (user['email'] != null) ...[
              const SizedBox(height: 2),
              Text(
                'Email: ${user['email']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (address != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dirección:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${address['neighborhood'] ?? ''}, ${address['street'] ?? ''} ${address['houseNumber'] ?? address['house_number'] ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                address['city'] ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget para el escáner QR
  Widget _buildQRScanner() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _processScannedQR(barcode.rawValue!);
                      break;
                    }
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Escanea el QR del usuario',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Alinea el código QR dentro del marco',
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Medición'),
        actions: [
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicador de modo offline
              if (!_isOnline)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: cs.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Modo offline - Los datos se guardarán localmente y se sincronizarán cuando haya conexión',
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Información del usuario o escáner QR
              if (_scannedUser != null) ...[
                _buildUserInfo(),
              ] else ...[
                _buildQRScanner(),
              ],
              
              // Formulario de medición (solo si hay usuario seleccionado)
              if (_scannedUser != null) ...[
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medición de Agua',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _waterMeasureController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Medición de agua (m³)',
                            prefixIcon: const Icon(Icons.water_drop),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese la medición';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Por favor ingrese un número válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _observationController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Observaciones (opcional)',
                            prefixIcon: const Icon(Icons.note),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fecha: ${_formatDate(DateTime.now())}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _saveMeasurement,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar Medición'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  void dispose() {
    _waterMeasureController.dispose();
    _observationController.dispose();
    super.dispose();
  }
}