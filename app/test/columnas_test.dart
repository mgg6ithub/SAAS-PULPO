import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/columnas.dart';
import 'package:pultec/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _tabla() => MaterialApp(
  home: Scaffold(
    body: Tabla(
      id: 'prueba',
      menuColumnas: true,
      columnas: const [Col('Nombre', fija: true), Col('Tag'), Col('Uso'), Col('Serie', oculta: true)],
      filas: 1,
      celdas: (_) => const [Text('Prensa'), Text('P-1'), Text('8 h'), Text('SN-9')],
    ),
  ),
);

bool _marcada(WidgetTester tester, String columna) => find
    .descendant(of: find.widgetWithText(MenuItemButton, columna), matching: find.byIcon(Icons.check_box_rounded))
    .evaluate()
    .isNotEmpty;

Future<void> _abrirMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Elegir columnas'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(columnasTablas.cerrar);

  testWidgets('el menú lista todas las columnas con marcadas las que se ven y permite quitar y añadir', (tester) async {
    await tester.pumpWidget(_tabla());
    expect(find.text('SN-9'), findsNothing);
    await _abrirMenu(tester);
    expect([for (final c in ['Nombre', 'Tag', 'Uso', 'Serie']) _marcada(tester, c)], [true, true, true, false]);
    // La que dice qué es cada fila no se puede quitar.
    expect(tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Nombre')).onPressed, isNull);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Serie'));
    await tester.pumpAndSettle();
    expect(find.text('P-1'), findsNothing);
    expect(find.text('SN-9'), findsOneWidget);
    expect([_marcada(tester, 'Tag'), _marcada(tester, 'Serie')], [false, true]);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Restaurar'));
    await tester.pumpAndSettle();
    expect(find.text('P-1'), findsOneWidget);
    expect(find.text('SN-9'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cada cuenta recupera al volver a entrar sus columnas y su orden', (tester) async {
    Map<String, dynamic>? enLaCuenta = {};
    Future<void> entrar() => columnasTablas.abrir(
      'ana',
      leer: () async => enLaCuenta,
      subir: (c) async => enLaCuenta = c,
    );
    await tester.runAsync(entrar);
    await tester.pumpWidget(_tabla());
    await _abrirMenu(tester);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Uso'));
    await tester.pumpAndSettle();
    await _abrirMenu(tester);
    // Arrastra «Tag» delante de «Nombre».
    final gesto = await tester.startGesture(tester.getCenter(find.text('Tag')));
    await gesto.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesto.moveTo(tester.getTopLeft(find.text('Nombre')));
    await tester.pump();
    await gesto.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('P-1')).dx, lessThan(tester.getTopLeft(find.text('Prensa')).dx));
    await tester.runAsync(() => columnasTablas.guardado);

    // Sale: la siguiente cuenta no hereda nada.
    await tester.pumpWidget(const SizedBox());
    columnasTablas.cerrar();
    expect(columnasTablas.ve('prueba', 'Uso'), isTrue);
    expect(columnasTablas.orden('prueba'), isEmpty);

    // Vuelve a entrar en otro equipo (navegador vacío).
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(entrar);
    await tester.pumpWidget(_tabla());
    await tester.pumpAndSettle();
    expect(find.text('8 h'), findsNothing);
    expect(tester.getTopLeft(find.text('P-1')).dx, lessThan(tester.getTopLeft(find.text('Prensa')).dx));
    expect(tester.takeException(), isNull);
  });

  test('sin conexión vale la copia del navegador y lo pendiente se sube al volver', () async {
    Future<void> sinRed(Map<String, dynamic> _) async => throw Exception('sin red');
    await columnasTablas.abrir('ana', leer: () async => throw Exception('sin red'), subir: sinRed);
    columnasTablas.poner('prueba', 'Tag', false);
    await columnasTablas.guardado;
    columnasTablas.cerrar();
    Map<String, dynamic>? subido;
    await columnasTablas.abrir(
      'ana',
      // La cuenta tiene algo anterior: manda lo que quedó sin subir.
      leer: () async => {'prueba': {'orden': <String>[], 'ver': {'Tag': true}}},
      subir: (c) async => subido = c,
    );
    await columnasTablas.guardado;
    expect(columnasTablas.ve('prueba', 'Tag'), isFalse);
    expect((subido!['prueba'] as Map)['ver'], {'Tag': false});
  });

  test('restablecer se guarda: no vuelve lo antiguo de este navegador', () async {
    Map<String, dynamic> cuenta = {};
    Future<void> entrar() =>
        columnasTablas.abrir('ana', leer: () async => cuenta, subir: (c) async => cuenta = c);
    await entrar();
    columnasTablas.poner('prueba', 'Tag', false);
    columnasTablas.restablecer('prueba');
    await columnasTablas.guardado;
    expect(cuenta, isNotEmpty);
    columnasTablas.cerrar();
    await entrar();
    expect(columnasTablas.ve('prueba', 'Tag'), isTrue);
  });
}
