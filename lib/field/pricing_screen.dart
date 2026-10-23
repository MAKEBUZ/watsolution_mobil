import 'package:flutter/material.dart';
import 'field_session.dart';

class PricingScreen extends StatefulWidget {
  final FieldSession session;
  const PricingScreen({super.key, required this.session});
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late final rate = TextEditingController(
    text: widget.session.defaultRate?.toString() ?? '',
  );
  late final fixed = TextEditingController(
    text: widget.session.defaultFixedCharge?.toString() ?? '',
  );
  bool saving = false;
  String? error;
  @override
  void dispose() {
    rate.dispose();
    fixed.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final rateValue = double.tryParse(rate.text.trim().replaceAll(',', '.'));
    final fixedValue = double.tryParse(fixed.text.trim().replaceAll(',', '.'));
    if (rateValue == null ||
        fixedValue == null ||
        !rateValue.isFinite ||
        !fixedValue.isFinite ||
        rateValue < 0 ||
        fixedValue < 0) {
      setState(
        () => error = 'Ingresa valores válidos, mayores o iguales a cero.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    await widget.session.savePricing(rateValue, fixedValue);
    if (!mounted) return;
    setState(() {
      saving = false;
      error = widget.session.error;
    });
    if (error == null && !widget.session.locked) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Parámetros de facturación')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Define los valores que se completarán automáticamente en las nuevas facturas de esta cuenta en esta tablet.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: rate,
          enabled: !saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Precio por m³ (COP)'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: fixed,
          enabled: !saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Tarifa fija (COP)',
            helperText: 'Escribe 0 si no hay cargo fijo adicional.',
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Total base = (lectura nueva − anterior) × precio por m³ + tarifa fija. Los cambios no modifican facturas pendientes ni confirmadas.',
        ),
        const SizedBox(height: 20),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Guardando…' : 'Guardar parámetros'),
        ),
      ],
    ),
  );
}
