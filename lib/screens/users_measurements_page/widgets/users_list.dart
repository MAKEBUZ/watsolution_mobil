import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/errors.dart';
import '../../home_page/home_page_functions.dart';

class UsersList extends StatefulWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  const UsersList({required this.stream, super.key});

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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.stream,
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
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context).noMeasurements,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final u = users[index];
            final name = (u['full_name'] ?? '').toString();
            final doc = (u['document_number'] ?? '').toString();
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
                                      backgroundColor: cs.primary.withOpacity(0.15),
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
                                                  ?.copyWith(color: tileFg().withOpacity(0.7))),
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
                                      ?.copyWith(color: tileFg().withOpacity(0.9))),
                              const SizedBox(height: 4),
                              Text(
                                '${AppLocalizations.of(context).phone}: ${(u['phone'] ?? '—').toString()}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tileFg().withOpacity(0.9)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppLocalizations.of(context).email}: ${(u['email'] ?? '—').toString()}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tileFg().withOpacity(0.9)),
                              ),
                              const SizedBox(height: 4),
                              Builder(builder: (context) {
                                final addrId = u['address_id'] as int?;
                                return FutureBuilder<dynamic>(
                                  future: addrId == null
                                      ? Future.value(null)
                                      : Supabase.instance.client
                                          .from('addresses')
                                          .select('neighborhood, street, house_number, city')
                                          .eq('id', addrId)
                                          .limit(1),
                                  builder: (context, addrSnap) {
                                    String label = AppLocalizations.of(context).noAddress;
                                    final data = addrSnap.data;
                                    if (data is List && data.isNotEmpty) {
                                      final a = data.first as Map<String, dynamic>;
                                      final neighborhood = (a['neighborhood'] ?? '').toString().trim();
                                      final street = (a['street'] ?? '').toString().trim();
                                      final house = (a['house_number'] ?? '').toString().trim();
                                      final city = (a['city'] ?? '').toString().trim();
                                      final left = [neighborhood, street, house].where((p) => p.isNotEmpty).join(' ');
                                      if (left.isNotEmpty && city.isNotEmpty) {
                                        label = '$left, $city';
                                      } else {
                                        label = left.isNotEmpty ? left : (city.isNotEmpty ? city : AppLocalizations.of(context).noAddress);
                                      }
                                    }
                                    return Text('${AppLocalizations.of(context).address}: $label',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tileFg().withOpacity(0.9)));
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                      if (showMeters) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: personId == null
                                ? null
                                : Supabase.instance.client
                                    .from('meters')
                                    .stream(primaryKey: ['id'])
                                    .eq('people_id', personId)
                                    .order('reading_date'),
                            builder: (context, metersSnap) {
                              if (metersSnap.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              if (metersSnap.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: tileFg().withOpacity(0.7)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          Errors.errorLoading(context),
                                          style: Theme.of(context).textTheme.bodyMedium
                                              ?.copyWith(color: tileFg().withOpacity(0.8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final meters = metersSnap.data ?? [];
                              if (meters.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: tileFg().withOpacity(0.7)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(AppLocalizations.of(context).noMeasurements,
                                            style: Theme.of(context).textTheme.bodyMedium
                                                ?.copyWith(color: tileFg().withOpacity(0.8))),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Column(
                                children: meters.map((mm) {
                                  final readingDateStr = (mm['reading_date'] ?? '').toString();
                                  DateTime? readingDate;
                                  try {
                                    readingDate = readingDateStr.isNotEmpty ? DateTime.parse(readingDateStr) : null;
                                  } catch (_) {}
                                  final waterMeasure = mm['water_measure']?.toString() ?? '—';
                                  final obs = (mm['observation'] ?? '').toString();
                                  final meterId = mm['id'] as int?;
                                  String? invoicePath;
                                  final ip = mm['invoice_path'];
                                  if (ip is String && ip.isNotEmpty) {
                                    invoicePath = ip;
                                  } else if (meterId != null && personId != null) {
                                    final readingLabel = readingDate != null
                                        ? '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}'
                                        : '—';
                                    final fileName = 'factura_${meterId}_$readingLabel.pdf';
                                    invoicePath = 'people/$personId/$fileName';
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 40,
                                          width: 52,
                                          decoration: BoxDecoration(
                                            color: cs.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(Icons.stacked_line_chart, color: cs.primary),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${AppLocalizations.of(context).measurement} • ${readingDate != null ? '${readingDate.year}-${readingDate.month.toString().padLeft(2, '0')}-${readingDate.day.toString().padLeft(2, '0')}' : '—'}',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tileFg()),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${AppLocalizations.of(context).measurementWater}: $waterMeasure',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(color: tileFg().withOpacity(0.75)),
                                              ),
                                              const SizedBox(height: 2),
                                              if (obs.trim().isNotEmpty)
                                                Text(
                                                  'Obs: $obs',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(color: tileFg().withOpacity(0.6)),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.download_outlined),
                                          color: tileFg().withOpacity(0.75),
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
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}