import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/activos.dart';
import 'package:pulpo/industrial/plan.dart';
import 'package:pulpo/industrial/planes.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iPultec (IPT-005/006): el color de un activo es el de la OT pendiente más grave de su árbol.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.activos = [];
    store.planes = [];
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

  test('IPT-007: el mantenimiento del componente da la OT con su tipo, categoría y repuestos', () {
    final p = PlanMantenimiento(
      id: 'p1',
      activoId: 'a2',
      nombre: 'Cambio de aceite',
      tipo: TipoMantenimiento.correctivoNoCritico,
      cadaDias: 30,
      cadaHoras: 500,
      categoria: 'Electricidad',
      repuestos: 'Filtro',
      procedimiento: 'Vaciar y llenar',
      duracionMin: 90,
    );
    store.guardarPlan(p);
    expect(PlanMantenimiento.fromJson(p.toJson()).toJson(), p.toJson());
    expect(p.cada, 'cada 30 días · cada 500 h');
    final ot = p.ot('ot9');
    expect(ot.activoId, 'a2');
    expect(ot.tipoMantenimiento, TipoMantenimiento.correctivoNoCritico);
    expect(ot.competencias, ['Electricidad']);
    expect(ot.periodicidad, Periodicidad.mensual);
    expect(ot.duracionMin, 90);
    expect(ot.notas, contains('Filtro'));
    // Borrar el activo se lleva los mantenimientos de sus componentes.
    store.borrarActivo('a1');
    expect(store.planes, isEmpty);
  });

  for (final ancho in [1440.0, 700.0, 420.0]) {
    testWidgets('IPT-007: el formulario de mantenimiento se pinta y valida a ${ancho.round()} px', (tester) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PlanForm(activoId: 'a2'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();
      expect(find.text('Ponle un nombre'), findsOneWidget);
      expect(store.planes, isEmpty);
    });
  }

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
      expect(find.text('Nuevo mantenimiento'), findsOneWidget);
      if (ancho > 600) {
        await tester.tap(find.text('Nuevo componente'));
        await tester.pumpAndSettle();
        expect(find.text('Nuevo componente'), findsWidgets);
      }
    });
  }
}
