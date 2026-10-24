import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/field_session.dart';
import 'package:watsolution_mobil/field/routes_screen.dart';

void main() {
  test(
    'route requests reject locked sessions and non-administrators before using the network',
    () async {
      final session = FieldSession();
      session.credentials = {
        'authorities': ['ROLE_ADMIN'],
      };
      await expectLater(
        session.routeRequest('POST', '/api/admin/routes/plan'),
        throwsStateError,
      );
      session.locked = false;
      for (final role in ['ROLE_USER', 'ROLE_OPERATOR']) {
        session.credentials = {
          'authorities': [role],
        };
        await expectLater(
          session.routeRequest('GET', '/api/people?page=0'),
          throwsStateError,
        );
      }
      session.credentials = {
        'authorities': ['ROLE_ADMIN'],
      };
      await expectLater(
        session.routeRequest('DELETE', '/api/people?all=true'),
        throwsStateError,
      );
      session.dispose();
    },
  );

  testWidgets('an operator cannot open the administrator map', (tester) async {
    final session = FieldSession()..locked = false;
    session.credentials = {
      'authorities': ['ROLE_OPERATOR'],
    };
    await tester.pumpWidget(MaterialApp(home: RoutesScreen(session: session)));
    expect(find.text('Acceso exclusivo para administradores.'), findsOneWidget);
    expect(find.text('Generar recorrido'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
