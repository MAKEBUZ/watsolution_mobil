import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/field_app.dart';
import 'package:watsolution_mobil/field/field_session.dart';
import 'package:watsolution_mobil/field/published_work.dart';

class RestoredPreview extends FieldSession {
  int saves = 0;
  RestoredPreview() {
    onlineOnly = true;
    locked = false;
    credentials = {
      'id': '2',
      'login': 'Administrador de prueba',
      'authorities': ['ROLE_ADMIN'],
    };
    people = [
      {
        'id': 7,
        'fullName': 'Suscriptor de prueba',
        'subscriberNumber': 'DEMO-007',
      },
    ];
    status = 'Datos de demostración';
  }
  @override
  Future<void> initialize() async {}
  @override
  PublishedWork get published => PublishedWork(
    (method, path, {data}) async => Response(
      requestOptions: RequestOptions(path: path),
      data: path.contains('invoices')
          ? [
              {
                'id': 12,
                'amountDue': 1100,
                'issueDate': '2026-10-06',
                'status': 'PENDING',
                'person': {'id': 7, 'fullName': 'Suscriptor de prueba'},
              },
            ]
          : [
              {
                'id': 3,
                'waterMeasure': 20,
                'readingDate': '2026-10-05',
                'createdBy': 'operador-prueba',
                'person': {'id': 7, 'fullName': 'Suscriptor de prueba'},
              },
            ],
    ),
  );
  @override
  Future<Map<String, dynamic>> saveOnlineReading(
    int personId,
    double measure,
    String observation, {
    Map<String, double>? billing,
  }) async {
    saves++;
    return {'kind': billing == null ? 'reading' : 'invoice', 'id': 12};
  }
}

void main() {
  testWidgets(
    'restored home has direct actions and recent actual reading cards',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: FieldApp(session: RestoredPreview()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Medición sin QR'), findsOneWidget);
      expect(find.text('Consultar usuarios'), findsOneWidget);
      expect(find.text('Últimas lecturas'), findsOneWidget);
      expect(find.textContaining('Lectura #3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final directory = Platform.environment['WATSOLUTION_VISUAL_EVIDENCE'];
      if (directory != null) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$directory/inicio_restaurado_2026-10-06.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('invoice entry selects a person, records once and offers PDF', (
    tester,
  ) async {
    final session = RestoredPreview();
    await tester.pumpWidget(FieldApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facturas'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Descargar factura PDF'), findsOneWidget);
    expect(find.text('Imprimir comprobante'), findsOneWidget);
    await tester.tap(find.text('Generar factura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suscriptor de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar medición'), findsOneWidget);
    expect(find.text('MEDICIÓN ANTERIOR'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('20 m³'), findsOneWidget);
    Future<void> fill(String label, String value) async {
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.scrollUntilVisible(
        field,
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
    }

    await fill('Nueva medición acumulada (m³)', '21');
    await fill('Tarifa por m³ (COP)', '1000');
    await fill('Cargo fijo (COP)', '100');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Registrar medición y generar factura'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Registrar medición y generar factura'),
    );
    await tester.pumpAndSettle();
    expect(find.text('21 − 20 = 1 m³ consumidos'), findsOneWidget);
    expect(find.text(r'Total estimado: $1.100 COP'), findsOneWidget);
    await tester.tap(find.text('Registrar medición y generar factura'));
    await tester.pumpAndSettle();
    expect(session.saves, 1);
    expect(find.text('Descargar factura PDF'), findsOneWidget);
    expect(find.text('Imprimir comprobante de medición'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
