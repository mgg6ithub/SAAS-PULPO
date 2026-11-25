import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/industrial/estadisticas.dart';
import 'package:pultec/industrial/incidencias.dart';
import 'package:pultec/industrial/simulacion_dominion.dart';
import 'package:pultec/industrial/simulacion_historial.dart';
import 'package:pultec/store.dart';
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
      // Con los datos de prueba (botón solo de desarrollo), cada apartado también se dibuja sin errores.
      if (find.text('Datos de prueba').evaluate().isNotEmpty) {
        await tester.tap(find.text('Datos de prueba'));
        await tester.pumpAndSettle();
        for (final apartado in ['Verificaciones', 'Técnicos', 'Incidencias', 'Activo']) {
          if (find.text(apartado).evaluate().isEmpty) continue;
          await tester.tap(find.text(apartado).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'prueba: $apartado');
        }
        await tester.tap(find.text('Quitar prueba'));
        await tester.pumpAndSettle();
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
