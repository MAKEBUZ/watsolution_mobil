import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/storage_config.dart';
import 'storage_service.dart';

class QrService {
  static Future<Uint8List> _buildUserQrPng(Map<String, dynamic> person, Map<String, dynamic>? address) async {
    final data = {
      'type': 'user',
      'id': person['id'],
      'name': person['full_name'],
      'document_number': person['document_number'],
      'phone': person['phone'],
      'email': person['email'],
      'address': address,
    };
    final payload = jsonEncode(data);
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
    );
    final bd = await painter.toImageData(1024, format: ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  static Future<String> createAndUploadUserQr({required int personId}) async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('people')
        .select('id, full_name, document_number, phone, email, address_id')
        .eq('id', personId)
        .limit(1);
    if (rows.isEmpty) {
      throw Exception('invalid_user');
    }
    final Map<String, dynamic> person = rows.first;
    Map<String, dynamic>? address;
    final addrId = person['address_id'] as int?;
    if (addrId != null) {
      final addrList = await client
          .from('addresses')
          .select('neighborhood, street, house_number, city')
          .eq('id', addrId)
          .limit(1);
      if (addrList.isNotEmpty) {
        address = addrList.first;
      }
    }
    final pngBytes = await _buildUserQrPng(person, address);
    final path = 'users/$personId/qr.png';
    await StorageService(bucketName: kUsersQrBucket).uploadBytes(path, pngBytes, contentType: 'image/png', upsert: true);
    return path;
  }
}