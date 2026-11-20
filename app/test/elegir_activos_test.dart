import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/marca.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/vista_trabajador.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Al entrar, el técnico ve marcados los activos de la última vez que aún tienen órdenes («Seguir»); los que ya
/// no tienen salen al final, sin marcar; si cambia algo, el botón dice «Empezar».
void main() {
  testWidgets(skip: !industrial, 'recuerda los activos elegidos y aparta los que ya no tienen órdenes', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'maquinas_demo_w': ['a', 'b', 'c']});
    await store.cargar();
    store.activos = [
      Activo(id: 'a', nombre: 'Prensa'),
      Activo(id: 'b', nombre: 'Horno'),
      Activo(id: 'c', nombre: 'Caldera'),
      Activo(id: 'd', nombre: 'Bomba'),
    ];
    store.trabajadores = [Trabajador(id: 'w', nombre: 'Juan')];
    store.subtareas = [];
    store.incidencias = [];
    // Prensa, Horno y Bomba con órdenes; Caldera, elegida la otra vez, ya sin ninguna.
    store.tareas = [
      for (final a in ['a', 'b', 'd'])
        Tarea(id: 'ot$a', activoId: a, nombre: 'Orden $a', plantilla: false, trabajadorIds: ['w'], proximo: hoy(),
          tipoMantenimiento: TipoMantenimiento.preventivo),
    ];
    rolTrabajador.value = 'w';
    addTearDown(() => rolTrabajador.value = null);
    await tester.pumpWidget(const MaterialApp(home: ShellTrabajador()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Seguir con 2 órdenes'), findsOneWidget, reason: 'Prensa y Horno, como la última vez');
    expect(find.text('Sin órdenes pendientes'), findsOneWidget, reason: 'Caldera, sin marcar');
    // Caldera, la última de la cuadrícula.
    final caldera = tester.getTopLeft(find.text('Caldera')), bomba = tester.getTopLeft(find.text('Bomba'));
    expect(caldera.dy > bomba.dy + 40 || caldera.dx > bomba.dx, isTrue);
    await tester.tap(find.text('Bomba'));
    await tester.pumpAndSettle();
    expect(find.text('Empezar con 3 órdenes'), findsOneWidget, reason: 'ha cambiado la selección');
    await tester.tap(find.text('Empezar con 3 órdenes'));
    await tester.pumpAndSettle();
    final guardado = (await SharedPreferences.getInstance()).getStringList('maquinas_demo_w');
    expect(guardado?.toSet(), {'a', 'b', 'd'}, reason: 'se recuerda para la próxima vez, sin Caldera');
    expect(tester.takeException(), isNull);
  });
}
