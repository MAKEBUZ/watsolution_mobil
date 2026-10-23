import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/api_contract.dart';

void main() {
  test(
    'account validation rejects customer roles and malformed authorities',
    () {
      expect(
        () => FieldAccount.parse({
          'login': 'customer',
          'authorities': ['ROLE_USER'],
        }),
        throwsStateError,
      );
      expect(
        () => FieldAccount.parse({
          'login': 'operator',
          'authorities': [7],
        }),
        throwsFormatException,
      );
      final account = FieldAccount.parse({
        'id': 2,
        'login': 'operator',
        'authorities': ['ROLE_OPERATOR'],
        'password': 'must-not-retain',
      });
      expect(account.id, '2');
      expect(account.roles, ['ROLE_OPERATOR']);
    },
  );
  test('public people minimize data and reject invalid identity', () {
    final person = publicPerson({
      'id': 7,
      'fullName': 'Synthetic',
      'email': 'private@example.invalid',
      'documentNumber': 'private',
      'subscriberNumber': 'DEMO',
    });
    expect(person.keys.toSet(), {'id', 'fullName', 'subscriberNumber'});
    expect(
      () => publicPerson({'id': '7', 'fullName': 'Synthetic'}),
      throwsFormatException,
    );
  });
  test('partial or invalid baselines cannot become a prepared dataset', () {
    final row = {
      'id': 7,
      'fullName': 'Synthetic',
      'previousMeterId': 8,
      'previousReading': 20,
      'previousDate': '2026-10-01',
    };
    expect(preparedPerson(row)['previousReading'], 20);
    expect(
      () => preparedPerson({...row, 'previousReading': double.nan}),
      throwsFormatException,
    );
    expect(
      () => preparedPerson({...row, 'previousMeterId': null}),
      throwsFormatException,
    );
    expect(
      () => preparedPerson({...row, 'previousDate': 'invalid'}),
      throwsFormatException,
    );
  });
  test('ACK must match content as well as identifiers', () {
    final command = {
      'operationId': 'op',
      'personId': 7,
      'waterMeasure': 21.5,
      'readingDate': '2026-10-01',
    };
    final ack = {...command, 'meterId': 8};
    expect(readingAcknowledgement(ack, command)['meterId'], 8);
    for (final wrong in [
      {'meterId': 0},
      {'waterMeasure': 22},
      {'readingDate': '2026-09-01'},
      {'operationId': 'other'},
      {'personId': 9},
    ]) {
      expect(
        () => readingAcknowledgement({...ack, ...wrong}, command),
        throwsFormatException,
      );
    }
  });
  test('retry values cannot create negative or unbounded timers', () {
    expect(retryDelaySeconds(1, '-100'), 5);
    expect(retryDelaySeconds(1, '999999999999'), 3600);
    expect(retryDelaySeconds(10000, null), 2560);
    expect(retryDelaySeconds(0, 'invalid'), 5);
  });
  test('invalid authentication response is never saved as a session', () {
    for (final value in [
      null,
      '<html>error</html>',
      {'id_token': ''},
      {'id_token': 7},
    ]) {
      expect(() => accessToken(value), throwsFormatException);
    }
  });
}
