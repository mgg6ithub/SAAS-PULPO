import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/activos.dart';
import 'package:pulpo/industrial/incidencia.dart';
import 'package:pulpo/industrial/mantenimientos.dart';
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
    store.incidencias = [];
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

  testWidgets('IPT-008: la OT solo se le puede dar a un técnico de su categoría', (tester) async {
    final apto = Trabajador(id: 'wA', nombre: 'Ane', competencias: ['Electricidad']);
    final otro = Trabajador(id: 'wB', nombre: 'Beñat', competencias: ['Jardinería']);
    store.trabajadores = [apto, otro];
    final ot = Tarea(id: 'ot5', nombre: 'Motor', activoId: 'a2', competencias: ['Electricidad']);
    expect(store.puedeRecibir(apto, ot), isTrue);
    expect(store.puedeRecibir(otro, ot), isFalse);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SelectorTrabajadores(ot, () {}))));
    await tester.tap(find.byType(SelectorTrabajadores));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beñat'));
    await tester.tap(find.text('Ane'));
    await tester.pump();
    expect(ot.trabajadorIds, ['wA']);
    // El alta del técnico pide su categoría.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TrabajadorForm())));
    await tester.pumpAndSettle();
    expect(find.text('Categorías'), findsOneWidget);
  });

  for (final ancho in [1440.0, 700.0, 420.0]) {
    testWidgets('IPT-007: el formulario de mantenimiento se pinta y valida a ${ancho.round()} px', (tester) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PlanForm(activoId: 'a2')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();
      expect(find.text('Ponle un nombre'), findsOneWidget);
      expect(store.planes, isEmpty);
    });
  }

  for (final ancho in [1440.0, 980.0, 700.0, 420.0]) {
    testWidgets('IPT-010: pendientes e incidencias por activo, con su gravedad, a ${ancho.round()} px', (tester) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store
        ..guardarActivo(Activo(id: 'b1', tag: 'PRE-01', nombre: 'Prensa'))
        ..guardarIncidencia(
          Incidencia(id: 'i1', activoId: 'a3', descripcion: 'Fuga de aceite', gravedad: Gravedad.grave),
        )
        ..guardarIncidencia(Incidencia(id: 'i2', activoId: 'b1', descripcion: 'Ruido raro', gravedad: Gravedad.leve));
      store.tareas
        ..add(
          Tarea(
            id: 'ot1',
            nombre: 'Cambiar junta',
            activoId: 'a3',
            tipoMantenimiento: TipoMantenimiento.correctivoCritico,
          ),
        )
        ..add(Tarea(id: 'ot2', nombre: 'Engrasar', activoId: 'b1', tipoMantenimiento: TipoMantenimiento.preventivo));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Activos())));
      await tester.pumpAndSettle();
      // Móvil: las pestañas son un desplegable.
      Future<void> pestana(String t, int cual) async {
        if (find.text(t).evaluate().isEmpty) {
          await tester.tap(find.byType(PopupMenuButton<int>).at(cual));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(t).last);
        await tester.pumpAndSettle();
      }

      await pestana('Mantenimientos', 0);
      expect(tester.takeException(), isNull);
      expect(find.text('Cambiar junta'), findsOneWidget);
      expect(find.text('Engrasar'), findsOneWidget);
      await pestana('Incidencias', 1);
      expect(find.text('Fuga de aceite'), findsOneWidget);
      expect(find.text('Ruido raro'), findsOneWidget);
      // Solo las de la prensa.
      await tester.tap(find.byType(FiltroActivo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PRE-01 · Prensa').last);
      await tester.pumpAndSettle();
      expect(find.text('Fuga de aceite'), findsNothing);
      expect(find.text('Ruido raro'), findsOneWidget);
      if (ancho > 980) expect(find.text('Leve'), findsOneWidget);
      // La incidencia abre su ficha con la gravedad.
      await tester.tap(find.text('Ruido raro'));
      await tester.pumpAndSettle();
      expect(find.text('Crear OT'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
