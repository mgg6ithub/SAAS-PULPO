import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/plan.dart';
import 'package:pulpo/industrial/planes.dart';
import 'package:pulpo/industrial/uso_maquinas.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Activo activo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    activo = Activo(
      id: 'a',
      nombre: 'Camión cisterna Volvo FH',
      tag: 'CAM-01',
      usoPlanificado: true,
      horas: 100,
      horasTurno: 8,
      fechaLectura: masDias(hoy(), -3),
    );
    store.activos = [activo];
    store.planes = [];
  });

  test('corregir turnos tras la lectura recalcula horas y fecha estimada', () {
    final ayer = masDias(hoy(), -1);
    ponerTurnos(activo, ayer, 1);
    ponerTurnos(activo, masDias(hoy(), 1), 1);
    ponerTurnos(activo, masDias(hoy(), 2), 1);
    final plan = PlanMantenimiento(id: 'p', activoId: 'a', cadaHoras: 16, ultimoHoras: 100);
    expect(horasHoy(activo), 108);
    expect(proximoPlan(plan), masDias(hoy(), 1));
    ponerTurnos(activo, ayer, 0);
    expect(turnosDe(activo, ayer), 0);
    expect(horasHoy(activo), 100);
    expect(proximoPlan(plan), masDias(hoy(), 2));
    expect(activo.horas, 100);
  });

  test('los turnos hasta la fecha de lectura no alteran la lectura real', () {
    for (final dia in [activo.fechaLectura, masDias(activo.fechaLectura, -1)]) {
      ponerTurnos(activo, dia, 2);
      expect(horasHoy(activo), 100);
      ponerTurnos(activo, dia, 0);
      expect(horasHoy(activo), 100);
    }
    final plan = PlanMantenimiento(id: 'p', activoId: 'a', cadaDias: 30, proximo: masDias(hoy(), 10));
    expect(proximoPlan(plan), masDias(hoy(), 10));
  });

  testWidgets('el uso ocupa una vista propia y permite volver a activos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => abrirUsoMaquinas(context), child: const Text('Abrir')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Uso de activos'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a Activos'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrastrar crea un turno y tocar pasa a dos y después quita', (tester) async {
    tester.view.physicalSize = const Size(1400, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UsoMaquinas())));
    final day = tester.getCenter(find.byType(DragTarget<String>).at(14));
    final start = tester.getCenter(find.byType(Draggable<String>));
    await tester.dragFrom(start, day - start);
    await tester.pumpAndSettle();
    // En el día: la máquina con su color; claro con 1 turno, lleno y «×2» con 2.
    expect(find.text('CAM-01'), findsOneWidget);
    expect(find.text('×2'), findsNothing);
    expect(activo.turnos.values.single, 1);
    await tester.tap(find.text('CAM-01'));
    await tester.pumpAndSettle();
    expect(find.text('×2'), findsOneWidget);
    expect(activo.turnos.values.single, 2);
    await tester.tap(find.text('CAM-01'));
    await tester.pumpAndSettle();
    expect(activo.turnos, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final width in [1600.0, 1000.0, 700.0, 420.0, 360.0]) {
    testWidgets('calendario sin desbordamientos a $width px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ponerTurnos(activo, hoy(), 2);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UsoMaquinas())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Uso de activos'), findsOneWidget);
    });
  }
}
