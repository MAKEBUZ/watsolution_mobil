import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  await dotenv.load(fileName: ".env");
  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

  assert(url != null && url!.isNotEmpty, 'SUPABASE_URL falta en .env');
  assert(anonKey != null && anonKey!.isNotEmpty, 'SUPABASE_ANON_KEY falta en .env');

  await Supabase.initialize(
    url: url!,
    anonKey: anonKey!,
  );
}