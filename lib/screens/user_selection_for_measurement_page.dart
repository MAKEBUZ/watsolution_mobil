import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/local_database/unified_database_service.dart';
import 'measurement_registration_page.dart';

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
        // Ir directamente a la página de registro con el usuario escaneado
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeasurementRegistrationPageWithUser(userData: result),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeasurementRegistrationPageWithUser(userData: selectedUser),
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

// Página de registro con usuario pre-seleccionado
class MeasurementRegistrationPageWithUser extends StatelessWidget {
  final Map<String, dynamic> userData;
  
  const MeasurementRegistrationPageWithUser({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Medición'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MeasurementRegistrationContent(userData: userData),
    );
  }
}

class MeasurementRegistrationContent extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const MeasurementRegistrationContent({super.key, required this.userData});

  @override
  State<MeasurementRegistrationContent> createState() => _MeasurementRegistrationContentState();
}

class _MeasurementRegistrationContentState extends State<MeasurementRegistrationContent> {
  final UnifiedDatabaseService _unifiedService = UnifiedDatabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  final _waterMeasureController = TextEditingController();
  final _observationController = TextEditingController();
  
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

  Future<void> _saveMeasurement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final waterMeasure = double.parse(_waterMeasureController.text);
      final observation = _observationController.text.isEmpty ? null : _observationController.text;
      final readingDate = DateTime.now();

      // Obtener el ID de la persona
      final personId = widget.userData['id'] as int;

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
        _waterMeasureController.clear();
        _observationController.clear();
        
        // Regresar a la pantalla anterior después de un breve delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = widget.userData;
    final address = user['addresses'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
          
          // Información del usuario
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Usuario Seleccionado',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user['full_name'] ?? 'Sin nombre',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Documento: ${user['document_number'] ?? 'N/A'}',
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
                      '${address['neighborhood'] ?? ''}, ${address['street'] ?? ''} ${address['house_number'] ?? ''}',
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
          ),
          
          const SizedBox(height: 16),
          
          // Formulario de medición
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medición de Agua',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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