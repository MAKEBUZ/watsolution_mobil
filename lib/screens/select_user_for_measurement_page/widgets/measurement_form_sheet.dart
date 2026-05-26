import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/measurement_service.dart';
import './ai_suggestion_block.dart';

class MeasurementFormSheet extends StatefulWidget {
  final Map<String, dynamic> person;
  final double? initialWaterMeasure;
  final String? initialObservation;
  final DateTime? initialReadingDate;
  final double? initialRate;
  final double? initialFixedCharge;
  final double? initialSubsidy;
  const MeasurementFormSheet({
    required this.person,
    this.initialWaterMeasure,
    this.initialObservation,
    this.initialReadingDate,
    this.initialRate,
    this.initialFixedCharge,
    this.initialSubsidy,
    super.key,
  });

  @override
  State<MeasurementFormSheet> createState() => _MeasurementFormSheetState();
}

class _MeasurementFormSheetState extends State<MeasurementFormSheet> {
  final TextEditingController _waterCtrl = TextEditingController();
  final TextEditingController _obsCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController(text: '2500');
  final TextEditingController _fixedChargeCtrl = TextEditingController(text: '5000');
  final TextEditingController _subsidyCtrl = TextEditingController(text: '0');
  final TextEditingController _additionalChargesCtrl = TextEditingController(text: '0');
  late DateTime _readingDate;
  bool _saving = false;
  bool _loadingPrev = true;
  double? _prevReading;
  double _consumption = 0;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _readingDate = widget.initialReadingDate ?? DateTime.now();
    final wm = widget.initialWaterMeasure;
    if (wm != null) _waterCtrl.text = wm.toString();
    final obs = widget.initialObservation;
    if (obs != null && obs.isNotEmpty) _obsCtrl.text = obs;
    // Usar tarifas del QR si vienen
    if (widget.initialRate != null) _rateCtrl.text = widget.initialRate.toString();
    if (widget.initialFixedCharge != null) _fixedChargeCtrl.text = widget.initialFixedCharge.toString();
    if (widget.initialSubsidy != null) _subsidyCtrl.text = widget.initialSubsidy.toString();
    _loadPreviousReading();
  }

  Future<void> _loadPreviousReading() async {
    final personId = widget.person['id'] as int?;
    if (personId == null) {
      setState(() => _loadingPrev = false);
      return;
    }
    final last = await MeasurementService.instance.getLastWaterMeasure(personId);
    setState(() {
      _prevReading = last ?? 0.0;
      _loadingPrev = false;
    });
    _calculateTotals();
  }

  void _calculateTotals() {
    final current = double.tryParse(_waterCtrl.text) ?? 0.0;
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      final loc = AppLocalizations.of(context);
      final navigator = Navigator.of(context);
      final personId = widget.person['id'] as int?;
      if (personId == null) throw Exception('Persona sin ID');

      final nestedAddress = widget.person['address'] as Map<String, dynamic>?;
      final addressId = nestedAddress?['id'] as int? ?? widget.person['addressId'] ?? widget.person['address_id'] as int?;
      final waterMeasure = double.tryParse(_waterCtrl.text.trim());
      if (waterMeasure == null) {
        messenger.showSnackBar(SnackBar(content: Text(loc.invalidMeasurement)));
        return;
      }

      final rate = double.tryParse(_rateCtrl.text) ?? 0.0;
      final fixed = double.tryParse(_fixedChargeCtrl.text) ?? 0.0;
      final subsidy = double.tryParse(_subsidyCtrl.text) ?? 0.0;
      final additional = double.tryParse(_additionalChargesCtrl.text) ?? 0.0;

      final result = await MeasurementService.instance.createMeasurementAndInvoice(
        personId: personId,
        addressId: addressId,
        currentReading: waterMeasure,
        prevReading: _prevReading ?? 0.0,
        readingDate: _readingDate,
        observation: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        ratePerM3: rate,
        fixedCharge: fixed,
        subsidyPercent: subsidy,
        additionalCharges: additional,
      );

      final consumption = result['consumption'] as double;
      final total = result['total'] as num;
      final invoice = result['invoice'] as Map<String, dynamic>;
      final invoiceId = invoice['id'];

      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Medición guardada. Factura #${invoiceId ?? 'N/A'}: \$${total.toStringAsFixed(0)} (${consumption.toStringAsFixed(2)} m³)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.person['fullName'] ?? widget.person['full_name'] ?? '').toString();
    final doc = (widget.person['documentNumber'] ?? widget.person['document_number'] ?? '').toString();
    final personId = widget.person['id'] as int?;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text([name, doc].where((s) => s.isNotEmpty).join(' • '), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('${AppLocalizations.of(context).date}: ${_readingDate.year}-${_readingDate.month.toString().padLeft(2, '0')}-${_readingDate.day.toString().padLeft(2, '0')}', style: textTheme.bodySmall),
            
            // Lectura anterior
            if (_loadingPrev)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else
              Text('Lectura anterior: ${_prevReading?.toStringAsFixed(2) ?? '0.00'} m³', style: textTheme.bodySmall?.copyWith(color: cs.primary)),
            
            const SizedBox(height: 12),
            TextField(
              controller: _waterCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: AppLocalizations.of(context).measurementWater),
              onChanged: (_) => _calculateTotals(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _obsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observación (opcional)'),
            ),
            const SizedBox(height: 12),
            
            // Tarifas
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tarifa', prefixIcon: Icon(Icons.attach_money)),
                    onChanged: (_) => _calculateTotals(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fixedChargeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cargo fijo', prefixIcon: Icon(Icons.paid)),
                    onChanged: (_) => _calculateTotals(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subsidyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Subsidio', prefixIcon: Icon(Icons.percent)),
                    onChanged: (_) => _calculateTotals(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _additionalChargesCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Adicional', prefixIcon: Icon(Icons.add_circle_outline)),
                    onChanged: (_) => _calculateTotals(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Resumen
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Consumo:'),
                    Text('${_consumption.toStringAsFixed(2)} m³', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Total:', style: textTheme.titleMedium),
                    Text('\$${_total.toStringAsFixed(0)}', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AiSuggestionBlock(personId: personId, name: name, document: doc, obsCtrl: _obsCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(AppLocalizations.of(context).save),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _waterCtrl.dispose();
    _obsCtrl.dispose();
    _rateCtrl.dispose();
    _fixedChargeCtrl.dispose();
    _subsidyCtrl.dispose();
    _additionalChargesCtrl.dispose();
    super.dispose();
  }
}
