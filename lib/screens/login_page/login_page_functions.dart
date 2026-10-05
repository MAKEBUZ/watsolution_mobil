import 'package:flutter/material.dart';
import '../../services/api/auth_service.dart';
import '../home_page/home_page.dart';

class LoginPageFunctions {
  static Future<void> signIn(BuildContext context, String username, String password) async {
    await AuthService.instance.login(username: username, password: password);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }
}
