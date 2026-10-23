import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/operation_policy.dart';

void main() {
  test('ambiguous delivery and withdrawn access cannot be discarded', () {
    for (final status in [
      'pending',
      'sending',
      'retry',
      'session',
      'quarantine',
      'confirmed',
      'reviewed',
      null,
    ]) {
      expect(canReviewOperation(status), isFalse, reason: '$status');
    }
    expect(canReviewOperation('conflict'), isTrue);
    expect(canReviewOperation('correction'), isTrue);
  });
  test(
    'reviewed originals stop blocking capture but unknown states remain pending',
    () {
      expect(isPendingOperation('reviewed'), isFalse);
      expect(isPendingOperation('confirmed'), isFalse);
      expect(isPendingOperation('quarantine'), isTrue);
      expect(isPendingOperation(null), isTrue);
    },
  );
  test('a review requires a meaningful bounded explanation', () {
    expect(() => reviewReason('  '), throwsStateError);
    expect(() => reviewReason('x' * 501), throwsStateError);
    expect(
      reviewReason('  Lectura cotejada en campo  '),
      'Lectura cotejada en campo',
    );
  });
}
