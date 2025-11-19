import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../landing_page/landing_page.dart';
import '../../utils/storage_service.dart';

class HomePageFunctions {
  static Future<void> logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LandingPage()),
        (route) => false,
      );
    }
  }

  static Stream<List<Map<String, dynamic>>> streamRecentMeters() {
    return Supabase.instance.client
        .from('meters')
        .stream(primaryKey: ['id'])
        .order('reading_date', ascending: false)
        .limit(20);
  }

  static Future<bool> openInvoice(String invoicePath) async {
    final url = await StorageService().createSignedUrl(invoicePath, const Duration(minutes: 15));
    final ok = await launchUrlString(url, webOnlyWindowName: '_blank');
    return ok;
  }
}