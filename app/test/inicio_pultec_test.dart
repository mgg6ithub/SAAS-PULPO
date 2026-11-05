import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/plan.dart';
import 'package:pulpo/industrial/vistazo.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inicio de Pultec: un mantenimiento sale abajo mientras no tiene orden; con orden, solo arriba.
void main() {
  testWidgets('mantenimiento sin orden abajo; al crear su orden pasa arriba', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store
      ..activos = []
      ..planes = []
      ..incidencias = []
      ..tareas = []
      ..subtareas = [];
    store.guardarActivo(Activo(id: 'a1', tag: 'CAM-09', nombre: 'Camión de prueba'));
    final p1 = PlanMantenimiento(id: 'p1', activoId: 'a1', nombre: 'Cambio de aceite', cadaDias: 30, proximo: masDias(hoy(), 5));
    final p2 = PlanMantenimiento(
      id: 'p2',
      activoId: 'a1',
      nombre: 'Revisión de frenos',
      tipo: TipoMantenimiento.correctivoCritico,
      cadaDias: 60,
      proximo: masDias(hoy(), 9),
    );
    store
      ..guardarPlan(p1)
      ..guardarPlan(p2);

    Widget inicio() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              VistazoActivos(onAbrir: (_) {}, onVerMas: (_) {}, columnas: 3),
              MantenimientosSinAsignar(onAbrir: (_) {}),
            ],
          ),
        ),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    await tester.pumpWidget(inicio());
    // Sin órdenes: arriba vacío, abajo los dos mantenimientos.
    expect(find.text('Ninguna orden de trabajo'), findsNWidgets(3));
    expect(find.text('Mantenimientos sin orden de trabajo'), findsOneWidget);
    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.text('Revisión de frenos'), findsOneWidget);

    // Se crea la orden del primero: sale arriba y deja de salir abajo.
    store.guardarTarea(p1.ot('ot1'));
    await tester.pumpWidget(inicio());
    await tester.pump();
    expect(find.text('Ninguna orden de trabajo'), findsNWidgets(2));
    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.text('Revisión de frenos'), findsOneWidget);

    // Con las dos órdenes creadas, la lista de abajo desaparece.
    store.guardarTarea(p2.ot('ot2'));
    await tester.pumpWidget(inicio());
    await tester.pump();
    expect(find.text('Mantenimientos sin orden de trabajo'), findsNothing);
    expect(find.text('Revisión de frenos'), findsOneWidget);
  });
}
