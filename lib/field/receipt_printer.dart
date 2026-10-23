import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'billing_calculation.dart';
import 'field_session.dart';

List<String> receiptLines(Map command, String name) {
  final billing = command['billing'] as Map;
  final summary = BillingCalculation(
    previous: command['previousReading'] as num,
    current: command['waterMeasure'] as num,
    rate: billing['rate'] as num,
    fixedCharge: billing['fixedCharge'] as num,
    subsidy: billing['subsidy'] as num,
    surcharges: billing['surcharges'] as num,
  );
  final lines = <String>[];
  void add(String text) {
    final safe = text.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
    if (safe.isEmpty) {
      lines.add('');
      return;
    }
    // The Android renderer wraps using the actual font width in pixels.
    lines.add(safe);
  }

  for (final text in [
    'WatSolution',
    'COMPROBANTE DE MEDICIÓN',
    '------------------------',
    name,
    'Persona ID: ${command['personId']}',
    'Fecha: ${command['readingDate']}',
    'Referencia: ${command['operationId']}',
    '------------------------',
    'Anterior: ${quantity(command['previousReading'] as num)} m³',
    'Actual: ${quantity(command['waterMeasure'] as num)} m³',
    'Consumo: ${quantity(summary.consumption)} m³',
    'Precio/m³: ${cop(billing['rate'] as num)}',
    'Consumo: ${cop(summary.consumptionCharge)}',
    'Tarifa fija: ${cop(summary.fixedCharge)}',
    'Descuento: ${cop(summary.discount)}',
    'Adicionales: ${cop(summary.additionalCharges)}',
    'TOTAL ESTIMADO: ${cop(summary.total)}',
    '------------------------',
    'Gracias por cuidar el agua.',
    'Conserva este comprobante de tu lectura.',
  ]) {
    add(text);
  }
  return lines;
}

class ReceiptPrinterScreen extends StatefulWidget {
  final FieldSession session;
  final Map command;
  final String personName;
  const ReceiptPrinterScreen({
    super.key,
    required this.session,
    required this.command,
    required this.personName,
  });
  @override
  State<ReceiptPrinterScreen> createState() => _ReceiptPrinterScreenState();
}

class _ReceiptPrinterScreenState extends State<ReceiptPrinterScreen> {
  static const channel = MethodChannel('watsolution/printer');
  List<Map> devices = [];
  String? selected;
  String message =
      'Selecciona KPrinter. Si no aparece, vincúlala en Ajustes Bluetooth.';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      await widget.session.checkAccess();
      final rows = await channel.invokeListMethod<dynamic>('devices') ?? [];
      if (!mounted || widget.session.locked) return;
      setState(() {
        devices = rows.map((r) => Map.from(r as Map)).toList();
        if (!devices.any((d) => d['address'] == selected)) selected = null;
        message = devices.isEmpty
            ? 'No hay dispositivos vinculados. Abre Ajustes Bluetooth y vincula KPrinter.'
            : 'Selecciona tu impresora y prueba la impresión.';
      });
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => message = e.message ?? 'Bluetooth no disponible.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'No se pudo preparar la impresión. Revisa el acceso a tu jornada.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> printReceipt(bool test) async {
    if (busy || selected == null) return;
    setState(() => busy = true);
    try {
      await widget.session.checkAccess();
      if (!mounted || widget.session.locked) return;
      await channel.invokeMethod<void>('print', {
        'address': selected,
        'lines': test
            ? [
                'WatSolution',
                'PRUEBA DE IMPRESIÓN',
                'Papel 58 mm',
                'Ancho imprimible: 48 mm',
                'ÁÉÍÓÚ áéíóú ñ Ñ m³',
                '0123456789',
                '------------------------',
                'Sin datos de usuarios.',
              ]
            : receiptLines(widget.command, widget.personName),
      });
      if (mounted) {
        setState(
          () => message =
              'Datos enviados a la impresora. Comprueba que el recibo salió completo.',
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => message = e.message ?? 'No se pudo imprimir.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'No se pudo imprimir el comprobante.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Imprimir comprobante')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Impresora térmica Bluetooth · 58 mm',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 12),
        for (final device in devices)
          ListTile(
            leading: Icon(
              selected == device['address']
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(device['name'].toString()),
            subtitle: Text(device['address'].toString()),
            onTap: busy
                ? null
                : () => setState(() => selected = device['address'] as String),
          ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () async {
                  try {
                    await channel.invokeMethod<void>('settings');
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => message =
                            'Abre Bluetooth desde los ajustes de la tablet.',
                      );
                    }
                  }
                },
          child: const Text('Abrir Ajustes Bluetooth'),
        ),
        TextButton(
          onPressed: busy ? null : load,
          child: const Text('Actualizar impresoras'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: busy || selected == null
                ? null
                : () => printReceipt(true),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir prueba'),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: busy || selected == null
                ? null
                : () => printReceipt(false),
            icon: const Icon(Icons.print),
            label: const Text('Imprimir comprobante de medición'),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        const SizedBox(height: 20),
        const Text(
          'Vista previa',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          receiptLines(widget.command, widget.personName).join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    ),
  );
}
