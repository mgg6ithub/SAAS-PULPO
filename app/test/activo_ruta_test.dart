import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/activos.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/industrial/plan.dart';
import 'package:pulpo/industrial/historicos.dart';
import 'package:pulpo/widgets.dart';
import 'package:pulpo/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    reiniciarVistaActivos();
    store.tareas = [];
  });

  testWidgets('ruta conserva el tag cuando el nombre está vacío, con cualquier icono', (tester) async {
    store.activos = [
      Activo(id: 'raiz', nombre: 'Camión'),
      Activo(id: 'hijo', padreId: 'raiz', tag: 'Otro componente mas', icono: 'brazo'),
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ActivoDetalle(activoId: 'hijo', onVolver: () {}),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Otro componente mas'), findsOneWidget);
    expect(find.text('Activo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ruta larga muestra el actual y permite desplazar hacia los ancestros', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store.activos = List.generate(12, (i) => Activo(
      id: '$i', padreId: i == 0 ? null : '${i - 1}',
      nombre: 'Componente número $i de la máquina',
    ));
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ActivoDetalle(activoId: '11', onVolver: () {}),
    )));
    await tester.pumpAndSettle();
    final ruta = find.byWidgetPredicate((w) => w is SingleChildScrollView && w.controller != null && w.scrollDirection == Axis.horizontal);
    final scroll = tester.widget<SingleChildScrollView>(ruta).controller!;
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(scroll.offset, scroll.position.maxScrollExtent);
    scroll.jumpTo(0);
    await tester.pump();
    expect(scroll.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra mantenimientos según la asignación de su OT pendiente', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store.activos = [Activo(id: 'a', nombre: 'Máquina')];
    store.planes = [
      for (var i = 2; i <= 3; i++)
        PlanMantenimiento(id: 'p$i', activoId: 'a', nombre: 'Plan $i'),
    ];
    store.tareas = [
      Tarea(id: 'ot2', planId: 'p2', activoId: 'a', nombre: 'Plan 2', plantilla: false,
        proximo: hoy().add(const Duration(days: 2)),
        tipoMantenimiento: TipoMantenimiento.preventivo),
      Tarea(id: 'ot3', planId: 'p3', activoId: 'a', nombre: 'Plan 3', plantilla: false,
        proximo: hoy(),
        trabajadorIds: ['tecnico'], tipoMantenimiento: TipoMantenimiento.preventivo),
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ActivoDetalle(activoId: 'a', onVolver: () {}),
    )));
    await tester.pumpAndSettle();
    // Todo mantenimiento tiene su OT (la crea la base): ya no hay «Sin orden».
    expect(find.text('Sin orden'), findsNothing);
    for (final caso in [('Sin asignar', 'Plan 2'), ('Asignados', 'Plan 3')]) {
      await tester.tap(find.text(caso.$1).first);
      await tester.pumpAndSettle();
      expect(find.text(caso.$2), findsOneWidget);
      for (final nombre in ['Plan 2', 'Plan 3'].where((n) => n != caso.$2)) {
        expect(find.text(nombre), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Órdenes de trabajo').first);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Plan 3')).dy, lessThan(tester.getTopLeft(find.text('Plan 2')).dy));
    await tester.tap(find.text('Sin asignar').first);
    await tester.pumpAndSettle();
    expect(find.text('Plan 2'), findsOneWidget);
    expect(find.text('Plan 3'), findsNothing);
    await tester.tap(find.text('Asignados').first);
    await tester.pumpAndSettle();
    expect(find.text('Plan 3'), findsOneWidget);
    expect(find.text('Plan 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final ancho in [1600.0, 1000.0, 700.0, 420.0, 360.0]) {
    testWidgets('histórico adapta los filtros a $ancho y conserva tres meses', (tester) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Historicos(activoId: 'a'))));
      await tester.pumpAndSettle();
      expect(find.text('Últimos 3 meses'), findsOneWidget);
      expect(find.byType(Pestanas), findsNWidgets(ancho > 1500 ? 2 : 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('completar una OT reduce su fila antes de retirarla', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store.activos = [Activo(id: 'a', nombre: 'Máquina')];
    final ot = Tarea(id: 'ot', activoId: 'a', nombre: 'Orden animada', plantilla: false,
      periodicidad: Periodicidad.unica, tipoMantenimiento: TipoMantenimiento.preventivo, proximo: hoy());
    store.tareas = [ot];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListenableBuilder(
      listenable: store, builder: (_, _) => ActivoDetalle(activoId: 'a', onVolver: () {}),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Órdenes de trabajo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendiente').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completada').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ot.estado, EstadoTrabajo.pendiente);
    expect(find.text('Orden animada'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(ot.estado, EstadoTrabajo.realizado);
    expect(find.text('Orden animada'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
