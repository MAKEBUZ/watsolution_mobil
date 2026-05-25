import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../select_user_for_measurement_page/select_user_for_measurement_page_functions.dart';
import './ai_suggestion_block.dart';

class MeasurementFormSheet extends StatefulWidget {
  final Map<String, dynamic> person;
  final double? initialWaterMeasure;
  final String? initialObservation;
  final DateTime? initialReadingDate;
  const MeasurementFormSheet({required this.person, this.initialWaterMeasure, this.initialObservation, this.initialReadingDate, super.key});

  @override
  State<MeasurementFormSheet> createState() => _MeasurementFormSheetState();
}

class _MeasurementFormSheetState extends State<MeasurementFormSheet> {
  final TextEditingController _waterCtrl = TextEditingController();
  final TextEditingController _obsCtrl = TextEditingController();
  late DateTime _readingDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _readingDate = widget.initialReadingDate ?? DateTime.now();
    final wm = widget.initialWaterMeasure;
    if (wm != null) {
      _waterCtrl.text = wm.toString();
    }
    final obs = widget.initialObservation;
    if (obs != null && obs.isNotEmpty) {
      _obsCtrl.text = obs;
    }
  }

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
      final messenger = ScaffoldMessenger.of(context);
      final loc = AppLocalizations.of(context);
      final navigator = Navigator.of(context);
      final addressId = widget.person['address_id'] as int?;
      final waterMeasure = double.tryParse(_waterCtrl.text.trim());
      if (waterMeasure == null) {
        messenger.showSnackBar(SnackBar(content: Text(loc.invalidMeasurement)));
        return;
      }
      final _ = await SelectUserForMeasurementFunctions.saveMeasurementAndInvoice(
        person: widget.person,
        addressId: addressId,
        waterMeasure: waterMeasure,
        readingDate: _readingDate,
        observation: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(loc.invoiceUploaded)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text('${AppLocalizations.of(context).date}: ${_readingDate.year}-${_readingDate.month.toString().padLeft(2, '0')}-${_readingDate.day.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodySmall),
          TextField(
            controller: _waterCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: AppLocalizations.of(context).measurementWater),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Observación (opcional)'),
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