import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../app.dart';
import './users_measurements_page_functions.dart';
import './widgets/create_user_form_sheet.dart';
import './widgets/users_list.dart';

class UsersMeasurementsPage extends StatefulWidget {
  const UsersMeasurementsPage({super.key});

  @override
  State<UsersMeasurementsPage> createState() => _UsersMeasurementsPageState();
}

class _UsersMeasurementsPageState extends State<UsersMeasurementsPage> {
  late Stream<List<Map<String, dynamic>>> _peopleStream;

  Stream<List<Map<String, dynamic>>> _streamPeople() {
    return UsersMeasurementsPageFunctions.streamPeople();
  }

  

  @override
  void initState() {
    super.initState();
    _peopleStream = _streamPeople();
  }

  Future<void> _openCreateUserForm() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const CreateUserFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeUsers),
        actions: [
          // Idioma: Español / Inglés
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (value) {
              switch (value) {
                case 'lang_es':
                  appState.setLocale(const Locale('es'));
                  break;
                case 'lang_en':
                  appState.setLocale(const Locale('en'));
                  break;
              }
            },
            itemBuilder: (context) {
              final currentLang = appState.locale.languageCode;
              Color selectedColor(String code) => currentLang == code ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;
              return [
                PopupMenuItem(
                  value: 'lang_es',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: selectedColor('es'), size: 18),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).languageSpanish),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'lang_en',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: selectedColor('en'), size: 18),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).languageEnglish),
                    ],
                  ),
                ),
              ];
            },
          ),
          // Cerrar sesión (NO IMPLEMENTAR: botón deshabilitado)
          IconButton(
            tooltip: '${AppLocalizations.of(context).logout} (no activo)',
            onPressed: null,
            icon: const Icon(Icons.logout),
          ),
          // Cambiar tema
          IconButton(
            tooltip: AppLocalizations.of(context).toggleTheme,
            onPressed: () => appState.toggleTheme(),
            icon: const Icon(Icons.brightness_6),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateUserForm,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(AppLocalizations.of(context).createUser),
      ),
      body: UsersList(stream: _peopleStream),
    );
  }
}