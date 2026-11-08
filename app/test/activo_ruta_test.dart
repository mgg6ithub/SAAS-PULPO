import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/activos.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/industrial/plan.dart';
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
      for (var i = 1; i <= 3; i++)
        PlanMantenimiento(id: 'p$i', activoId: 'a', nombre: 'Plan $i'),
    ];
    store.tareas = [
      Tarea(id: 'ot2', planId: 'p2', activoId: 'a', nombre: 'Plan 2', plantilla: false,
        tipoMantenimiento: TipoMantenimiento.preventivo),
      Tarea(id: 'ot3', planId: 'p3', activoId: 'a', nombre: 'Plan 3', plantilla: false,
        trabajadorIds: ['tecnico'], tipoMantenimiento: TipoMantenimiento.preventivo),
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ActivoDetalle(activoId: 'a', onVolver: () {}),
    )));
    await tester.pumpAndSettle();
    for (final caso in [('Sin orden', 'Plan 1'), ('Sin asignar', 'Plan 2'), ('Asignados', 'Plan 3')]) {
      await tester.tap(find.text(caso.$1).first);
      await tester.pumpAndSettle();
      expect(find.text(caso.$2), findsOneWidget);
      for (final nombre in ['Plan 1', 'Plan 2', 'Plan 3'].where((n) => n != caso.$2)) {
        expect(find.text(nombre), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
