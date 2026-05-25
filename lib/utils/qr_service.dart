import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api/person_service.dart';

class QrService {
  static Future<Uint8List> generateUserQrPng(Map<String, dynamic> person) async {
    final data = {
      'type': 'user',
      'id': person['id'],
      'name': person['fullName'] ?? person['full_name'],
      'document_number': person['documentNumber'] ?? person['document_number'],
    };
    final payload = jsonEncode(data);
    print('[QrService] Generando QR para persona ${person['id']} con payload length: ${payload.length}');

    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
    );
    final bd = await painter.toImageData(1024, format: ImageByteFormat.png);
    if (bd == null) {
      throw Exception('No se pudo generar la imagen del QR');
    }
    print('[QrService] QR generado correctamente: ${bd.lengthInBytes} bytes');
    return bd.buffer.asUint8List();
  }

  static Future<Uint8List> createUserQr({required int personId}) async {
    try {
      final person = await PersonService.instance.getById(personId);
      print('[QrService] Creando QR para: ${person['fullName']} (id=$personId)');
      return await generateUserQrPng(person);
    } catch (e, st) {
      print('[QrService] Error creando QR: $e');
      print(st);
      rethrow;
    }
  }

  static Future<void> showQrDialog(BuildContext context, Uint8List pngBytes, String title) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Image.memory(pngBytes),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
