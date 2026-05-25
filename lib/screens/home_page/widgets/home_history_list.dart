import 'package:flutter/material.dart';
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
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
            ),
          );
        }
        return Column(
          children: items.map((inv) {
            final invoiceId = inv['id'] as int?;
            final issueDate = (inv['issueDate'] ?? inv['issue_date'] ?? '').toString();
            final amountDue = (inv['amountDue'] ?? inv['amount_due'] ?? 0.0);
            final consumptionM3 = (inv['consumptionM3'] ?? inv['consumption_m_3'] ?? 0.0);
            final status = (inv['status'] ?? 'PENDING').toString();
            final pdfUrl = inv['pdfUrl'] ?? inv['pdf_url'];

            final meter = inv['meter'] as Map<String, dynamic>?;
            final person = inv['person'] as Map<String, dynamic>?;

            final wm = (meter?['waterMeasure'] ?? meter?['water_measure'])?.toString() ?? '—';

            final name = (person?['fullName'] ?? person?['full_name'] ?? '—').toString().trim();
            final doc = (person?['documentNumber'] ?? person?['document_number'] ?? '').toString().trim();
            final personLabel = [name, doc].where((s) => s.isNotEmpty && s != '—').join(' • ');

            final address = person?['address'] as Map<String, dynamic>?;
            String addrLabel = AppLocalizations.of(context).noAddress;
            if (address != null) {
              final neighborhood = (address['neighborhood'] ?? '').toString().trim();
              final street = (address['street'] ?? '').toString().trim();
              final house = (address['houseNumber'] ?? address['house_number'] ?? '').toString().trim();
              final city = (address['city'] ?? '').toString().trim();
              final left = [neighborhood, street, house].where((p) => p.isNotEmpty).join(' ');
              if (left.isNotEmpty && city.isNotEmpty) {
                addrLabel = '$left, $city';
              } else {
                addrLabel = left.isNotEmpty ? left : (city.isNotEmpty ? city : AppLocalizations.of(context).noAddress);
              }
            }

            final bool hasPdf = pdfUrl != null && pdfUrl.toString().isNotEmpty;
            final Color statusColor = status == 'PAID' ? Colors.green : (status == 'CANCELLED' ? Colors.grey : Colors.orange);

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
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          personLabel.isEmpty ? '—' : personLabel,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Factura #${invoiceId ?? '—'} • ${_fmtDate(issueDate)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Medición: $wm m³ • Consumo: ${consumptionM3.toString()} m³',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocalizations.of(context).address}: $addrLabel',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\$${amountDue is num ? amountDue.toStringAsFixed(0) : amountDue.toString()}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      hasPdf ? Icons.download_outlined : Icons.picture_as_pdf_outlined,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                    tooltip: hasPdf ? 'Descargar PDF' : 'Generar PDF local',
                    onPressed: () async {
                      final ok = await HomePageFunctions.downloadInvoice(context, inv);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(Errors.invoiceOpenFailed(context))),
                        );
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
