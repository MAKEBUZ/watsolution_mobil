import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../home_page/home_page.dart';

class LoginPageFunctions {
  static Future<void> signIn(BuildContext context, String email, String password) async {
    await initSupabase();
    if (!supabaseKeyMatchesUrl()) {
      throw Exception('api_key_mismatch');
    }
    final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
    if (res.session == null) {
      throw AuthException('could_not_sign_in');
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }
}