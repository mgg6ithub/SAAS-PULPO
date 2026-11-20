import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/estadisticas.dart';
import 'package:pulpo/industrial/incidencias.dart';
import 'package:pulpo/industrial/simulacion_dominion.dart';
import 'package:pulpo/industrial/simulacion_historial.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estadísticas e Incidencias con seis meses simulados (sin sesión): cada apartado se dibuja sin errores,
/// en ancho de portátil y en móvil.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.activos = [];
    store.planes = [];
    store.tareas = [];
    store.subtareas = [];
    store.incidencias = [];
  });

  for (final ancho in [1400.0, 420.0]) {
    testWidgets('Estadísticas e Incidencias con historial simulado ($ancho px)', (tester) async {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        crearSimulacionDominion();
        await simularHistorial(meses: 3);
      });
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: EstadisticasPultec())));
      await tester.pumpAndSettle();
      expect(find.text('Hechas en el periodo'), findsOneWidget);
      for (final apartado in ['Verificaciones', 'Técnicos', 'Incidencias', 'Activo']) {
        // En el móvil las pestañas se abrevian o van en menú: ahí basta con que se dibuje.
        if (find.text(apartado).evaluate().isEmpty) continue;
        await tester.tap(find.text(apartado).first);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: apartado);
      }
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: IncidenciasPagina())));
      await tester.pumpAndSettle();
      if (find.textContaining('Histórico').evaluate().isNotEmpty) {
        await tester.tap(find.textContaining('Histórico').first);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
