import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../select_user_for_measurement_page/select_user_for_measurement_page_functions.dart';
import './ai_suggestion_block.dart';

class MeasurementFormSheet extends StatefulWidget {
  final Map<String, dynamic> person;
  const MeasurementFormSheet({required this.person, super.key});

  @override
  State<MeasurementFormSheet> createState() => _MeasurementFormSheetState();
}

class _MeasurementFormSheetState extends State<MeasurementFormSheet> {
  final TextEditingController _waterCtrl = TextEditingController();
  final TextEditingController _obsCtrl = TextEditingController();
  DateTime _readingDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _waterCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final personId = widget.person['id'] as int?;
      final addressId = widget.person['address_id'] as int?;
      final waterMeasure = double.tryParse(_waterCtrl.text.trim());
      final ok = await SelectUserForMeasurementFunctions.saveMeasurementAndInvoice(
        context,
        personId: personId,
        addressId: addressId,
        waterMeasure: waterMeasure,
        readingDate: _readingDate,
        observation: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );
      if (context.mounted) {
        if (ok) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).saveFailed)));
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = (widget.person['full_name'] ?? '').toString();
    final doc = (widget.person['document_number'] ?? '').toString();
    final personId = widget.person['id'] as int?;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([name, doc].where((s) => s.isNotEmpty).join(' • '), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _waterCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: AppLocalizations.of(context).measurementWater),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obsCtrl,
            maxLines: 3,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).observationOptional),
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
    );
  }
}