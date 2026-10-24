import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/field_app.dart';
import 'package:watsolution_mobil/field/field_session.dart';

class PreviewSession extends FieldSession {
  PreviewSession() : super(apiProfile: 'published') {
    locked = false;
    credentials = {'login': 'Operador de prueba', 'id': '2'};
    preparedAt = DateTime(2026, 10, 4);
    people = [
      {
        'id': 7,
        'fullName': 'Persona ficticia',
        'subscriberNumber': 'DEMO-7',
        'previousReading': 20,
        'previousDate': '2026-10-01',
        'previousMeterId': 8,
      },
    ];
  }
  @override
  Future<void> initialize() async {}
  void withdrawPeople() {
    people = [];
    notifyListeners();
  }

  @override
  Future<void> lock() async {
    locked = true;
    people = [];
    credentials = null;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'published profile restores manual online measurement without optional assignments',
    (tester) async {
      final session = PreviewSession()..onlineOnly = true;
      session.credentials!['authorities'] = ['ROLE_ADMIN'];
      await tester.pumpWidget(FieldApp(session: session));
      await tester.pumpAndSettle();
      expect(find.text('Consultar usuarios'), findsOneWidget);
      expect(find.text('Registrar una lectura'), findsNothing);
      await tester.tap(find.text('Personas'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Asignar operador'), findsNothing);
      await tester.tap(find.text('Persona ficticia'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva lectura'), findsNothing);
      expect(find.text('Registrar medición'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'withdrawing assignment also closes an already open personal sheet',
    (tester) async {
      final session = PreviewSession();
      await tester.pumpWidget(FieldApp(session: session));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Persona ficticia'));
      await tester.pumpAndSettle();
      session.withdrawPeople();
      await tester.pumpAndSettle();
      expect(find.text('Persona ficticia'), findsNothing);
      expect(find.text('Nueva lectura'), findsNothing);
      expect(session.locked, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'only definitive rejections offer review and locking dismisses it',
    (tester) async {
      final session = PreviewSession();
      session.operations = [
        for (final status in ['conflict', 'retry', 'quarantine'])
          {
            'id': status,
            'person_id': 7,
            'status': status,
            'command': '{"waterMeasure":21,"readingDate":"2026-10-04"}',
          },
      ];
      await tester.pumpWidget(FieldApp(session: session));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envíos'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Revisar rechazo'), findsOneWidget);
      await tester.tap(find.byTooltip('Revisar rechazo'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar lectura rechazada'), findsOneWidget);
      await session.lock();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Revisar lectura rechazada'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('locking removes personal data from an open capture sheet', (
    tester,
  ) async {
    final session = PreviewSession();
    await tester.pumpWidget(FieldApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Persona ficticia'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva lectura'), findsOneWidget);
    await session.lock();
    await tester.pumpAndSettle();
    expect(find.text('Persona ficticia'), findsNothing);
    expect(find.text('Nueva lectura'), findsNothing);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('dashboard fits a narrow display with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(FieldApp(session: PreviewSession()));
    await tester.pumpAndSettle();
    expect(find.text('Medición sin QR'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
