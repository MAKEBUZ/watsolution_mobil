import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPageFunctions {
  static String? extractFirstCode(BarcodeCapture capture) {
    final codes = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    if (codes.isEmpty) return null;
    return codes.first;
  }
}
