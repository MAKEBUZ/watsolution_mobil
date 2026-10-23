import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'field_session.dart';
import 'billing_calculation.dart';
import 'pricing_screen.dart';
import 'dart:convert';
import 'receipt_printer.dart';
import 'local_invoice_pdf.dart';

Future<void> printInvoiceReceipt(
  BuildContext context,
  FieldSession session,
  int id,
) async {
  try {
    final command = await session.invoiceReceipt(id);
    if (!context.mounted || session.locked) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReceiptPrinterScreen(
          session: session,
          command: command,
          personName: operationPersonName(command, session.people),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted && !session.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError
                ? e.message.toString()
                : 'No se pudo recuperar el comprobante. Revisa conexión y sesión.',
          ),
        ),
      );
    }
  }
}

Future<void> downloadInvoice(
  BuildContext context,
  FieldSession session,
  int id,
) async {
  try {
    final url = await session.published.invoiceDownload(id);
    if (!context.mounted || session.locked) return;
    // Separate client: never forward the API bearer token to the PDF host.
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        followRedirects: false,
        responseType: ResponseType.bytes,
      ),
    );
    late final List<int> data;
    try {
      final response = await client.get<List<int>>(url.toString());
      data = response.data ?? [];
      if (response.statusCode != 200 ||
          data.length < 5 ||
          String.fromCharCodes(data.take(5)) != '%PDF-') {
        throw StateError('El servidor no devolvió un PDF.');
      }
    } finally {
      client.close(force: true);
    }
    if (!context.mounted || session.locked) return;
    final saved = await const MethodChannel('watsolution/documents')
        .invokeMethod<bool>('savePdf', {
          'bytes': Uint8List.fromList(data),
          'name': 'Factura ($id).pdf',
        });
    if (saved == true && context.mounted && !session.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura PDF guardada en Descargas.')),
      );
    }
  } catch (_) {
    if (context.mounted && !session.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo descargar el PDF. Revisa conexión y permisos e inténtalo de nuevo.',
          ),
        ),
      );
    }
  }
}

class WorkHistory extends StatefulWidget {
  final FieldSession session;
  final bool invoices, compact;
  final int? personId;
  const WorkHistory({
    super.key,
    required this.session,
    this.invoices = false,
    this.compact = false,
    this.personId,
  });
  @override
  State<WorkHistory> createState() => _WorkHistoryState();
}

class PersonInformation extends StatefulWidget {
  final FieldSession session;
  final int personId;
  const PersonInformation({
    super.key,
    required this.session,
    required this.personId,
  });
  @override
  State<PersonInformation> createState() => _PersonInformationState();
}

