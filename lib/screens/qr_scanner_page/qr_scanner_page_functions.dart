import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPageFunctions {
  static String? extractFirstCode(BarcodeCapture capture) {
    final codes = capture.barcodes.map((b) => b.rawValue).where((v) => v != null && v.isNotEmpty).cast<String>().toList();
    if (codes.isEmpty) return null;
    return codes.first;
  }
}
