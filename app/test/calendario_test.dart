import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulpo/screens/planificacion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/ajustes.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/theme.dart';
import 'package:pulpo/screens/calendario_datos.dart';
import 'package:pulpo/screens/calendario_trabajos.dart';
import 'package:shared_preferences/shared_preferences.dart';

Tarea trabajo(String id, DateTime d, int? inicio, {int duracion = 60}) => Tarea(
  id: id,
  plantilla: false,
  nombre: 'Revisión $id',
  proximo: d,
  inicioMin: inicio,
  duracionMin: duracion,
  periodicidad: Periodicidad.unica,
);

void main() {
  final d = DateTime(2026, 10, 28);
  test('1000 coincidencias conservan todos los trabajos en carriles distintos', () {
    final tareas = List.generate(1000, (i) => trabajo('$i', d, 540));
    final visitas = visitasCalendario(tareas, d, d, (_, _) => true)[d]!;
    final reloj = Stopwatch()..start();
    final grupos = distribuirVisitas(visitas);
    expect(grupos.single.carriles, 1000);
    expect(grupos.single.posiciones.map((p) => p.$2).toSet().length, 1000);
    // Diagnóstico, no umbral dependiente del equipo.
    debugPrint('1000 solapes: ${reloj.elapsedMicroseconds} µs');
  });
  test('reutiliza carriles sin encoger el resto del día', () {
    final tareas = [
      trabajo('a', d, 540, duracion: 180),
      trabajo('b', d, 550),
      trabajo('c', d, 610),
      trabajo('d', d, 800),
    ];
    final g = distribuirVisitas(visitasCalendario(tareas, d, d, (_, _) => true)[d]!);
    expect(g.length, 2);
    expect(g.first.carriles, 2);
    expect(g.last.carriles, 1);
    expect(g.first.posiciones[1].$2, g.first.posiciones[2].$2);
  });
  test('medianoche, sin hora, historial y atrasados mantienen su fecha', () {
    final ayer = DateTime(2026, 10, 27);
    final noche = trabajo('noche', ayer, 1410, duracion: 120);
    final hecha = trabajo('hecha', d, 600)
      ..historial = [ayer]
      ..ultimo = ayer;
    final mapa = visitasCalendario(
      [noche, hecha, trabajo('sin', d, null), trabajo('atrasado', ayer, 480)],
      ayer,
      d,
      (_, _) => true,
    );
    expect(mapa[d]!.firstWhere((v) => v.tarea.id == 'noche').fin, 90);
    expect(mapa[d]!.firstWhere((v) => v.tarea.id == 'noche').inicio, 0);
    expect(mapa[ayer]!.where((v) => v.tarea.id == 'hecha').length, 1);
    expect(mapa[ayer]!.firstWhere((v) => v.tarea.id == 'hecha').hecha, isTrue);
    expect(mapa[d]!.any((v) => v.tarea.id == 'atrasado'), isFalse);
    expect(mapa[d]!.firstWhere((v) => v.tarea.id == 'sin').inicio, isNull);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ajustes.cargar();
    await store.cargar();
    store.tareas.clear();
    store.trabajadores.clear();
    store.clientes.clear();
  });

  Future<void> montar(WidgetTester tester, ModoCalendario modo, {double ancho = 1200, double escala = 1}) async {
    tester.view.physicalSize = Size(ancho, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPulpo(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: Size(ancho, 900), textScaler: TextScaler.linear(escala)),
            child: StatefulBuilder(
              builder: (context, cambiar) => CalendarioTrabajos(
                dia: hoy(),
                modo: modo,
                onModo: (m) => cambiar(() => modo = m),
                onDia: (_) => cambiar(() => modo = ModoCalendario.dia),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final modo in ModoCalendario.values) {
    for (final ancho in [1440.0, 980.0, 700.0, 600.0, 420.0, 360.0]) {
      testWidgets('$modo con carga a $ancho px', (tester) async {
        store.tareas.addAll(List.generate(120, (i) => trabajo('$i', hoy(), i < 100 ? 540 : 600 + (i - 100) * 15)));
        store.tareas.add(trabajo('sin hora', hoy(), null));
        await montar(tester, modo, ancho: ancho, escala: ancho == 420 ? 1.4 : 1);
        expect(tester.takeException(), isNull);
        if (modo == ModoCalendario.dia) {
          // Los 100 trabajos simultáneos se virtualizan: solo se montan las filas visibles.
          expect(find.byType(OverlayPortal).evaluate().length, lessThan(50));
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('resumen por hover, detalles y cerrar', (tester) async {
    store.tareas.add(trabajo('caldera', hoy(), 540));
    await montar(tester, ModoCalendario.dia);
    final evento = find.text('Revisión caldera');
    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.addPointer(location: Offset.zero);
    await raton.moveTo(tester.getCenter(evento));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ver detalles'), findsOneWidget);
    await raton.moveTo(tester.getCenter(find.text('Ver detalles')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ver detalles'), findsOneWidget);
    await tester.tap(find.text('Ver detalles'));
    await tester.pumpAndSettle();
    expect(find.text('Detalles del trabajo'), findsOneWidget);
    expect(find.text('Resumen'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar detalles'));
    await tester.pumpAndSettle();
    expect(find.text('Detalles del trabajo'), findsNothing);
    await raton.removePointer();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('semana saturada abre el día sin perder trabajos', (tester) async {
    store.tareas.addAll(List.generate(2000, (i) => trabajo('$i', hoy(), 540)));
    await montar(tester, ModoCalendario.semana);
    expect(find.text('2000 trabajos →'), findsOneWidget);
    await tester.tap(find.text('2000 trabajos →'));
    await tester.pumpAndSettle();
    // Ya en el día: los trabajos se ven sueltos, no agrupados.
    expect(find.text('2000 trabajos →'), findsNothing);
    expect(find.text('Revisión 0'), findsWidgets);
    expect(find.byType(OverlayPortal).evaluate().length, lessThan(50));
    expect(tester.takeException(), isNull);
  });
  testWidgets('resumen accesible se cierra con Escape en modo oscuro', (tester) async {
    ajustes.tema = ThemeMode.dark;
    store.tareas.add(trabajo('oscuro', hoy(), 540));
    await montar(tester, ModoCalendario.dia, ancho: 420, escala: 1.4);
    await tester.tap(find.text('Revisión oscuro'));
    await tester.pumpAndSettle();
    expect(find.text('Ver detalles'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Ver detalles'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('navegación integrada cambia meses y días', (tester) async {
    ajustes.vistaInicio = 1;
    ajustes.guiaItinerario = false;
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Planificacion(mapa: false))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mes siguiente'), findsOneWidget);
    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Día'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Día siguiente'), findsOneWidget);
    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('semana compacta sin contadores, franja ni pie y con siete días visibles', (tester) async {
    await montar(tester, ModoCalendario.semana, ancho: 600);
    expect(find.text('Sin hora'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.textContaining('Jornada destacada'), findsNothing);
    expect(find.text('Estado'), findsNothing);
    expect(find.text('Tipo'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.getBottomRight(find.text('DOM')).dx, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
  });
}
