/// Only definitive validation rejections may be closed locally. A timeout or
/// lost ACK must keep its original id until the server confirms its outcome.
bool canReviewOperation(Object? status) =>
    status == 'conflict' || status == 'correction';

bool isPendingOperation(Object? status) =>
    status != 'confirmed' && status != 'reviewed' && status != 'cancelled';

String reviewReason(String reason) {
  final value = reason.trim();
  if (value.length < 10 || value.length > 500) {
    throw StateError('Describe la revisión con entre 10 y 500 caracteres.');
  }
  return value;
}
