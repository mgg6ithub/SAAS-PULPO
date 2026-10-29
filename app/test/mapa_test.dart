import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/agenda_vistas.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El mapa del itinerario se pinta con los clientes de ejemplo, con las chinchetas cercanas agrupadas.
void main() {
  testWidgets('el mapa se pinta y agrupa chinchetas cercanas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemoRutas();
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = hoy();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapaAgenda(desde: d, hasta: d, periodo: 'Hoy'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Mapa · Hoy'), findsOneWidget);
  });

  testWidgets('armar una ruta a mano muestra su barra y se cancela', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemoRutas();
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = hoy();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapaAgenda(desde: d, hasta: d, periodo: 'Hoy'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Armar una ruta a mano: pulsa los clientes en orden'));
    await tester.pump();
    expect(find.text('Pulsa los clientes en el orden de la ruta'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(find.text('Pulsa los clientes en el orden de la ruta'), findsNothing);
  });
}
