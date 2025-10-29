import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> _localizedStrings = {
    'es': {
      'appTitle': 'WatSolution',
      // Home
      'homeTitle': 'Inicio',
      'homeWelcome': 'Bienvenido a Home',
      'logout': 'Cerrar sesión',
      'toggleTheme': 'Cambiar tema (Claro/Oscuro)',
      'languageSpanish': 'Español',
      'languageEnglish': 'Inglés',
      'homeScanQR': 'Escanear QR',
      'homeUsers': 'Usuarios',
      'homeHistory': 'Historial de Mediciones',
      // Nueva clave para el texto "Medición"
      'measurement': 'Medición',
      // Users/Measurements page
      'noMeasurements': 'Sin mediciones registradas',
      'errorLoading': 'Error al cargar datos',
      // Login
      'loginTitle': 'Iniciar sesión',
      'loginEmail': 'Correo',
      'loginPassword': 'Contraseña',
      'loginEnter': 'Entrar',
      'loginEnterEmailPassword': 'Ingresa correo y contraseña',
      'loginApiKeyMismatch': 'La API key no corresponde al proyecto (URL). Revisa .env.',
      'loginCouldNotSignIn': 'No se pudo iniciar sesión',
      'loginUnexpectedError': 'Error inesperado al iniciar sesión',
      // Landing
      'landingHeadline1': 'Watsolution',
      'landingHeadline2': 'Cada gota cuenta.',
      'landingDescription': 'Aplicación para la toma de consumos',
      'landingSignInButton': 'Iniciar sesión',
      'landingUseYourAccount': 'Usa tu cuenta para comenzar',
    },
    'en': {
      'appTitle': 'WatSolution',
      // Home
      'homeTitle': 'Home',
      'homeWelcome': 'Welcome Home',
      'logout': 'Logout',
      'toggleTheme': 'Toggle theme (Light/Dark)',
      'languageSpanish': 'Spanish',
      'languageEnglish': 'English',
      'homeScanQR': 'Scan QR',
      'homeUsers': 'Users',
      'homeHistory': 'Measurement History',
      // New key for "Measurement"
      'measurement': 'Measurement',
      // Users/Measurements page
      'noMeasurements': 'No measurements recorded',
      'errorLoading': 'Error loading data',
      // Login
      'loginTitle': 'Sign in',
      'loginEmail': 'Email',
      'loginPassword': 'Password',
      'loginEnter': 'Sign in',
      'loginEnterEmailPassword': 'Enter email and password',
      'loginApiKeyMismatch': 'API key does not match project URL. Check .env.',
      'loginCouldNotSignIn': 'Could not sign in',
      'loginUnexpectedError': 'Unexpected error while signing in',
      // Landing
      'landingHeadline1': 'Watsolution',
      'landingHeadline2': 'Every drop counts.',
      'landingDescription': 'App for consumption readings',
      'landingSignInButton': 'Sign in',
      'landingUseYourAccount': 'Use your account to get started',
    },
  };

  String _get(String key) {
    final lang = locale.languageCode;
    return _localizedStrings[lang]?[key] ?? _localizedStrings['en']![key] ?? key;
  }

  // Getters
  String get appTitle => _get('appTitle');
  // Home
  String get homeTitle => _get('homeTitle');
  String get homeWelcome => _get('homeWelcome');
  String get logout => _get('logout');
  String get toggleTheme => _get('toggleTheme');
  String get languageSpanish => _get('languageSpanish');
  String get languageEnglish => _get('languageEnglish');
  String get homeScanQR => _get('homeScanQR');
  String get homeUsers => _get('homeUsers');
  String get homeHistory => _get('homeHistory');
  // Getter para "Medición" / "Measurement"
  String get measurement => _get('measurement');
  // Users/Measurements page
  String get noMeasurements => _get('noMeasurements');
  String get errorLoading => _get('errorLoading');
  // Login
  String get loginTitle => _get('loginTitle');
  String get loginEmail => _get('loginEmail');
  String get loginPassword => _get('loginPassword');
  String get loginEnter => _get('loginEnter');
  String get loginEnterEmailPassword => _get('loginEnterEmailPassword');
  String get loginApiKeyMismatch => _get('loginApiKeyMismatch');
  String get loginCouldNotSignIn => _get('loginCouldNotSignIn');
  String get loginUnexpectedError => _get('loginUnexpectedError');
  // Landing
  String get landingHeadline1 => _get('landingHeadline1');
  String get landingHeadline2 => _get('landingHeadline2');
  String get landingDescription => _get('landingDescription');
  String get landingSignInButton => _get('landingSignInButton');
  String get landingUseYourAccount => _get('landingUseYourAccount');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['es', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}