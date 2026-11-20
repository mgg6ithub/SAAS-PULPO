import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/screens/cliente_detalle.dart';
import 'package:pultec/screens/clientes.dart';
import 'package:pultec/screens/planificacion.dart';
import 'package:pultec/screens/resumen.dart';
import 'package:pultec/screens/tareas.dart';
import 'package:pultec/screens/trabajador_detalle.dart';
import 'package:pultec/screens/trabajadores.dart';
import 'package:pultec/shell.dart';
import 'package:pultec/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cada pantalla se pinta sin errores con la empresa de ejemplo, en ancho de escritorio y estrecho.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemo();
  });

  final pantallas = <String, Widget Function()>{
    'Shell': () => const Shell(),
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
