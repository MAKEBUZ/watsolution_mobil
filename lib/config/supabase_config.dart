import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Variables cacheadas para validación
String? kSupabaseUrl;
String? kSupabaseAnonKey;
bool _initialized = false;

Future<void> initSupabase() async {
  if (_initialized) return;

  await dotenv.load(fileName: ".env");
  final rawUrl = dotenv.env['SUPABASE_URL'];
  final rawAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  kSupabaseUrl = rawUrl?.trim();
  kSupabaseAnonKey = rawAnonKey?.trim();

  if (kSupabaseUrl == null || kSupabaseUrl!.isEmpty) {
    throw Exception('SUPABASE_URL falta o está vacío en .env');
  }
  if (kSupabaseAnonKey == null || kSupabaseAnonKey!.isEmpty) {
    throw Exception('SUPABASE_ANON_KEY falta o está vacío en .env');
  }

  await Supabase.initialize(
    url: kSupabaseUrl!,
    anonKey: kSupabaseAnonKey!,
  );

  _initialized = true;
}

// Valida que el "ref" dentro del anon key coincida con el subdominio del URL
bool supabaseKeyMatchesUrl() {
  try {
    if (kSupabaseUrl == null || kSupabaseAnonKey == null) return false;
    final host = Uri.parse(kSupabaseUrl!).host; // ej: wpw...tx.supabase.co
    final subdomain = host.split('.').first; // ej: wpw...tx

    final parts = kSupabaseAnonKey!.split('.');
    if (parts.length < 2) return false;
    final payloadB64 = parts[1];
    final normalized = base64Url.normalize(payloadB64);
    final payloadJson = utf8.decode(base64Url.decode(normalized));
    final Map<String, dynamic> payload = jsonDecode(payloadJson);
    final ref = payload['ref'] as String?;
    return ref != null && ref == subdomain;
  } catch (_) {
    return false;
  }
}