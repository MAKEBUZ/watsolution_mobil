import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/field_app.dart';
import 'field_app_test.dart' show PreviewSession;

class ConfirmSession extends PreviewSession {
  int logouts = 0;
  @override
  Future<void> logout() async {
    logouts++;
    await lock();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final preferences = <String, String>{};
  setUp(() {
    preferences.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map;
            if (call.method == 'read') return preferences[args['key']];
            if (call.method == 'write') {
              preferences[args['key'] as String] = args['value'] as String;
            }
            return null;
          },
        );
  });
  testWidgets('logout requires confirmation and cancel preserves session', (
    tester,
  ) async {
    final session = ConfirmSession();
    await tester.pumpWidget(FieldApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(session.locked, isFalse);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(session.logouts, 0);
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(session.logouts, 1);
    expect(session.locked, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('welcome shows volcano before login and supports returning', (
    tester,
  ) async {
    final session = PreviewSession()..locked = true;
    await tester.pumpWidget(FieldApp(session: session));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Volcán de WatSolution'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Volcán de WatSolution'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('theme survives app recreation and original volcano is present', (
    tester,
  ) async {
    await tester.pumpWidget(FieldApp(session: PreviewSession()));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Volcán de WatSolution'), findsOneWidget);
    await tester.tap(find.byTooltip('Cambiar tema'));
    await tester.pumpAndSettle();
    expect(preferences['field_theme_mode'], 'dark');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(FieldApp(session: PreviewSession()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.tap(find.byTooltip('Cambiar tema'));
    await tester.pumpAndSettle();
    expect(preferences['field_theme_mode'], 'light');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'short inactivity and background keep session, thirty minutes locks',
    (tester) async {
      final session = PreviewSession();
      await tester.pumpWidget(FieldApp(session: session));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 3));
      expect(session.locked, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(minutes: 28));
      expect(session.locked, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
