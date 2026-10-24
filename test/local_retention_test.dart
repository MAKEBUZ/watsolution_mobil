import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/local_retention.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23);
  Map<String, Object?> row(String state) => {
    'status': state,
    'created_at': '2026-01-01',
    'result': jsonEncode({'invoiceId': 7, 'meterId': 8}),
  };
  test(
    'never purges pending, uncertain, rejected or quarantined originals even when old',
    () {
      for (final state in [
        'pending',
        'sending',
        'retry',
        'uncertain',
        'conflict',
        'correction',
        'session',
        'quarantine',
        'cancelled',
        'reviewed',
      ]) {
        expect(canPurgeConfirmedCopy(row(state), now), false, reason: state);
      }
    },
  );
  test(
    'requires old confirmed copy with valid server identifiers and date',
    () {
      expect(canPurgeConfirmedCopy(row('confirmed'), now), true);
      expect(
        canPurgeConfirmedCopy({
          ...row('confirmed'),
          'created_at': '2026-10-22',
        }, now),
        false,
      );
      expect(
        canPurgeConfirmedCopy({...row('confirmed'), 'created_at': 'bad'}, now),
        false,
      );
      expect(
        canPurgeConfirmedCopy({...row('confirmed'), 'result': '{}'}, now),
        false,
      );
      expect(
        canPurgeConfirmedCopy({...row('confirmed'), 'result': '{'}, now),
        false,
      );
    },
  );
}
