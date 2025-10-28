import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'landing_page.dart';
import '../app.dart';
import '../l10n/app_localizations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _logout(context);
                  break;
                case 'toggle_theme':
                  appState.toggleTheme();
                  break;
                case 'lang_es':
                  appState.setLocale(const Locale('es'));
                  break;
                case 'lang_en':
                  appState.setLocale(const Locale('en'));
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [const Icon(Icons.logout), const SizedBox(width: 8), Text(AppLocalizations.of(context).logout)],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_theme',
                child: Row(
                  children: [const Icon(Icons.brightness_6), const SizedBox(width: 8), Text(AppLocalizations.of(context).toggleTheme)],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'lang_es',
                child: Row(
                  children: [const Icon(Icons.language), const SizedBox(width: 8), Text(AppLocalizations.of(context).languageSpanish)],
                ),
              ),
              PopupMenuItem(
                value: 'lang_en',
                child: Row(
                  children: [const Icon(Icons.language), const SizedBox(width: 8), Text(AppLocalizations.of(context).languageEnglish)],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Text(AppLocalizations.of(context).homeWelcome),
      ),
    );
  }
}