import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../home_page/home_page_functions.dart';
import '../../../utils/errors.dart';
import '../../../l10n/app_localizations.dart';

class HomeHistoryList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  const HomeHistoryList({required this.stream, super.key});

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                Errors.errorLoading(context),
                style: TextStyle(color: cs.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context).noMeasurements,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
            ),
          );
        }
        return Column(
          children: items.map((m) {
            final wm = m['water_measure']?.toString() ?? '—';
            final dateStr = (m['reading_date'] ?? '').toString();
            final addressId = m['address_id'] as int?;
            final meterId = m['id'] as int?;
            final peopleId = m['people_id'] as int?;
            String? invoicePath;
            final ip = m['invoice_path'];
            if (ip is String && ip.isNotEmpty) {
              invoicePath = ip;
            } else if (meterId != null && peopleId != null) {
              final fileName = 'factura_${meterId}_${_fmtDate(dateStr)}.pdf';
              invoicePath = 'people/$peopleId/$fileName';
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 72,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.stacked_line_chart, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                );
                            if (peopleId == null) {
                              return Text('—', style: titleStyle);
                            }
                            return FutureBuilder<dynamic>(
                              future: Supabase.instance.client
                                  .from('people')
                                  .select('full_name, document_number')
                                  .eq('id', peopleId)
                                  .limit(1),
                              builder: (context, personSnap) {
                                if (personSnap.connectionState == ConnectionState.waiting) {
                                  return Text('—', style: titleStyle);
                                }
                                String label = '—';
                                final data = personSnap.data;
                                if (data is List && data.isNotEmpty) {
                                  final p = data.first as Map<String, dynamic>;
                                  final name = (p['full_name'] ?? '').toString().trim();
                                  final doc = (p['document_number'] ?? '').toString().trim();
                                  label = [name, doc].where((s) => s.isNotEmpty).join(' • ');
                                  if (label.isEmpty) label = '—';
                                }
                                return Text(label, style: titleStyle);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocalizations.of(context).date}: ${_fmtDate(dateStr)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocalizations.of(context).measurementWater}: $wm',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<dynamic>(
                          future: addressId == null
                              ? Future.value(null)
                              : Supabase.instance.client
                                  .from('addresses')
                                  .select('neighborhood, street, house_number, city')
                                  .eq('id', addressId)
                                  .limit(1),
                          builder: (context, addrSnap) {
                            final style = Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withOpacity(0.7),
                                );
                            if (addrSnap.connectionState == ConnectionState.waiting) {
                              return Text('${AppLocalizations.of(context).address}: ${AppLocalizations.of(context).addressLoading}', style: style);
                            }
                            String addrLabel = AppLocalizations.of(context).noAddress;
                            final data = addrSnap.data;
                            if (data is List && data.isNotEmpty) {
                              final a = data.first as Map<String, dynamic>;
                              final neighborhood = (a['neighborhood'] ?? '').toString().trim();
                              final street = (a['street'] ?? '').toString().trim();
                              final house = (a['house_number'] ?? '').toString().trim();
                              final city = (a['city'] ?? '').toString().trim();
                              final left = [neighborhood, street, house].where((p) => p.isNotEmpty).join(' ');
                              if (left.isNotEmpty && city.isNotEmpty) {
                                addrLabel = '$left, $city';
                              } else {
                                addrLabel = left.isNotEmpty ? left : (city.isNotEmpty ? city : AppLocalizations.of(context).noAddress);
                              }
                            }
                            return Text('${AppLocalizations.of(context).address}: $addrLabel', style: style);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    color: cs.onSurface.withOpacity(0.75),
                    onPressed: invoicePath == null
                        ? null
                        : () async {
                            try {
                              final ok = await HomePageFunctions.openInvoice(invoicePath!);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(Errors.invoiceOpenFailed(context))),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(Errors.invoiceFetchFailed(context))),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}