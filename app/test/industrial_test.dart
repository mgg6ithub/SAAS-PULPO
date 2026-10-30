import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/activos.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iPultec (IPT-005/006): el color de un activo es el de la OT pendiente más grave de su árbol.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.activos = [];
    store.tareas.removeWhere((t) => t.id.startsWith('ot'));
    store
      ..guardarActivo(Activo(id: 'a1', tag: 'CAM-01', nombre: 'Camión'))
      ..guardarActivo(Activo(id: 'a2', padreId: 'a1', tag: 'CAM-01-MOT', nombre: 'Motor'))
      ..guardarActivo(Activo(id: 'a3', padreId: 'a2', tag: 'CAM-01-MOT-B', nombre: 'Bomba'));
  });

  test('la gravedad sube por el árbol y deja de contar al terminar la OT', () {
    expect(gravedadDe('a1'), isNull);
    final ot = Tarea(id: 'ot1', nombre: 'Fuga', activoId: 'a3', tipoMantenimiento: TipoMantenimiento.correctivoCritico);
    store.tareas.add(ot);
    store.tareas.add(Tarea(id: 'ot2', activoId: 'a2', tipoMantenimiento: TipoMantenimiento.preventivo));
    expect(gravedadDe('a1'), TipoMantenimiento.correctivoCritico);
    expect(gravedadDe('a2'), TipoMantenimiento.correctivoCritico);
    ot.estado = EstadoTrabajo.realizado;
    expect(gravedadDe('a1'), TipoMantenimiento.preventivo);
  });

  test('borrar un activo quita sus componentes y deja sus OT sin activo', () {
    store.tareas.add(Tarea(id: 'ot1', activoId: 'a3', tipoMantenimiento: TipoMantenimiento.correctivoNoCritico));
    store.borrarActivo('a2');
    expect(store.activos.map((a) => a.id), ['a1']);
    expect(store.tareas.firstWhere((t) => t.id == 'ot1').activoId, isNull);
  });

  for (final ancho in [1440.0, 980.0, 700.0, 420.0]) {
    testWidgets('Activos y su ficha se pintan a ${ancho.round()} px', (tester) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Activos())));
      await tester.pumpAndSettle();
      expect(find.text('CAM-01 · Camión'), findsOneWidget);
      await tester.tap(find.text('CAM-01 · Camión'));
      await tester.pumpAndSettle();
      expect(find.text('CAM-01-MOT-B · Bomba'), findsOneWidget);
      if (ancho > 600) {
        await tester.tap(find.text('Nuevo componente'));
        await tester.pumpAndSettle();
        expect(find.text('Nuevo componente'), findsWidgets);
      }
    });
  }
}
