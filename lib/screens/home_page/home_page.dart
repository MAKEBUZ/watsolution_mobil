import 'dart:async';
import 'package:flutter/material.dart';
import '../../app.dart';
import '../../l10n/app_localizations.dart';
import '../users_measurements_page/users_measurements_page.dart';
import '../qr_scanner_page/qr_scanner_page.dart';
import './home_page_functions.dart';
import './widgets/home_card.dart';
import './widgets/home_history_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late StreamController<List<Map<String, dynamic>>> _historyController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _historyController = StreamController<List<Map<String, dynamic>>>.broadcast();
    _startStream();
  }

  void _startStream() {
    // Emitir datos periódicamente
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _emitHistory());
    // Emitir inmediatamente
    _emitHistory();
  }

  Future<void> _emitHistory() async {
    if (_historyController.isClosed) return;
    try {
      final invoices = await HomePageFunctions.fetchRecentInvoices();
      if (!_historyController.isClosed) {
        _historyController.add(invoices);
      }
    } catch (e) {
      if (!_historyController.isClosed) {
        _historyController.addError(e);
      }
    }
  }

  Future<void> _refresh() async {
    await _emitHistory();
  }

  void _logout(BuildContext context) async {
    await HomePageFunctions.logout(context);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _historyController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color cardBg() => isDark ? cs.surface : cs.surface;
    Color cardFg() => isDark ? cs.onSurface : cs.onSurface;

    PopupMenuEntry<String> menuItem({
      required String value,
      required String label,
      required bool selected,
      required IconData icon,
    }) {
      final bg = selected ? cs.primary.withValues(alpha: 0.15) : Colors.transparent;
      final fg = selected ? cs.primary : cs.onSurface;
      return PopupMenuItem<String>(
        value: value,
        child: Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
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
              backgroundColor: cs.primary.withValues(alpha: 0.2),
              child: Icon(Icons.water_drop, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Text('WatSolution', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
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
                    children: [
                      Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).toggleTheme),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                menuItem(
                  value: 'lang_es',
                  label: '${AppLocalizations.of(context).languageSpanish} (ES)',
                  icon: Icons.language,
                  selected: currentLang == 'es',
                ),
                menuItem(
                  value: 'lang_en',
                  label: '${AppLocalizations.of(context).languageEnglish} (EN)',
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
            Row(
              children: [
                Expanded(
                  child: HomeCard(
                    title: AppLocalizations.of(context).homeScanQR,
                    icon: Icons.qr_code_scanner,
                    bg: cardBg(),
                    fg: cardFg(),
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QrScannerPage()),
                      );
                      if (result == true) await _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HomeCard(
                    title: AppLocalizations.of(context).homeUsers,
                    icon: Icons.people_outline,
                    bg: cardBg(),
                    fg: cardFg(),
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsersMeasurementsPage()),
                      );
                      if (result == true) await _refresh();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).homeHistory,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            HomeHistoryList(stream: _historyController.stream),
          ],
        ),
      ),
    );
  }
}