import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/supabase_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Hive and open app state box
  await Hive.initFlutter();
  await Hive.openBox('app');

  await initSupabase();

  // Load persisted settings from Hive
  final box = Hive.box('app');
  final themeStr = box.get('themeMode') as String?;
  final localeCode = box.get('localeCode') as String?;
  if (themeStr == 'dark') {
    appState.setThemeMode(ThemeMode.dark);
  } else if (themeStr == 'light') {
    appState.setThemeMode(ThemeMode.light);
  }
  if (localeCode != null && localeCode.isNotEmpty) {
    appState.setLocale(Locale(localeCode));
  }

  runApp(const MyApp());
}
