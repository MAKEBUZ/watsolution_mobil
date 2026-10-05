import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/local_database/unified_database_service.dart';
import '../../../utils/qr_service.dart';
import '../../../utils/errors.dart';

class CreateUserFormSheet extends StatefulWidget {
  const CreateUserFormSheet({super.key});

  @override
  State<CreateUserFormSheet> createState() => _CreateUserFormSheetState();
}

class _CreateUserFormSheetState extends State<CreateUserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseNumberCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _saving = false;

  String? _emailValidator(String? v) {
    if (v == null || v.isEmpty) return null;
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final loc = AppLocalizations.of(context);
    if (!emailRegex.hasMatch(v)) return loc.invalidEmail;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_add_alt_1, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  loc.createUser,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: cs.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: loc.fullName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _docCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: loc.documentNumber,
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: loc.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: loc.email,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: _emailValidator,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: cs.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _neighborhoodCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: loc.neighborhood,
                        prefixIcon: const Icon(Icons.location_city),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _streetCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: loc.street,
                        prefixIcon: const Icon(Icons.signpost_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _houseNumberCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: loc.houseNumber,
                        prefixIcon: const Icon(Icons.tag_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: loc.city,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(loc.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _saving = true);
                          try {
                            final fullName = _nameCtrl.text.trim();
                            final documentNumber = _docCtrl.text.trim();
                            final phone = _phoneCtrl.text.trim();
                            final email = _emailCtrl.text.trim();
                            final neighborhood = _neighborhoodCtrl.text.trim();
                            final street = _streetCtrl.text.trim();
                            final houseNumber = _houseNumberCtrl.text.trim();
                            final city = _cityCtrl.text.trim();

                            final result = await UnifiedDatabaseService.instance.createPerson(
                              fullName: fullName,
                              documentNumber: documentNumber,
                              phone: phone.isEmpty ? null : phone,
                              email: email.isEmpty ? null : email,
                              neighborhood: neighborhood,
                              street: street.isEmpty ? null : street,
                              houseNumber: houseNumber.isEmpty ? null : houseNumber,
                              city: city,
                            );

                            if (result != null) {
                              final personId = result['id'] as int?;
                              if (personId != null) {
                                try {
                                  await QrService.createUserQr(personId: personId);
                                } catch (e) {
                                  print('Error generando QR tras crear usuario: $e');
                                }
                              }
                            }

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(loc.userCreated)),
                            );
                          } catch (e) {
                            setState(() => _saving = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${Errors.userCreateError(context)}: $e')),
                            );
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
  label: Text(loc.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}