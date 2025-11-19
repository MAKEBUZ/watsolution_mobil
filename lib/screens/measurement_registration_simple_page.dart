import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database/unified_database_service.dart';

class MeasurementRegistrationSimplePage extends StatefulWidget {
  final int userId;
  
  const MeasurementRegistrationSimplePage({
    super.key, 
    required this.userId,
  });

  @override
  State<MeasurementRegistrationSimplePage> createState() => _MeasurementRegistrationSimplePageState();
}

class _MeasurementRegistrationSimplePageState extends State<MeasurementRegistrationSimplePage> {
  final UnifiedDatabaseService _unifiedService = UnifiedDatabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  final _waterMeasureController = TextEditingController();
  final _observationController = TextEditingController();
  
  bool _isOnline = true;
  bool _isLoading = false;
  bool _isUserLoading = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadUserData();
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _unifiedService.syncService.isOnline();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Cargar datos básicos del usuario (solo el nombre para mostrar en el app bar)
      Map<String, dynamic>? user;
      
      if (_isOnline) {
        // Buscar en Supabase
        final client = Supabase.instance.client;
        final response = await client
            .from('people')
            .select('full_name')
            .eq('id', widget.userId)
            .single();
        user = response;
      } else {
        // Buscar en base de datos local
        final localPeople = await _unifiedService.getPeople();
        user = localPeople.firstWhere(
          (person) => (person['server_id'] ?? person['id']) == widget.userId,
          orElse: () => <String, dynamic>{},
        );
      }

      if (mounted) {
        setState(() {
          _userName = user?['full_name'];
          _isUserLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUserLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar usuario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Función para guardar la medición
  Future<void> _saveMeasurement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final waterMeasure = double.parse(_waterMeasureController.text);
      final observation = _observationController.text.isEmpty ? null : _observationController.text;
      final readingDate = DateTime.now();

      await _unifiedService.createMeter(
        personId: widget.userId,
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
        
        // Regresar a la pantalla anterior después de guardar
        Navigator.pop(context);
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

    return Scaffold(
      appBar: AppBar(
        title: _isUserLoading 
          ? const Text('Cargando...')
          : Text('Medición - ${_userName ?? 'Usuario'}'),
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
              
              // Instrucciones simples
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.water_drop, color: cs.primary, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Registrar Medición de Agua',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresa el valor de medición de agua actual',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
              
              const SizedBox(height: 24),
              
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