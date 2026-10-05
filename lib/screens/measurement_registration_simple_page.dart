import 'package:flutter/material.dart';
import '../services/measurement_service.dart';
import '../services/api/person_service.dart';
import '../services/api/address_service.dart';
import '../services/local_database/unified_database_service.dart';

class MeasurementRegistrationSimplePage extends StatefulWidget {
  final int userId;
  final double? initialWaterMeasure;
  final String? initialObservation;
  final DateTime? initialReadingDate;
  final double? initialRate;
  final double? initialFixedCharge;
  final double? initialSubsidy;

  const MeasurementRegistrationSimplePage({
    super.key,
    required this.userId,
    this.initialWaterMeasure,
    this.initialObservation,
    this.initialReadingDate,
    this.initialRate,
    this.initialFixedCharge,
    this.initialSubsidy,
  });

  @override
  State<MeasurementRegistrationSimplePage> createState() => _MeasurementRegistrationSimplePageState();
}

class _MeasurementRegistrationSimplePageState extends State<MeasurementRegistrationSimplePage> {
  final UnifiedDatabaseService _unifiedService = UnifiedDatabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  final _currentReadingCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '2500'); // Valor por defecto
  final _fixedChargeCtrl = TextEditingController(text: '5000'); // Valor por defecto
  final _subsidyCtrl = TextEditingController(text: '0');
  final _additionalChargesCtrl = TextEditingController(text: '0');
  final _observationCtrl = TextEditingController();

  bool _isOnline = true;
  bool _isLoading = false;
  bool _isUserLoading = true;
  bool _isLoadingPrev = true;
  String? _userName;
  String? _userDocument;
  String? _userAddressLabel;
  int? _userAddressId;
  double? _prevReading;
  double _consumption = 0;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    await _loadUserData();
    await _loadPreviousReading();
    if (widget.initialWaterMeasure != null) {
      _currentReadingCtrl.text = widget.initialWaterMeasure.toString();
      _calculateTotals();
    }
    if (widget.initialObservation != null && widget.initialObservation!.isNotEmpty) {
      _observationCtrl.text = widget.initialObservation!;
    }
    // Usar tarifas del QR si vienen
    if (widget.initialRate != null) {
      _rateCtrl.text = widget.initialRate.toString();
      _calculateTotals();
    }
    if (widget.initialFixedCharge != null) {
      _fixedChargeCtrl.text = widget.initialFixedCharge.toString();
      _calculateTotals();
    }
    if (widget.initialSubsidy != null) {
      _subsidyCtrl.text = widget.initialSubsidy.toString();
      _calculateTotals();
    }
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _unifiedService.syncService.isOnline();
    if (mounted) setState(() => _isOnline = isOnline);
  }

  Future<void> _loadUserData() async {
    try {
      Map<String, dynamic>? user;
      if (_isOnline) {
        user = await PersonService.instance.getById(widget.userId);
      } else {
        final localPeople = await _unifiedService.getPeople();
        user = localPeople.firstWhere(
          (p) => (p['server_id'] ?? p['id']) == widget.userId,
          orElse: () => <String, dynamic>{},
        );
      }

      int? addressId;
      String? addressLabel;
      if (user != null && user.isNotEmpty) {
        // El backend retorna address como objeto anidado {id, neighborhood...}
        final nestedAddress = user['address'] as Map<String, dynamic>?;
        addressId = nestedAddress?['id'] as int? ?? user['addressId'] ?? user['address_id'];

        if (addressId != null && _isOnline) {
          try {
            final address = await AddressService.instance.getById(addressId);
            final neighborhood = (address['neighborhood'] ?? '').toString();
            final street = (address['street'] ?? '').toString();
            final house = (address['houseNumber'] ?? address['house_number'] ?? '').toString();
            final city = (address['city'] ?? '').toString();
            final parts = [neighborhood, street, house].where((s) => s.isNotEmpty).join(' ');
            addressLabel = parts.isNotEmpty && city.isNotEmpty ? '$parts, $city' : (parts.isNotEmpty ? parts : city);
          } catch (_) {}
        } else if (nestedAddress != null) {
          // Si no pudimos consultar el backend, construir label desde el objeto anidado
          final neighborhood = (nestedAddress['neighborhood'] ?? '').toString();
          final street = (nestedAddress['street'] ?? '').toString();
          final house = (nestedAddress['houseNumber'] ?? nestedAddress['house_number'] ?? '').toString();
          final city = (nestedAddress['city'] ?? '').toString();
          final parts = [neighborhood, street, house].where((s) => s.isNotEmpty).join(' ');
          addressLabel = parts.isNotEmpty && city.isNotEmpty ? '$parts, $city' : (parts.isNotEmpty ? parts : city);
        }
      }

      if (mounted) {
        setState(() {
          _userName = user?['fullName'] ?? user?['full_name'];
          _userDocument = user?['documentNumber'] ?? user?['document_number'];
          _userAddressId = addressId;
          _userAddressLabel = addressLabel;
          _isUserLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isUserLoading = false);
    }
  }

  Future<void> _loadPreviousReading() async {
    try {
      final last = await MeasurementService.instance.getLastWaterMeasure(widget.userId);
      if (mounted) {
        setState(() {
          _prevReading = last ?? 0.0;
          _isLoadingPrev = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPrev = false);
    }
  }

  void _calculateTotals() {
    final current = double.tryParse(_currentReadingCtrl.text) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text) ?? 0.0;
    final fixed = double.tryParse(_fixedChargeCtrl.text) ?? 0.0;
    final subsidy = double.tryParse(_subsidyCtrl.text) ?? 0.0;
    final additional = double.tryParse(_additionalChargesCtrl.text) ?? 0.0;
    final prev = _prevReading ?? 0.0;

    final consumption = current - prev;
    final subtotal = consumption * rate + fixed;
    final subsidyApplied = subtotal * subsidy;
    final total = subtotal - subsidyApplied + additional;

    setState(() {
      _consumption = consumption < 0 ? 0 : consumption;
      _total = total;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final current = double.parse(_currentReadingCtrl.text);
      final rate = double.parse(_rateCtrl.text);
      final fixed = double.parse(_fixedChargeCtrl.text);
      final subsidy = double.parse(_subsidyCtrl.text);
      final additional = double.parse(_additionalChargesCtrl.text);
      final readingDate = widget.initialReadingDate ?? DateTime.now();
      final observation = _observationCtrl.text.isEmpty ? null : _observationCtrl.text;

      final result = await MeasurementService.instance.createMeasurementAndInvoice(
        personId: widget.userId,
        addressId: _userAddressId,
        currentReading: current,
        prevReading: _prevReading ?? 0.0,
        readingDate: readingDate,
        observation: observation,
        ratePerM3: rate,
        fixedCharge: fixed,
        subsidyPercent: subsidy,
        additionalCharges: additional,
      );

      if (mounted) {
        final _ = result['meter']; // ignore: unused_local_variable
        final invoice = result['invoice'] as Map<String, dynamic>;
        final consumption = result['consumption'] as double;
        final total = result['total'] as num;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Medición y Factura Guardadas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lectura registrada: $current m³'),
                Text('Consumo: ${consumption.toStringAsFixed(2)} m³'),
                const SizedBox(height: 8),
                Text('Total a pagar: \$${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                if (invoice['id'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Factura #${invoice['id']} generada', style: TextStyle(color: Colors.green[700])),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true); // Regresar y notificar éxito
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: _isUserLoading
            ? const Text('Cargando...')
            : Text('Medición - ${_userName ?? 'Usuario'}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info usuario
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.person, color: cs.primary),
                        const SizedBox(width: 8),
                        Text('Información del Usuario', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 12),
                      if (_userName != null) Text('Nombre: $_userName'),
                      if (_userDocument != null && _userDocument!.isNotEmpty) Text('Documento: $_userDocument'),
                      if (_userAddressLabel != null && _userAddressLabel!.isNotEmpty)
                        Text('Dirección: $_userAddressLabel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Offline warning
              if (!_isOnline)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: cs.error),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Modo offline. Se guardará localmente y se sincronizará al reconectar.')),
                    ],
                  ),
                ),

              // Lectura anterior
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.history, color: cs.primary),
                        const SizedBox(width: 8),
                        Text('Lectura Anterior', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 12),
                      if (_isLoadingPrev)
                        const Center(child: CircularProgressIndicator())
                      else
                        Text(
                          '${_prevReading?.toStringAsFixed(2) ?? '0.00'} m³',
                          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Formulario medición
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.water_drop, color: cs.primary),
                        const SizedBox(width: 8),
                        Text('Nueva Medición', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _currentReadingCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Lectura actual (m³)',
                          prefixIcon: Icon(Icons.water_drop),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingrese la lectura';
                          if (double.tryParse(v) == null) return 'Número inválido';
                          return null;
                        },
                        onChanged: (_) => _calculateTotals(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _observationCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observación (opcional)',
                          prefixIcon: Icon(Icons.note),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tarifas
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.receipt_long, color: cs.primary),
                        const SizedBox(width: 8),
                        Text('Datos de Facturación', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Tarifa/m³', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                              onChanged: (_) => _calculateTotals(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _fixedChargeCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Cargo fijo', prefixIcon: Icon(Icons.paid), border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                              onChanged: (_) => _calculateTotals(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _subsidyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Subsidio (0-1)', prefixIcon: Icon(Icons.percent), border: OutlineInputBorder()),
                              onChanged: (_) => _calculateTotals(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _additionalChargesCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Cargos adic.', prefixIcon: Icon(Icons.add_circle_outline), border: OutlineInputBorder()),
                              onChanged: (_) => _calculateTotals(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Resumen factura
              Card(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Resumen Factura', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Consumo:'),
                          Text('${_consumption.toStringAsFixed(2)} m³', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total a pagar:', style: textTheme.titleMedium),
                          Text('\$${_total.toStringAsFixed(0)}', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Guardando...' : 'Guardar Medición y Factura'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentReadingCtrl.dispose();
    _rateCtrl.dispose();
    _fixedChargeCtrl.dispose();
    _subsidyCtrl.dispose();
    _additionalChargesCtrl.dispose();
    _observationCtrl.dispose();
    super.dispose();
  }
}
