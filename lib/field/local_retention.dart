import 'dart:convert';

/// Only confirmed server-backed copies qualify. Pending, rejected, uncertain,
/// cancelled and quarantined originals are never removed by retention.
bool canPurgeConfirmedCopy(Map<String, Object?> row, DateTime now) {
  if (row['status'] != 'confirmed' || row['result'] is! String) return false;
  final created = DateTime.tryParse('${row['created_at']}');
  if (created == null ||
      !created.isBefore(now.subtract(const Duration(days: 90)))) {
    return false;
  }
  try {
    final result = jsonDecode(row['result'] as String);
    return result is Map &&
        result['invoiceId'] is int &&
        result['invoiceId'] > 0 &&
        result['meterId'] is int &&
        result['meterId'] > 0;
  } catch (_) {
    return false;
  }
}
