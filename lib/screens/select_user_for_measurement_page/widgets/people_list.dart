import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/errors.dart';
import './measurement_form_sheet.dart';

class PeopleList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  const PeopleList({required this.stream, super.key});

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
          return Center(child: Text(Errors.errorLoading(context), style: TextStyle(color: cs.error)));
        }
        final people = snapshot.data ?? [];
        if (people.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context).noMeasurements));
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: people.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = people[i];
            final name = (p['fullName'] ?? p['full_name'] ?? '').toString();
            final doc = (p['documentNumber'] ?? p['document_number'] ?? '').toString();
            final label = [name, doc].where((s) => s.isNotEmpty).join(' • ');
            return ListTile(
              title: Text(label.isEmpty ? '—' : label),
              trailing: IconButton(
                icon: const Icon(Icons.water_drop_outlined),
                onPressed: () async {
                  final cs2 = Theme.of(context).colorScheme;
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: cs2.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) => MeasurementFormSheet(person: p),
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