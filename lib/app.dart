import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/landing_page.dart';
import 'screens/home_page.dart';
import 'l10n/app_localizations.dart';

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  Locale locale = const Locale('es');

  void setThemeMode(ThemeMode mode) {
    if (themeMode != mode) {
      themeMode = mode;
      // Persist selection using Hive
      final box = Hive.box('app');
      box.put('themeMode', themeMode == ThemeMode.dark ? 'dark' : 'light');
      notifyListeners();
    }
  }

  void toggleTheme() {
    setThemeMode(themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  void setLocale(Locale newLocale) {
    if (locale != newLocale) {
      locale = newLocale;
      // Persist selection using Hive
      final box = Hive.box('app');
      box.put('localeCode', newLocale.languageCode);
      notifyListeners();
    }
  }
}

final appState = AppState();

ThemeData _buildLightTheme() {
  const primary = Color(0xFF2A9DF4); // Azul agua
  const secondary = Color(0xFF0077C8); // Azul medio
  const background = Color(0xFFF4F9FF); // Blanco azulado
  const surface = Color(0xFFE8F1FA); // Azul muy claro
  const onBackground = Color(0xFF0A2342); // Azul oscuro (texto principal)
  const onSurface = Color(0xFF5A6C7D); // Gris azulado (texto secundario)
  const success = Color(0xFF4FC3A1); // Verde agua
  const error = Color(0xFFE57373); // Rojo suave

  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      error: error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: onBackground,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: secondary,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    extensions: <ThemeExtension<dynamic>>[
      _SuccessColors(success),
    ],
  );
}

ThemeData _buildDarkTheme() {
  const primary = Color(0xFF2A9DF4); // Azul brillante
  const secondary = Color(0xFF5FA8D3); // Celeste claro
  const background = Color(0xFF0D1B2A); // Azul oscuro
  const surface = Color(0xFF1B263B); // Azul grisáceo
  const onBackground = Colors.white; // Blanco puro
  const onSurface = Color(0xFFB0C4DE); // Gris claro
  const success = Color(0xFF4FC3A1); // Verde agua
  const error = Color(0xFFFF6B6B); // Rojo coral

  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.black,
      surface: surface,
      onSurface: onSurface,
      error: error,
      onError: Colors.black,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: onBackground,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: secondary,
      contentTextStyle: TextStyle(color: Colors.black),
    ),
    extensions: <ThemeExtension<dynamic>>[
      _SuccessColors(success),
    ],
  );
}

class _SuccessColors extends ThemeExtension<_SuccessColors> {
  final Color success;
  const _SuccessColors(this.success);

  @override
  _SuccessColors copyWith({Color? success}) => _SuccessColors(success ?? this.success);

  @override
  _SuccessColors lerp(ThemeExtension<_SuccessColors>? other, double t) {
    if (other is! _SuccessColors) return this;
    return _SuccessColors(Color.lerp(success, other.success, t) ?? success);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppLocalizations(appState.locale).appTitle,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: appState.themeMode,
          locale: appState.locale,
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizationsDelegate(),
          ],
          home: session != null ? const HomePage() : const LandingPage(),
        );
      },
    );
  }
}