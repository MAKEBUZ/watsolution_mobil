import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';
import '../config/storage_config.dart';

class UserQrService {
  static Future<Uint8List> _generatePngBytes(String data, {int size = 512}) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
      emptyColor: Colors.white,
    );
    final byteData = await painter.toImageData(size.toDouble());
    if (byteData == null) {
      throw Exception('No se pudo generar la imagen del QR');
    }
    return byteData.buffer.asUint8List();
  }

  static String buildUserPayload(int personId) {
    return 'people:$personId';
  }

  static Future<String> generateAndUpload({required int personId}) async {
    final client = Supabase.instance.client;
    final exists = await client.from('people').select('id').eq('id', personId).limit(1);
    if (exists is List && exists.isEmpty) {
      throw Exception('Usuario no encontrado');
    }

    final payload = buildUserPayload(personId);
    final pngBytes = await _generatePngBytes(payload, size: 1024);
    final path = 'people/$personId/qr.png';
    await StorageService(bucketName: kUserQrBucket).uploadBytes(
      path,
      pngBytes,
      contentType: 'image/png',
      upsert: true,
    );
    return path;
  }
}