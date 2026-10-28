import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/screens/cliente_detalle.dart';
import 'package:pulpo/screens/clientes.dart';
import 'package:pulpo/screens/planificacion.dart';
import 'package:pulpo/screens/resumen.dart';
import 'package:pulpo/screens/tareas.dart';
import 'package:pulpo/screens/trabajador_detalle.dart';
import 'package:pulpo/screens/trabajadores.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cada pantalla se pinta sin errores con la empresa de ejemplo, en ancho de escritorio y estrecho.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemo();
  });

  final pantallas = <String, Widget Function()>{
    'Inicio': () => Resumen(onIr: (_) {}, onTrabajador: (_) {}),
    'Clientes': () => Clientes(onAbrir: (_) {}),
    'Trabajadores': () => Trabajadores(onAbrir: (_) {}),
    'Tareas': () => TareasPagina(onAbrir: (_) {}),
    'Agenda': () => const Planificacion(mapa: false),
    'Ficha de cliente': () => ClienteDetalle(clienteId: 'c1', onVolver: () {}),
    'Ficha de trabajador': () => TrabajadorDetalle(trabajadorId: 'w1', onVolver: () {}),
  };

  for (final ancho in [1440.0, 980.0, 700.0, 600.0, 420.0, 360.0]) {
    for (final e in pantallas.entries) {
      testWidgets('${e.key} se pinta a ${ancho.round()} px', (tester) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: e.value())));
        await tester.pumpAndSettle();
      });
    }
  }
}
