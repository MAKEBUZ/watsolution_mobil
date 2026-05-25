import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../app.dart';
import '../../services/api/person_service.dart';
import './widgets/create_user_form_sheet.dart';
import './widgets/users_list.dart';

class UsersMeasurementsPage extends StatefulWidget {
  const UsersMeasurementsPage({super.key});

  @override
  State<UsersMeasurementsPage> createState() => _UsersMeasurementsPageState();
}

class _UsersMeasurementsPageState extends State<UsersMeasurementsPage> {
  late Future<List<Map<String, dynamic>>> _peopleFuture;

  Future<List<Map<String, dynamic>>> _loadPeople() async {
    print('[UsersMeasurementsPage] Cargando personas...');
    try {
      final people = await PersonService.instance.getAll(size: 1000);
      print('[UsersMeasurementsPage] Personas cargadas: ${people.length}');
      return people.cast<Map<String, dynamic>>();
    } catch (e) {
      print('[UsersMeasurementsPage] Error cargando personas: $e');
      rethrow;
    }
  }

  void _refresh() {
    setState(() {
      _peopleFuture = _loadPeople();
    });
  }

  @override
  void initState() {
    super.initState();
    _peopleFuture = _loadPeople();
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
    // Recargar lista después de crear usuario
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeUsers),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _refresh,
          ),
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
                      Text('${AppLocalizations.of(context).languageSpanish} (ES)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'lang_en',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: selectedColor('en'), size: 18),
                      const SizedBox(width: 8),
                      Text('${AppLocalizations.of(context).languageEnglish} (EN)'),
                    ],
                  ),
                ),
              ];
            },
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).toggleTheme,
            onPressed: () => appState.toggleTheme(),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateUserForm,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(AppLocalizations.of(context).createUser),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _peopleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error al cargar usuarios:\n${snapshot.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final users = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _peopleFuture;
            },
            child: UsersList(
              users: users,
              onRefresh: _refresh,
            ),
          );
        },
      ),
    );
  }
}
