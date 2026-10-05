import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api/meter_service.dart';
import '../../../services/api/invoice_service.dart';

class UsersList extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final VoidCallback? onRefresh;
  const UsersList({required this.users, this.onRefresh, super.key});

  @override
  State<UsersList> createState() => _UsersListState();
}

class _UsersListState extends State<UsersList> {
  final Set<int> _detailsOpen = {};
  final Set<int> _metersOpen = {};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color tileBg() => cs.surface;
    Color tileFg() => cs.onSurface;

    if (widget.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: cs.onSurface.withValues(alpha: 0.5), size: 64),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).noMeasurements,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
            ),
            if (widget.onRefresh != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Recargar'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final u = widget.users[index];
        final name = (u['fullName'] ?? u['full_name'] ?? '').toString();
        final doc = (u['documentNumber'] ?? u['document_number'] ?? '').toString();
        final status = (u['status'] ?? '').toString();
        final personId = u['id'] as int?;

        return Container(
          decoration: BoxDecoration(
            color: tileBg(),
            borderRadius: BorderRadius.circular(14),
          ),
          child: StatefulBuilder(
            builder: (context, setItemState) {
              final int userKey = personId ?? (-index);
              final bool showDetails = _detailsOpen.contains(userKey);
              final bool showMeters = _metersOpen.contains(userKey);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() {
                              if (showDetails) {
                                _detailsOpen.remove(userKey);
                              } else {
                                _detailsOpen.add(userKey);
                              }
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: cs.primary.withValues(alpha: 0.15),
                                  foregroundColor: cs.primary,
                                  child: const Icon(Icons.person_outline),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name.isEmpty ? '—' : name,
                                          style: Theme.of(context).textTheme.bodyMedium
                                              ?.copyWith(color: tileFg(), fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text('Doc: ${doc.isEmpty ? '—' : doc} · ${status.isEmpty ? '—' : status}',
                                          style: Theme.of(context).textTheme.bodySmall
                                              ?.copyWith(color: tileFg().withValues(alpha: 0.7))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(showDetails ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () => setState(() {
                                    if (showDetails) {
                                      _detailsOpen.remove(userKey);
                                    } else {
                                      _detailsOpen.add(userKey);
                                    }
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(showMeters ? Icons.history_toggle_off : Icons.history),
                          tooltip: AppLocalizations.of(context).homeHistory,
                          onPressed: () => setState(() {
                            if (showMeters) {
                              _metersOpen.remove(userKey);
                            } else {
                              _metersOpen.add(userKey);
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                  if (showDetails) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${AppLocalizations.of(context).fullName}: ${name.isEmpty ? '—' : name}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tileFg())),
                          const SizedBox(height: 4),
                          Text('${AppLocalizations.of(context).documentNumber}: ${doc.isEmpty ? '—' : doc}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: tileFg().withValues(alpha: 0.9))),
                          const SizedBox(height: 4),
                          Text(
                            '${AppLocalizations.of(context).phone}: ${(u['phone'] ?? '—').toString()}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tileFg().withValues(alpha: 0.9)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppLocalizations.of(context).email}: ${(u['email'] ?? '—').toString()}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tileFg().withValues(alpha: 0.9)),
                          ),
                          const SizedBox(height: 4),
                          Builder(builder: (context) {
                            String label = AppLocalizations.of(context).noAddress;
                            final address = u['address'] as Map<String, dynamic>?;
                            if (address != null) {
                              final neighborhood = (address['neighborhood'] ?? '').toString().trim();
                              final street = (address['street'] ?? '').toString().trim();
                              final house = (address['houseNumber'] ?? address['house_number'] ?? '').toString().trim();
                              final city = (address['city'] ?? '').toString().trim();
                              final left = [neighborhood, street, house].where((p) => p.isNotEmpty).join(' ');
                              if (left.isNotEmpty && city.isNotEmpty) {
                                label = '$left, $city';
                              } else {
                                label = left.isNotEmpty ? left : (city.isNotEmpty ? city : AppLocalizations.of(context).noAddress);
                              }
                            }
                            return Text('${AppLocalizations.of(context).address}: $label',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tileFg().withValues(alpha: 0.9)));
                          }),
                        ],
                      ),
                    ),
                  ],
                  if (showMeters && personId != null) ...[
                    _MetersAndInvoicesSection(
                      personId: personId,
                      tileFg: tileFg,
                      cs: cs,
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Sección que carga medidores y facturas de una persona, empareja y permite descarga
class _MetersAndInvoicesSection extends StatefulWidget {
  final int personId;
  final Color Function() tileFg;
  final ColorScheme cs;

  const _MetersAndInvoicesSection({
    required this.personId,
    required this.tileFg,
    required this.cs,
  });

  @override
  State<_MetersAndInvoicesSection> createState() => _MetersAndInvoicesSectionState();
}

class _MetersAndInvoicesSectionState extends State<_MetersAndInvoicesSection> {
  bool _loading = true;
  List<Map<String, dynamic>> _meters = [];
  List<Map<String, dynamic>> _invoices = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      print('[MetersSection] Cargando medidores para personId=${widget.personId}...');
      final meters = await MeterService.instance.getByPersonId(widget.personId);
      print('[MetersSection] Medidores recibidos: ${meters.length}');
      print('[MetersSection] Primer medidor: ${meters.isNotEmpty ? meters.first : null}');

      print('[MetersSection] Cargando facturas para personId=${widget.personId}...');
      final invoices = await InvoiceService.instance.getByPersonId(widget.personId);
      print('[MetersSection] Facturas recibidas: ${invoices.length}');

      if (mounted) {
        setState(() {
          _meters = meters.cast<Map<String, dynamic>>();
          _invoices = invoices.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e, st) {
      print('[MetersSection] Error cargando datos: $e');
      print(st);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Buscar factura asociada a un medidor por meter.id == invoice.meter.id
  Map<String, dynamic>? _findInvoiceForMeter(Map<String, dynamic> meter) {
    final meterId = meter['id'];
    if (meterId == null) return null;
    try {
      return _invoices.firstWhere((inv) {
        final invMeter = inv['meter'] as Map<String, dynamic>?;
        return invMeter != null && invMeter['id'] == meterId;
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadInvoice(int invoiceId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await InvoiceService.instance.getDownloadUrl(invoiceId);
      final ok = await launchUrlString(url, webOnlyWindowName: '_blank');
      if (!ok && context.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error descargando factura: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: widget.cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error al cargar mediciones',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: widget.tileFg().withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_meters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: widget.tileFg().withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(AppLocalizations.of(context).noMeasurements,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: widget.tileFg().withValues(alpha: 0.8))),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: _meters.map((mm) {
          final readingDateStr = (mm['readingDate'] ?? mm['reading_date'] ?? '').toString();
          DateTime? readingDate;
          try {
            readingDate = readingDateStr.isNotEmpty ? DateTime.parse(readingDateStr) : null;
          } catch (_) {}
          final waterMeasure = (mm['waterMeasure'] ?? mm['water_measure'])?.toString() ?? '—';
          final obs = (mm['observation'] ?? '').toString();

          final invoice = _findInvoiceForMeter(mm);
          final invoiceId = invoice?['id'] as int?;
          final invoiceStatus = (invoice?['status'] ?? '').toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  width: 52,
                  decoration: BoxDecoration(
                    color: widget.cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.stacked_line_chart, color: widget.cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppLocalizations.of(context).measurement} • ${readingDate != null ? '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}' : '—'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: widget.tileFg()),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppLocalizations.of(context).measurementWater}: $waterMeasure',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: widget.tileFg().withValues(alpha: 0.75)),
                      ),
                      const SizedBox(height: 2),
                      if (obs.trim().isNotEmpty)
                        Text(
                          'Obs: $obs',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: widget.tileFg().withValues(alpha: 0.6)),
                        ),
                      if (invoice != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Factura: $invoiceStatus',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: widget.cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (invoiceId != null)
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    color: widget.tileFg().withValues(alpha: 0.75),
                    tooltip: 'Descargar factura',
                    onPressed: () => _downloadInvoice(invoiceId),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    color: widget.tileFg().withValues(alpha: 0.3),
                    onPressed: null,
                    tooltip: 'Sin factura',
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