class _PersonInformationState extends State<PersonInformation> {
  late final future = widget.session.published.person(widget.personId);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Consultar usuario')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'No se pudo consultar al usuario. Revisa conexión y permisos.',
            ),
          );
        }
        final person = snapshot.data!;
        const labels = {
          'fullName': 'Nombre',
          'subscriberNumber': 'Suscriptor',
          'documentNumber': 'Documento',
          'phone': 'Teléfono',
          'email': 'Correo',
          'address': 'Dirección',
        };
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in labels.entries)
              Card(
                child: ListTile(
                  title: Text(entry.value),
                  subtitle: Text(
                    person[entry.key]?.toString() ?? 'No registrado',
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _WorkHistoryState extends State<WorkHistory> {
  late Future<List<Map<String, dynamic>>> result;
  int page = 0;
  @override
  void initState() {
    super.initState();
    result = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async => widget.invoices
      ? widget.session.published.invoices(page: page, personId: widget.personId)
      : widget.session.published.readings(
          page: page,
          personId: widget.personId,
        );
  void reload([int? next]) => setState(() {
    page = next ?? page;
    result = _load();
  });
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No se pudo cargar la información. Revisa conexión y sesión.',
              ),
              TextButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        );
      }
      final rows = snapshot.data ?? [];
      final visible = widget.compact ? rows.take(5).toList() : rows;
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.compact)
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.invoices ? 'Facturas' : 'Últimas lecturas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar historial',
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.invoices
                    ? 'No hay facturas en esta página.'
                    : 'No hay lecturas en esta página.',
              ),
            ),
          for (final row in visible)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      child: Icon(
                        widget.invoices
                            ? Icons.receipt_long
                            : Icons.water_drop_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['personName']?.toString() ??
                                'Suscriptor ${row['personId'] ?? '—'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.invoices
                                ? 'Factura #${row['id']} · ${row['issueDate']}'
                                : 'Lectura #${row['id']} · ${row['readingDate']}',
                          ),
                          Text(
                            widget.invoices
                                ? '\$${row['amountDue']} COP · ${row['status']}'
                                : '${row['waterMeasure']} m³',
                          ),
                          if (!widget.invoices && row['createdBy'] != null)
                            Text(
                              'Registrada por ${row['createdBy']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (widget.invoices) ...[
                            const SizedBox(height: 16),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Comprobante de medición',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () => printInvoiceReceipt(
                                  context,
                                  widget.session,
                                  row['id'] as int,
                                ),
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('Imprimir comprobante'),
                              ),
                            ),
                            const Divider(height: 24),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text('Factura PDF'),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Tooltip(
                                message: 'Descargar factura PDF',
                                child: OutlinedButton.icon(
                                  onPressed: () => downloadInvoice(
                                    context,
                                    widget.session,
                                    row['id'] as int,
                                  ),
                                  icon: const Icon(Icons.download_outlined),
                                  label: const Text('Descargar factura PDF'),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!widget.compact && widget.personId == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: page == 0 ? null : () => reload(page - 1),
                  child: const Text('Anterior'),
                ),
                Text('Página ${page + 1}'),
                TextButton(
                  onPressed: rows.length < 20 ? null : () => reload(page + 1),
                  child: const Text('Siguiente'),
                ),
              ],
            ),
        ],
      );
      return widget.compact
          ? content
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: content,
            );
    },
  );
}

class OnlineMeasurement extends StatefulWidget {
  final FieldSession session;
  final Map<String, dynamic> person;
  const OnlineMeasurement({
    super.key,
    required this.session,
    required this.person,
  });
  @override
  State<OnlineMeasurement> createState() => _OnlineMeasurementState();
}

