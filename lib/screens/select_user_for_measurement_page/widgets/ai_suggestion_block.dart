import 'package:flutter/material.dart';
import '../../select_user_for_measurement_page/select_user_for_measurement_page_functions.dart';

class AiSuggestionBlock extends StatefulWidget {
  final int? personId;
  final String name;
  final String document;
  final TextEditingController obsCtrl;
  const AiSuggestionBlock({required this.personId, required this.name, required this.document, required this.obsCtrl, super.key});

  @override
  State<AiSuggestionBlock> createState() => _AiSuggestionBlockState();
}

class _AiSuggestionBlockState extends State<AiSuggestionBlock> {
  String? _aiText;
  bool _aiLoading = false;
  String? _aiError;

  bool _isEs(BuildContext context) => Localizations.localeOf(context).languageCode == 'es';

  Future<void> _generate() async {
    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiText = null;
    });
    try {
      final t = await SelectUserForMeasurementFunctions.generateAiSuggestion(
        context,
        personId: widget.personId,
        name: widget.name,
        document: widget.document,
      );
      setState(() {
        _aiLoading = false;
        _aiText = t;
      });
    } catch (e) {
      setState(() {
        _aiLoading = false;
        _aiError = e.toString();
      });
    }
  }

  void _copy() {
    final t = (_aiText ?? '').trim();
    if (t.isEmpty) return;
    setState(() {
      if (widget.obsCtrl.text.trim().isEmpty) {
        widget.obsCtrl.text = t;
      } else {
        widget.obsCtrl.text = '${widget.obsCtrl.text}\n$t';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEs(context) ? 'Copiado a Observación' : 'Copied to Observation')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final title = _isEs(context) ? 'Sugerencia AI' : 'AI Suggestion';
    final btn = _isEs(context) ? (_aiText == null ? 'Generar' : 'Actualizar') : (_aiText == null ? 'Generate' : 'Refresh');

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          TextButton.icon(onPressed: _aiLoading ? null : _generate, icon: _aiLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: Text(btn)),
          const SizedBox(width: 8),
          TextButton.icon(onPressed: (_aiLoading || _aiText == null) ? null : _copy, icon: const Icon(Icons.copy), label: Text(_isEs(context) ? 'Copiar' : 'Copy')),
        ]),
        const SizedBox(height: 8),
        if (_aiError != null) Text(_aiError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_aiText != null && _aiError == null) Text(_aiText!, style: Theme.of(context).textTheme.bodyMedium),
        if (_aiText == null && _aiError == null && !_aiLoading) Text(_isEs(context) ? 'Pulsa el botón para generar una recomendación basada en tu consumo mensual.' : 'Press the button to generate a recommendation based on your monthly consumption.', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}