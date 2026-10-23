import 'package:flutter/material.dart';
import 'config/api_config.dart';
import 'field/field_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? configurationError;
  try {
    await ApiConfig.load();
  } catch (_) {
    configurationError =
        'Falta una dirección HTTPS válida para conectar con tu sistema. Instala una compilación configurada para WatSolution.';
  }
  runApp(FieldApp(configurationError: configurationError));
}
