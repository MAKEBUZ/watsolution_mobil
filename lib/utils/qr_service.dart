import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api/person_service.dart';

class QrService {
  static Future<Uint8List> generateUserQrPng(Map<String, dynamic> person) async {
    // Construir dirección igual que el backend
    final addressMap = person['address'] as Map<String, dynamic>?;
    final address = addressMap != null
        ? [
            addressMap['street'],
            addressMap['houseNumber'] ?? addressMap['house_number'],
            addressMap['neighborhood'],
            addressMap['city'],
          ].where((v) => v != null && v.toString().isNotEmpty).join(', ')
        : '';

    // Mismo formato que el backend (admin.controller.ts)
    final data = {
      'v': 1,
      'personId': person['id'],
      'name': person['fullName'] ?? person['full_name'] ?? '',
      'doc': person['documentNumber'] ?? person['document_number'] ?? '',
      'sub': person['subscriberNumber'] ?? person['subscriber_number'] ?? '',
      'stratum': person['stratum'] ?? 1,
      'address': address,
      'rate': 2500,
      'fixedCharge': 5000,
      'subsidy': 0.15,
    };
    final payload = jsonEncode(data);

    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
    );
    final bd = await painter.toImageData(1024, format: ImageByteFormat.png);
    if (bd == null) {
      throw Exception('No se pudo generar la imagen del QR');
    }
    return bd.buffer.asUint8List();
  }

  static Future<Uint8List> createUserQr({required int personId}) async {
    try {
      final person = await PersonService.instance.getById(personId);
      return await generateUserQrPng(person);
    } catch (e) {

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
