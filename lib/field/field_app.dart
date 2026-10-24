import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'field_session.dart';
import 'field_store.dart';
import 'dashboard_header.dart';
import 'field_theme.dart';
export 'field_theme.dart' show fieldTheme;
import 'pricing_screen.dart';
import 'routes_screen.dart';
import 'operation_policy.dart';
import 'work_screens.dart';
import 'local_invoice_pdf.dart';
import 'receipt_printer.dart';
import '../screens/home_page/widgets/home_card.dart';

class FieldApp extends StatefulWidget {
  final String? configurationError;
  final FieldSession? session;
  const FieldApp({super.key, this.configurationError, this.session});
  @override
  State<FieldApp> createState() => _FieldAppState();
}

class _FieldAppState extends State<FieldApp> with WidgetsBindingObserver {
  late final session = widget.session ?? FieldSession();
  final navigator = GlobalKey<NavigatorState>();
  Timer? inactivity;
  DateTime? inactivityDeadline;
  static const inactivityLimit = Duration(minutes: 30);
  bool themeChanged = false;
  int tab = 0;
  int workRevision = 0;
  bool historyInvoices = false;
  bool billingSelection = false;
  bool loginVisible = false;
  ThemeMode themeMode = ThemeMode.light;
  String search = '';
  Set<int> visiblePeople = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadTheme());
    touch();
    visiblePeople = session.people.map((p) => p['id'] as int).toSet();
    session.addListener(_sessionChanged);
    if (widget.configurationError == null) {
      unawaited(session.run(session.initialize));
    }
  }

  void _sessionChanged() {
    if (!session.locked) loginVisible = false;
    final current = session.people.map((p) => p['id'] as int).toSet();
    final accessWithdrawn = visiblePeople.difference(current).isNotEmpty;
    visiblePeople = current;
    if (session.locked || accessWithdrawn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) navigator.currentState?.popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void dispose() {
    inactivity?.cancel();
    session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(session.lock());
    super.dispose();
  }

  Future<void> _loadTheme() async {
    try {
      final saved = await secureSession.read(key: 'field_theme_mode');
      if (mounted && !themeChanged && saved != null) {
        setState(
          () => themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light,
        );
      }
    } catch (_) {
      // A missing preference must not prevent access to the app.
    }
  }

  Future<void> _toggleTheme() async {
    themeChanged = true;
    final selected = themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() => themeMode = selected);
    try {
      await secureSession.write(
        key: 'field_theme_mode',
        value: selected == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      final context = navigator.currentState?.overlay?.context;
      if (mounted && context != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el tema en este dispositivo.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: Text(
          session.pending > 0
              ? 'Hay ${session.pending} registros pendientes. Se conservarán cifrados para esta cuenta. Necesitarás iniciar sesión de nuevo.'
              : 'Necesitarás iniciar sesión de nuevo para acceder a tus datos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await session.logout();
  }

  void touch() {
    inactivity?.cancel();
    if (!session.locked) {
      inactivityDeadline = DateTime.now().add(inactivityLimit);
      inactivity = Timer(inactivityLimit, () => unawaited(session.lock()));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(session.retryRemoteLogout());
    }
    if (state == AppLifecycleState.resumed && !session.locked) {
      final deadline = inactivityDeadline;
      if (deadline != null && !DateTime.now().isBefore(deadline)) {
        unawaited(session.lock());
      } else {
        // Android may pause the periodic timer while the app is in background.
        unawaited(session.sync());
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    title: 'WatSolution · Campo',
    debugShowCheckedModeBanner: false,
    theme: fieldTheme(Brightness.light),
    darkTheme: fieldTheme(Brightness.dark),
    themeMode: themeMode,
    builder: (context, child) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => touch(),
      onPointerMove: (_) => touch(),
      onPointerSignal: (_) => touch(),
      child: child!,
    ),
    home: AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        if (widget.configurationError != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(widget.configurationError!),
              ),
            ),
          );
        }
        if (session.locked) {
          if (!loginVisible) {
            return _Welcome(
              onContinue: () => setState(() => loginVisible = true),
            );
          }
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) setState(() => loginVisible = false);
            },
            child: _Login(
              session: session,
              onUnlocked: touch,
              onBack: () => setState(() => loginVisible = false),
            ),
          );
        }
        return Listener(
          onPointerDown: (_) => touch(),
          child: Scaffold(
            appBar: AppBar(
              title: const Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.water_drop, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'WatSolution',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Actualizar inicio',
                  onPressed: () => setState(() => workRevision++),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Cambiar tema',
                  onPressed: _toggleTheme,
                  icon: const Icon(Icons.brightness_6_outlined),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: session.busy
                      ? null
                      : () => _confirmLogout(context),
                  icon: const Icon(Icons.lock_outline),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  children: [
                    if (session.busy) const LinearProgressIndicator(),
                    if (session.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: _Notice(
                          text: session.error!,
                          icon: Icons.info_outline,
                        ),
                      ),
                    Expanded(
                      child: switch (tab) {
                        0 => _dashboard(context),
                        1 => _people(context),
                        2 => _history(context),
                        3 => _sync(context),
                        _ => _settings(context),
                      },
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (value) => setState(() => tab = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'Personas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'Historial',
                ),
                NavigationDestination(icon: Icon(Icons.sync), label: 'Envíos'),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Cuenta',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _dashboard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget card(String title, IconData icon, VoidCallback action) => HomeCard(
      title: title,
      icon: icon,
      bg: colors.surface,
      fg: colors.onSurface,
      onTap: action,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DashboardHeader(),
        if (session.canWork && session.store != null) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: session.busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PricingScreen(session: session),
                    ),
                  ),
            icon: const Icon(Icons.price_change_outlined),
            label: const Text(
              'Parámetros de facturación · precio por m³ y tarifa fija',
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: card(
                'Escanear QR',
                Icons.qr_code_scanner,
                () => _scan(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: card(
                'Consultar usuarios',
                Icons.people_outline,
                () => setState(() => tab = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: card(
                'Medición sin QR',
                Icons.speed,
                () => setState(() => tab = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: card(
                'Facturas',
                Icons.receipt_long,
                () => setState(() {
                  tab = 2;
                  historyInvoices = true;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Últimas lecturas',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                tab = 2;
                historyInvoices = false;
              }),
              child: const Text('Ver historial'),
            ),
          ],
        ),
        WorkHistory(
          key: ValueKey('recent-$workRevision'),
          session: session,
          compact: true,
        ),
        const SizedBox(height: 16),
        Text(session.status, style: Theme.of(context).textTheme.bodySmall),
        if (!session.onlineOnly || session.offlineReady)
          FilledButton.tonalIcon(
            onPressed: session.busy ? null : () => session.run(session.prepare),
            icon: const Icon(Icons.download_for_offline),
            label: const Text('Preparar datos sin conexión'),
          ),
      ],
    );
  }

  Widget _history(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Lecturas'),
              icon: Icon(Icons.history),
            ),
            ButtonSegment(
              value: true,
              label: Text('Facturas'),
              icon: Icon(Icons.receipt_long),
            ),
          ],
          selected: {historyInvoices},
          onSelectionChanged: (value) =>
              setState(() => historyInvoices = value.first),
        ),
      ),
      if (historyInvoices && session.onlineOnly)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: () => setState(() {
              billingSelection = true;
              tab = 1;
            }),
            icon: const Icon(Icons.add),
            label: const Text('Generar factura'),
          ),
        ),
      Expanded(
        child: WorkHistory(
          key: ValueKey('history-$historyInvoices-$workRevision'),
          session: session,
          invoices: historyInvoices,
        ),
      ),
    ],
  );
  Widget _people(BuildContext context) {
    final rows = session.people
        .where(
          (p) => '${p['fullName']} ${p['subscriberNumber']}'
              .toLowerCase()
              .contains(search.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        if (billingSelection)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Selecciona el usuario para registrar su medición y generar la factura.',
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => search = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Nombre o suscriptor',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Escanear QR',
                onPressed: () => _scan(context),
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const _Empty(
                  icon: Icons.people_outline,
                  title: 'Sin personas disponibles',
                  detail:
                      'Prepara tus datos o consulta al administrador sobre tus asignaciones.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final person = rows[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Text(
                            person['fullName'].toString().isEmpty
                                ? '?'
                                : person['fullName'].toString()[0],
                          ),
                        ),
                        title: Text(
                          person['fullName'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          session.onlineOnly
                              ? 'Suscriptor ${person['subscriberNumber'] ?? '—'}'
                              : 'Suscriptor ${person['subscriberNumber'] ?? '—'} · ${person['previousReading'] ?? 'Sin lectura previa'} m³',
                        ),
                        trailing: session.canAssign
                            ? IconButton(
                                tooltip: 'Asignar operador',
                                onPressed: session.busy
                                    ? null
                                    : () => _assign(context, person),
                                icon: const Icon(Icons.assignment_ind_outlined),
                              )
                            : PopupMenuButton<String>(
                                tooltip: 'Acciones del usuario',
                                onSelected: (action) {
                                  if (action == 'bill') {
                                    _capture(context, person, invoice: true);
                                  } else if (action == 'details') {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PersonInformation(
                                          session: session,
                                          personId: person['id'] as int,
                                        ),
                                      ),
                                    );
                                  } else {
                                    _personHistory(
                                      context,
                                      person,
                                      action == 'invoices',
                                    );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'details',
                                    child: Text('Consultar datos'),
                                  ),
                                  PopupMenuItem(
                                    value: 'readings',
                                    child: Text('Ver lecturas'),
                                  ),
                                  PopupMenuItem(
                                    value: 'bill',
                                    child: Text('Medición y factura'),
                                  ),
                                  PopupMenuItem(
                                    value: 'invoices',
                                    child: Text('Ver facturas'),
                                  ),
                                ],
                              ),
                        onTap: () => _capture(context, person),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _assign(
    BuildContext context,
    Map<String, dynamic> person,
  ) async {
    final identity = session.credentials;
    try {
      final operators = await session.operators();
      if (!context.mounted ||
          session.locked ||
          session.credentials != identity) {
        return;
      }
      final chosen = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Asignar: ${person['fullName']}'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Retirar asignación'),
            ),
            for (final operator in operators)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, operator['id'] as int),
                child: Text(operator['login'].toString()),
              ),
            if (operators.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay operadores activos.'),
              ),
          ],
        ),
      );
      if (chosen != null &&
          context.mounted &&
          !session.locked &&
          session.credentials == identity) {
        await session.assign(person['id'] as int, chosen == 0 ? null : chosen);
      }
    } catch (_) {
      if (context.mounted && !session.locked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron consultar los operadores. Revisa conexión y permisos.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _scan(BuildContext context) async {
    final id = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const _Scanner()));
    if (!context.mounted || id == null) return;
    final rows = session.people.where((p) => p['id'] == id);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este QR no pertenece a tus datos preparados.'),
        ),
      );
      return;
    }
    await _capture(context, rows.first);
  }

  Future<void> _capture(
    BuildContext context,
    Map<String, dynamic> person, {
    bool invoice = false,
  }) async {
    if (session.onlineOnly) {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OnlineMeasurement(session: session, person: person),
        ),
      );
      if (mounted) {
        setState(() {
          billingSelection = false;
          if (saved == true) workRevision++;
        });
      }
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _Capture(session: session, person: person),
    );
  }

  void _personHistory(
    BuildContext context,
    Map<String, dynamic> person,
    bool invoices,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(person['fullName'].toString())),
          body: WorkHistory(
            session: session,
            invoices: invoices,
            personId: person['id'] as int,
          ),
        ),
      ),
    );
  }

  Widget _sync(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Centro de envíos',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Guardado local y confirmado en el servidor son estados diferentes.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  session.busy || (session.onlineOnly && !session.offlineReady)
                  ? null
                  : () async {
                      await session.retry();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(session.error ?? session.status),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.sync),
              label: Text(session.busy ? 'Procesando…' : 'Sincronizar ahora'),
            ),
            if (session.busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(session.error ?? session.status),
            if (session.onlineOnly && !session.offlineReady)
              const Text(
                'Para habilitar los envíos, prepara primero la jornada con conexión a internet.',
              ),
          ],
        ),
      ),
      Expanded(
        child: session.pendingOperations.isEmpty
            ? const _Empty(
                icon: Icons.cloud_done_outlined,
                title: 'No hay envíos pendientes',
                detail:
                    'Los registros confirmados están en Historial → Facturas.',
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: session.pendingOperations.length,
                itemBuilder: (context, index) {
                  final op = session.pendingOperations[index];
                  final command = jsonDecode(op['command'] as String) as Map;
                  final confirmed = op['status'] == 'confirmed';
                  final result = op['result'] is String
                      ? jsonDecode(op['result'] as String)
                      : null;
                  final invoiceId = result is Map ? result['invoiceId'] : null;
                  final personName = operationPersonName(
                    command,
                    session.people,
                  );
                  const labels = {
                    'confirmed': 'Confirmado en servidor',
                    'pending': 'Guardado en este dispositivo',
                    'sending': 'Esperando confirmación',
                    'uncertain': 'Resultado por comprobar; no se repetirá',
                    'retry': 'Reintento pendiente',
                    'conflict': 'Conflicto: revisión necesaria',
                    'session': 'Inicia sesión para enviar',
                    'quarantine': 'Acceso retirado: revisión necesaria',
                    'correction': 'Requiere corrección',
                    'reviewed': 'Revisado: original conservado',
                    'cancelled': 'Cancelado; no se enviará',
                  };
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            confirmed
                                ? Icons.verified_outlined
                                : Icons.schedule,
                          ),
                          title: Text(
                            '$personName\n${command['billing'] is Map ? 'Medición y factura' : 'Medición'} · ${command['waterMeasure']} m³',
                          ),
                          subtitle: Text(
                            '${labels[op['status']] ?? 'Pendiente'}\nCaptura: ${command['readingDate']}${op['error'] == null ? '' : '\n${op['error']}'}',
                          ),
                          isThreeLine: true,
                          trailing:
                              session.onlineOnly && op['status'] == 'pending'
                              ? IconButton(
                                  tooltip: 'Cancelar registro pendiente',
                                  onPressed: session.busy
                                      ? null
                                      : () => _cancelPending(
                                          context,
                                          op['id'] as String,
                                        ),
                                  icon: const Icon(Icons.cancel_outlined),
                                )
                              : canReviewOperation(op['status'])
                              ? IconButton(
                                  tooltip: 'Revisar rechazo',
                                  onPressed: session.busy
                                      ? null
                                      : () => _review(context, op),
                                  icon: const Icon(Icons.fact_check_outlined),
                                )
                              : op['status'] == 'quarantine'
                              ? IconButton(
                                  tooltip: 'Revalidar asignación',
                                  onPressed: session.busy
                                      ? null
                                      : () => session.resumeQuarantined(
                                          op['id'] as String,
                                        ),
                                  icon: const Icon(Icons.shield_outlined),
                                )
                              : confirmed && invoiceId is int
                              ? IconButton(
                                  tooltip: 'Descargar factura PDF',
                                  onPressed: () => downloadInvoice(
                                    context,
                                    session,
                                    invoiceId,
                                  ),
                                  icon: const Icon(Icons.download_outlined),
                                )
                              : null,
                        ),
                        if (confirmed && invoiceId is int)
                          TextButton.icon(
                            onPressed: () =>
                                downloadInvoice(context, session, invoiceId),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: Text('Descargar Factura ($invoiceId)'),
                          ),
                        if (command['billing'] is Map &&
                            ['pending', 'confirmed'].contains(op['status']))
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ReceiptPrinterScreen(
                                    session: session,
                                    command: command,
                                    personName: personName,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('Imprimir comprobante'),
                            ),
                          ),
                        if (command['billing'] is Map &&
                            ['pending', 'confirmed'].contains(op['status']))
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                await session.checkAccess();
                                if (session.locked) return;
                                final saved = await saveLocalInvoicePdf(
                                  command,
                                  personName,
                                );
                                if (context.mounted &&
                                    !session.locked &&
                                    saved) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Comprobante de medición guardado en Descargas.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted && !session.locked) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No se pudo guardar el PDF en este dispositivo.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.save_alt),
                            label: const Text(
                              'Descargar Comprobante de medición',
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );

  Future<void> _cancelPending(BuildContext context, String id) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar registro pendiente?'),
        content: const Text(
          'Se cancelará la medición y su solicitud de factura, si la tiene. No se enviarán al servidor. El registro quedará marcado como cancelado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar registro'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted && !session.locked) {
      await session.cancelPending(id);
    }
  }

  Future<void> _review(BuildContext context, Map<String, Object?> op) async {
    var reason = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revisar lectura rechazada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Se consultarán tus permisos y las lecturas actuales con internet. El original se conservará como revisado, sin enviarlo de nuevo. Después podrás registrar una nueva lectura desde Personas. Esto no modifica el servidor.',
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => reason = value,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo de revisión (mínimo 10 caracteres)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conservar como revisado'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted && !session.locked) {
      await session.reviewRejected(op['id'] as String, reason);
    }
  }

  Widget _settings(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (session.isAdmin)
        Card(
          child: ListTile(
            leading: const Icon(Icons.route),
            title: const Text('Mapa y recorridos'),
            subtitle: const Text(
              'Viviendas y rutas de lectura · Solo administradores',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoutesScreen(session: session)),
            ),
          ),
        ),
      if (session.store != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Privacidad y conservación'),
                const SizedBox(height: 8),
                const Text(
                  'Las lecturas pendientes se conservan cifradas. Puedes retirar copias locales confirmadas de más de 90 días; las facturas siguen disponibles en el historial con internet.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Los PDF que descargues quedan en Descargas y pueden abrirse desde otros visores. La impresión directa no necesita guardar un PDF.',
                ),
                TextButton.icon(
                  onPressed: session.busy ? null : session.purgeConfirmedCopies,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Limpiar copias confirmadas antiguas'),
                ),
              ],
            ),
          ),
        ),
      if (session.canWork && session.store != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('Parámetros de facturación'),
            subtitle: const Text('Precio por m³ y tarifa fija'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PricingScreen(session: session),
              ),
            ),
          ),
        ),
      Text(
        'Tu espacio de trabajo',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(session.login),
              subtitle: const Text('Operación de campo'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text('Datos protegidos en este dispositivo'),
              subtitle: Text(
                'Jornada sin conexión hasta ${session.permitExpires == null ? '—' : _date(session.permitExpires!)}. Puedes desbloquear con la seguridad del dispositivo.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const _Notice(
        icon: Icons.info_outline,
        text:
            'Las lecturas pendientes se conservan al cerrar sesión. No desinstales ni borres los datos de la app antes de confirmar sus envíos.',
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: session.busy
            ? null
            : () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: Text(
                      'Hay ${session.pending} registros pendientes. Quedarán cifrados y necesitarás iniciar sesión con internet con esta misma cuenta para recuperarlos. Sin conexión no se puede revocar la sesión del servidor inmediatamente.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Volver'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                );
                if (yes == true) await session.logout();
              },
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
      ),
    ],
  );
  String _date(DateTime date) {
    final d = date.toLocal();
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _Welcome extends StatelessWidget {
  final VoidCallback onContinue;
  const _Welcome({required this.onContinue});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/landing_bg.png',
          fit: BoxFit.cover,
          semanticLabel: 'Volcán de WatSolution',
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0x99000000)],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 56).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.water_drop, color: Colors.white, size: 32),
                          SizedBox(width: 12),
                          Text(
                            'WatSolution',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 120),
                      const Text(
                        'Agua, datos\ny tranquilidad.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tu jornada de trabajo, estés donde estés.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onContinue,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Iniciar sesión'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Login extends StatefulWidget {
  final FieldSession session;
  final VoidCallback onUnlocked;
  final VoidCallback onBack;
  const _Login({
    required this.session,
    required this.onUnlocked,
    required this.onBack,
  });
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final username = TextEditingController();
  final password = TextEditingController();
  final securityCode = TextEditingController();
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    securityCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Iniciar sesión'),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: CircleAvatar(
                    radius: 32,
                    child: Icon(Icons.water_drop_outlined, size: 36),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Agua, datos\ny tranquilidad.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 14),
                const Text('WatSolution · Operadores y administradores'),
                const SizedBox(height: 32),
                if (widget.session.hasSavedSession) ...[
                  FilledButton.icon(
                    onPressed: widget.session.busy
                        ? null
                        : () async {
                            await widget.session.unlock();
                            widget.onUnlocked();
                          },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Desbloquear mi jornada'),
                  ),
                  const SizedBox(height: 24),
                  const Text('O inicia sesión con internet'),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: username,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: securityCode,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    labelText:
                        'Código de seguridad (si activaste el segundo factor)',
                    helperText:
                        'Acepta código del autenticador o código de recuperación.',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: widget.session.busy
                      ? null
                      : () async {
                          final value = password.text;
                          password.clear();
                          final code = securityCode.text;
                          securityCode.clear();
                          await widget.session.signIn(
                            username.text,
                            value,
                            code: code,
                          );
                          widget.onUnlocked();
                        },
                  child: Text(
                    widget.session.busy
                        ? 'Preparando acceso…'
                        : 'Entrar y preparar trabajo',
                  ),
                ),
                if (widget.session.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _Notice(
                      text: widget.session.error!,
                      icon: Icons.info_outline,
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'El primer acceso requiere internet y bloqueo de pantalla en el dispositivo.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Capture extends StatefulWidget {
  final FieldSession session;
  final Map<String, dynamic> person;
  const _Capture({required this.session, required this.person});
  @override
  State<_Capture> createState() => _CaptureState();
}

class _CaptureState extends State<_Capture> {
  final reading = TextEditingController();
  final observation = TextEditingController();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    reading.dispose();
    observation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nueva lectura',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(widget.person['fullName'].toString()),
          const SizedBox(height: 20),
          _Notice(
            text: widget.person['previousReading'] == null
                ? 'Sin lectura previa: se registrará una lectura inicial, sin calcular una factura.'
                : 'Anterior: ${widget.person['previousReading']} m³ · ${widget.person['previousDate']}',
            icon: Icons.history,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: reading,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Lectura acumulada',
              suffixText: 'm³',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: observation,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observación (opcional)',
            ),
          ),
          const SizedBox(height: 12),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton.icon(
            onPressed: saving
                ? null
                : () async {
                    final value = double.tryParse(
                      reading.text.replaceAll(',', '.'),
                    );
                    if (value == null) {
                      setState(() => error = 'Ingresa un número válido');
                      return;
                    }
                    setState(() => saving = true);
                    await widget.session.capture(
                      widget.person,
                      value,
                      observation.text,
                    );
                    if (!context.mounted) return;
                    if (widget.session.error == null) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        error = widget.session.error;
                        saving = false;
                      });
                    }
                  },
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'Guardando…' : 'Guardar lectura'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quedará guardada en este dispositivo. La facturación oficial se realiza en el servidor.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Scanner extends StatefulWidget {
  const _Scanner();
  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  final controller = MobileScannerController();
  bool found = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Escanear suscriptor'),
      actions: [
        IconButton(
          tooltip: 'Linterna',
          onPressed: controller.toggleTorch,
          icon: const Icon(Icons.flashlight_on_outlined),
        ),
      ],
    ),
    body: MobileScanner(
      controller: controller,
      onDetect: (capture) {
        if (found || capture.barcodes.isEmpty) return;
        final raw = capture.barcodes.first.rawValue;
        if (raw == null || raw.length > 2048) return;
        try {
          final data = jsonDecode(raw) as Map;
          final id = int.tryParse('${data['personId'] ?? data['id']}');
          if (id == null || id < 1) return;
          found = true;
          Navigator.pop(context, id);
        } catch (_) {
          /* Untrusted QR content is ignored, never opened as a URL. */
        }
      },
    ),
  );
}

class _Notice extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Notice({required this.text, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, detail;
  const _Empty({required this.icon, required this.title, required this.detail});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