class _OnlineMeasurementState extends State<OnlineMeasurement> {
  final measure = TextEditingController(),
      observation = TextEditingController();
  final rate = TextEditingController(),
      fixed = TextEditingController(),
      subsidy = TextEditingController(text: '0'),
      extra = TextEditingController(text: '0');
  final bool invoice = true;
  late final baseline = widget.session.measurementReference(widget.person);
  bool saving = false;
  late final calculationChanges = Listenable.merge([
    measure,
    rate,
    fixed,
    subsidy,
    extra,
  ]);
  String? error;
  Map<String, dynamic>? confirmed;
  Map<String, dynamic>? savedReceipt;
  @override
  void initState() {
    super.initState();
    rate.text = widget.session.defaultRate?.toString() ?? '';
    fixed.text = widget.session.defaultFixedCharge?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final c in [measure, observation, rate, fixed, subsidy, extra]) {
      c.dispose();
    }
    super.dispose();
  }

  double number(TextEditingController c) {
    final value = double.tryParse(c.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0) {
      throw StateError('Completa los valores con números válidos.');
    }
    return value;
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.session.saveOnlineReading(
        widget.person['id'] as int,
        number(measure),
        observation.text,
        billing: invoice
            ? {
                'rate': number(rate),
                'fixedCharge': number(fixed),
                'subsidy': number(subsidy) / 100,
                'surcharges': number(extra),
              }
            : null,
      );
      if (mounted && !widget.session.locked) {
        if (result['kind'] == 'local') {
          for (final operation in widget.session.operations) {
            if (operation['id'] == result['id']) {
              savedReceipt = Map<String, dynamic>.from(
                jsonDecode(operation['command'] as String),
              );
              break;
            }
          }
        }
        setState(() {
          confirmed = result;
          // Direct online invoices are reconstructed from the exact server record.
          if (result['kind'] != 'local') savedReceipt = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'No se pudo completar el registro. Revisa conexión, permisos e historial.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editPricing() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PricingScreen(session: widget.session)),
    );
    if (!mounted || widget.session.locked) return;
    setState(() {
      rate.text = widget.session.defaultRate?.toString() ?? rate.text;
      fixed.text = widget.session.defaultFixedCharge?.toString() ?? fixed.text;
    });
  }

  Future<void> review() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revisar envío sin confirmar'),
        content: const Text(
          'Comprueba primero Historial y Facturas. Habilita otro envío solo si verificaste que el anterior no creó ningún registro. Si existe, vuelve sin repetirlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Comprobé que no existe'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted && !widget.session.locked) {
      await widget.session.resolveSubmission(widget.person['id'] as int);
      if (mounted) setState(() => error = null);
    }
  }

  Widget input(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: c == fixed
            ? 'Escribe 0 si no hay cargo fijo adicional.'
            : null,
      ),
      enabled: !saving,
    ),
  );
  Widget calculation() => FutureBuilder<List<Map<String, dynamic>>>(
    future: baseline,
    builder: (context, snapshot) => AnimatedBuilder(
      animation: calculationChanges,
      builder: (context, _) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'Se necesita la última medición para calcular el consumo.',
          );
        }
        final previous = snapshot.data!.first['waterMeasure'] as num;
        final current = double.tryParse(
          measure.text.trim().replaceAll(',', '.'),
        );
        if (current == null || !current.isFinite || current < 0) {
          return const Text('Ingresa la nueva lectura para ver el consumo.');
        }
        if (current < previous) {
          return Text(
            'La lectura nueva no puede ser menor que la anterior.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        BillingCalculation? bill;
        String? detail;
        if (invoice) {
          try {
            bill = BillingCalculation(
              previous: previous,
              current: current,
              rate: number(rate),
              fixedCharge: number(fixed),
              subsidy: number(subsidy) / 100,
              surcharges: number(extra),
            );
          } on StateError catch (e) {
            detail = e.message.toString();
          }
        }
        return Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Desglose del consumo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text('Anterior: ${quantity(previous)} m³'),
                Text('Nueva: ${quantity(current)} m³'),
                Text(
                  '${quantity(current)} − ${quantity(previous)} = ${quantity(current - previous)} m³ consumidos',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (bill != null) ...[
                  const Divider(),
                  Text(
                    'Consumo: ${quantity(bill.consumption)} m³ × ${cop(number(rate))}/m³ = ${cop(bill.consumptionCharge)}',
                  ),
                  Text('Cargo fijo: + ${cop(bill.fixedCharge)}'),
                  if (bill.discount > 0)
                    Text('Subsidio: − ${cop(bill.discount)}'),
                  if (bill.additionalCharges > 0)
                    Text(
                      'Cargos adicionales: + ${cop(bill.additionalCharges)}',
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Total estimado: ${cop(bill.total)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'El servidor confirmará el total al emitir la factura.',
                  ),
                ] else if (detail != null) ...[
                  const SizedBox(height: 8),
                  Text(detail),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        if (widget.session.store != null)
          IconButton(
            tooltip: 'Parámetros de facturación',
            onPressed: saving ? null : editPricing,
            icon: const Icon(Icons.price_change_outlined),
          ),
      ],
      title: Text(
        confirmed == null
            ? 'Registrar medición'
            : confirmed!['kind'] == 'local'
            ? 'Datos guardados'
            : 'Registro confirmado',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.person['fullName'].toString(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (confirmed != null) ...[
          const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
          Text(
            confirmed!['kind'] == 'local'
                ? confirmed!['billing'] == true
                      ? 'Lectura guardada. Imprime el comprobante para entregarlo ahora. La factura se generará al sincronizar y su PDF estará en Historial.'
                      : 'Lectura guardada cifrada en esta tablet. Se enviará al recuperar conexión. Consulta su estado en Envíos.'
                : confirmed!['kind'] == 'invoice'
                ? 'Lectura y factura #${confirmed!['id']} confirmadas en el servidor.'
                : 'Lectura #${confirmed!['id']} confirmada en el servidor.',
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Comprobante de medición',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (savedReceipt != null || confirmed!['kind'] == 'invoice')
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  final command = savedReceipt;
                  if (command == null) {
                    printInvoiceReceipt(
                      context,
                      widget.session,
                      confirmed!['id'] as int,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ReceiptPrinterScreen(
                          session: widget.session,
                          command: command,
                          personName: operationPersonName(
                            command,
                            widget.session.people,
                          ),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text('Imprimir comprobante de medición'),
              ),
            ),
          const Divider(height: 28),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('Factura PDF'),
          ),
          if (confirmed!['kind'] == 'invoice')
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => downloadInvoice(
                  context,
                  widget.session,
                  confirmed!['id'] as int,
                ),
                icon: const Icon(Icons.download),
                label: const Text('Descargar factura PDF'),
              ),
            ),
          if (confirmed!['kind'] == 'local')
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Disponible en Historial cuando se confirme el envío.',
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Volver al inicio'),
          ),
        ] else ...[
          FutureBuilder<List<Map<String, dynamic>>>(
            future: baseline,
            builder: (context, snapshot) => Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'MEDICIÓN ANTERIOR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (snapshot.hasError)
                      const Text(
                        'Medición anterior no disponible. Conecta internet y prepara los datos para consultarla.',
                      )
                    else if (snapshot.data == null)
                      const Text('Consultando última medición…')
                    else if (snapshot.data!.isEmpty)
                      const Text(
                        'Esta persona no tiene una medición anterior. Se necesita una referencia válida para calcular su factura.',
                      )
                    else ...[
                      Text(
                        '${quantity(snapshot.data!.first['waterMeasure'] as num)} m³',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Fecha de la medición: ${snapshot.data!.first['readingDate']}',
                      ),
                      const SizedBox(height: 8),
                      if (widget.session.offlineReady)
                        const Text(
                          'Guardada en la tablet · disponible sin internet',
                        ),
                      const Text(
                        'El consumo se calcula restando esta lectura a la nueva.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          input(measure, 'Nueva medición acumulada (m³)'),
          TextField(
            controller: observation,
            maxLength: widget.session.offlineReady ? 450 : 500,
            enabled: !saving,
            decoration: const InputDecoration(
              labelText: 'Observación local (no aparece en el PDF)',
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.receipt_long, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Esta medición incluye factura',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Se guardan los datos juntos. El servidor emite la factura al sincronizar, sin duplicar la medición.',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (widget.session.store != null)
            OutlinedButton.icon(
              onPressed: saving ? null : editPricing,
              icon: const Icon(Icons.price_change_outlined),
              label: const Text('Configurar precio por m³ y tarifa fija'),
            ),
          const SizedBox(height: 12),
          if (invoice) ...[
            input(rate, 'Tarifa por m³ (COP)'),
            input(fixed, 'Cargo fijo (COP)'),
            input(subsidy, 'Subsidio (%)'),
            input(extra, 'Cargos adicionales (COP)'),
          ],
          calculation(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              saving
                  ? 'Esperando confirmación…'
                  : invoice
                  ? widget.session.offlineReady
                        ? 'Guardar medición y factura'
                        : 'Registrar medición y generar factura'
                  : 'Guardar medición',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Con la jornada preparada, mediciones y solicitudes de factura se guardan cifradas sin internet. Se enviarán al recuperar conexión. La factura toma la fecha de emisión del servidor; la fecha de captura queda conservada en Envíos.',
          ),
          OutlinedButton(
            onPressed: saving
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Lecturas del usuario'),
                        ),
                        body: WorkHistory(
                          session: widget.session,
                          personId: widget.person['id'] as int,
                        ),
                      ),
                    ),
                  ),
            child: const Text('Ver lecturas del usuario'),
          ),
          OutlinedButton(
            onPressed: saving
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Facturas del usuario'),
                        ),
                        body: WorkHistory(
                          session: widget.session,
                          personId: widget.person['id'] as int,
                          invoices: true,
                        ),
                      ),
                    ),
                  ),
            child: const Text('Ver facturas del usuario'),
          ),
          TextButton(
            onPressed: saving ? null : review,
            child: const Text('Ya revisé un envío sin confirmar'),
          ),
        ],
      ],
    ),
  );
}
