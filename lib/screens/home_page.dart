import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app.dart';
import '../l10n/app_localizations.dart';
import 'users_measurements_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color cardBg() => isDark ? cs.surface : cs.surface;
    Color cardFg() => isDark ? cs.onSurface : cs.onSurface;

    PopupMenuEntry<String> _menuItem({
      required String value,
      required String label,
      required bool selected,
      required IconData icon,
    }) {
      final bg = selected ? (isDark ? cs.primary.withOpacity(0.15) : cs.primary.withOpacity(0.15)) : Colors.transparent;
      final fg = selected ? cs.primary : cs.onSurface;
      return PopupMenuItem<String>(
        value: value,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: fg)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 16),
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primary.withOpacity(0.2),
              child: Icon(Icons.water_drop, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Text('WatSolution', style: TextStyle(color: cs.onBackground, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
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
            itemBuilder: (context) {
              final currentLang = appState.locale.languageCode;
              return [
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
                _menuItem(
                  value: 'lang_es',
                  label: AppLocalizations.of(context).languageSpanish,
                  icon: Icons.language,
                  selected: currentLang == 'es',
                ),
                _menuItem(
                  value: 'lang_en',
                  label: AppLocalizations.of(context).languageEnglish,
                  icon: Icons.language,
                  selected: currentLang == 'en',
                ),
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grid of two main cards
            Row(
              children: [
                Expanded(
                  child: _HomeCard(
                    title: AppLocalizations.of(context).homeScanQR,
                    icon: Icons.qr_code_scanner,
                    bg: cardBg(),
                    fg: cardFg(),
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HomeCard(
                    title: AppLocalizations.of(context).homeUsers,
                    icon: Icons.people_outline,
                    bg: cardBg(),
                    fg: cardFg(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsersMeasurementsPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).homeHistory,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            // Placeholder list items (no functionality)
            Column(
              children: List.generate(3, (index) {
                return _HistoryItem(
                  cs: cs,
                  isDark: isDark,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  const _HomeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.bg,
    required this.fg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 12,
              bottom: 12,
              child: Icon(icon, color: cs.primary.withOpacity(0.7), size: 28),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ' ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  const _HistoryItem({super.key, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 72,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.stacked_line_chart, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).measurement + ' #' + (DateTime.now().millisecondsSinceEpoch % 10000).toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fecha: —',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
        ],
      ),
    );
  }
}