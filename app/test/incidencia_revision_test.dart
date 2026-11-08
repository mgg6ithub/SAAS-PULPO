import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/incidencia.dart';
import 'package:pulpo/industrial/incidencia_form.dart';
import 'package:pulpo/industrial/plan.dart';
import 'package:pulpo/industrial/vistazo.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/screens/vista_trabajador.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.activos = [Activo(id: 'a', nombre: 'Máquina')];
    store.tareas = [];
    store.subtareas = [];
    store.incidencias = [];
  });
  testWidgets('avisar crea una incidencia abierta sin crear una OT', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: AvisoIncidenciaForm()))),
      child: const Text('Avisar'),
    )))));
    await tester.tap(find.text('Avisar'));
    await tester.pumpAndSettle();
    tester.widget<SelectorActivo>(find.byType(SelectorActivo)).onChanged('a');
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Fuga de aceite');
    await tester.pump();
    tester.widget<VentanaFormulario>(find.byType(VentanaFormulario)).onGuardar!();
    await tester.pumpAndSettle();
    expect(store.tareas, isEmpty);
    expect(store.incidencias.single.estado, EstadoIncidencia.abierta);
    expect(store.incidencias.single.trabajoId, isNull);
    expect(store.incidencias.single.descripcion, 'Fuga de aceite');
    expect(tester.takeException(), isNull);
  });
  testWidgets('el responsable ve las incidencias sin OT para revisarlas', (tester) async {
    store.incidencias = [Incidencia(id: 'i', activoId: 'a', descripcion: 'Fuga de aceite')];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IncidenciasAbiertas(onAbrir: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.text('Fuga de aceite'), findsOneWidget);
    expect(find.text('Revisar'), findsOneWidget);
    expect(find.textContaining('Pendiente de revisión'), findsOneWidget);
  });
  test('resolver un aviso no completa la OT ni reinicia su mantenimiento', () {
    final p = PlanMantenimiento(id: 'p', activoId: 'a', cadaDias: 30, ultimoHoras: 100, proximo: DateTime(2026, 12, 1));
    store.planes = [p];
    final t = Tarea(id: 'ot', activoId: 'a', planId: 'p', plantilla: false, resultado: 2,
      tipoMantenimiento: TipoMantenimiento.preventivo);
    store.tareas = [t];
    t.resultadoResuelto = true;
    store.guardarTarea(t);
    expect(t.estado, EstadoTrabajo.pendiente);
    expect(t.resultado, 2);
    expect(p.ultimoHoras, 100);
    expect(p.proximo, DateTime(2026, 12, 1));
  });

  testWidgets('el técnico distingue hoy y atrasadas de las próximas órdenes', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store.trabajadores = [Trabajador(id: 'w', nombre: 'Juan')];
    rolTrabajador.value = 'w';
    addTearDown(() => rolTrabajador.value = null);
    store.tareas = [
      for (final d in [-1, 0, 3]) Tarea(id: '$d', activoId: 'a', nombre: 'Revisión $d',
        plantilla: false, trabajadorIds: ['w'], proximo: hoy().add(Duration(days: d)),
        tipoMantenimiento: TipoMantenimiento.preventivo),
    ];
    await tester.pumpWidget(const MaterialApp(home: ShellTrabajador()));
    await tester.pumpAndSettle();
    expect(find.text('Revisión 0'), findsOneWidget);
    expect(find.text('Revisión -1'), findsOneWidget);
    expect(find.text('Revisión 3').hitTestable(), findsNothing);
    await tester.tap(find.text('Próximas órdenes · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Revisión 3').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
