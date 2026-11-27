// Flujo de incidencias del administrador en la interfaz: de la lista a la OT y vuelta, sin recargar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/industrial/activo.dart';
import 'package:pultec/industrial/incidencia.dart';
import 'package:pultec/industrial/incidencias.dart';
import 'package:pultec/marca.dart';
import 'package:pultec/models.dart';
import 'package:pultec/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pagina(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Como en el shell: la página se rehace con cada cambio del store.
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ListenableBuilder(
        listenable: store,
        // ignore: prefer_const_constructors
        builder: (_, _) => IncidenciasPagina(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _cerrarPanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Cerrar').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.activos = [
      Activo(id: 'a', nombre: 'Compresor', tag: 'CMP-02'),
      Activo(id: 'c', nombre: 'Motor', tag: 'MOT-01', padreId: 'a'),
    ];
    store.trabajadores = [
      Trabajador(id: 'iker', nombre: 'Iker'),
      Trabajador(id: 'ana', nombre: 'Ana'),
    ];
    store.tareas = [
      Tarea(id: 'origen', nombre: 'Engrase', activoId: 'a', plantilla: false, trabajadorIds: ['ana'], proximo: hoy()),
    ];
    store.subtareas = [];
    store.planes = [];
    store.incidencias = [
      Incidencia(id: 'i1', activoId: 'c', tecnicoId: 'iker', origenTrabajoId: 'origen', descripcion: 'Ruido raro'),
      Incidencia(id: 'i2', activoId: 'a', tecnicoId: 'iker', descripcion: 'Fuga de aceite'),
    ];
  });

  testWidgets('crear la OT: «Incidencia → Orden de trabajo», técnico por defecto y «Con OT» al momento',
      skip: !industrial, (tester) async {
    await _pagina(tester);
    // La columna Activo dice solo la máquina; Comunicada por, el técnico.
    expect(find.text('Compresor - CMP-02'), findsNWidgets(2));
    expect(find.textContaining('›'), findsNothing);
    expect(find.text('Iker'), findsNWidgets(2));

    await tester.tap(find.text('Ruido raro'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'Comunicada por .*Iker el'), findRichText: true), findsOneWidget);
    // Avisada desde una OT abierta: interrumpirla (con confirmación) y seguir en una nueva.
    await tester.tap(find.text('Interrumpir y crear OT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interrumpir y crear OT').last);
    await tester.pumpAndSettle();
    expect(store.tarea('origen')!.estado, EstadoTrabajo.interrumpida);

    final ot = store.tareas.firstWhere((t) => t.id != 'origen');
    expect(find.text('INCIDENCIA'), findsOneWidget);
    expect(find.text('ORDEN DE TRABAJO'), findsOneWidget);
    expect(ot.trabajadorIds, ['ana'], reason: 'quien lleva la orden en la que se detectó');
    expect(store.incidencias.firstWhere((x) => x.id == 'i1').trabajoId, ot.id);
    await _cerrarPanel(tester);
    expect(find.text('Con OT'), findsWidgets, reason: 'la lista cambia sin recargar');
    expect(store.estadoIncidencia(store.incidencias.firstWhere((x) => x.id == 'i1')), EstadoIncidencia.conOt);

    // Sin orden de origen: el técnico que la comunicó.
    await tester.tap(find.text('Fuga de aceite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear OT'));
    await tester.pumpAndSettle();
    final ot2 = store.tareas.firstWhere((t) => t.id != 'origen' && t.id != ot.id);
    expect(ot2.trabajadorIds, ['iker']);
    await _cerrarPanel(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desestimar, reabrir y cancelar la OT; vacíos según el filtro', skip: !industrial, (tester) async {
    await _pagina(tester);
    await tester.tap(find.text('Fuga de aceite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desestimar'));
    await tester.pumpAndSettle();
    expect(store.estadoIncidencia(store.incidencias.firstWhere((x) => x.id == 'i2')), EstadoIncidencia.desestimada);
    expect(find.text('Fuga de aceite'), findsNothing, reason: 'sale de pendientes al momento');

    // Al histórico (desestimadas) y reabrirla.
    await tester.tap(find.textContaining('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Sin incidencias completadas'), findsOneWidget);
    await tester.tap(find.text('Desestimadas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuga de aceite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reabrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(store.estadoIncidencia(store.incidencias.firstWhere((x) => x.id == 'i2')), EstadoIncidencia.abierta);
    expect(find.text('Sin incidencias desestimadas'), findsOneWidget);

    // Con OT → «Cancelar OT y desestimar».
    await tester.tap(find.textContaining('Pendientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruido raro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interrumpir y crear OT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interrumpir y crear OT').last);
    await tester.pumpAndSettle();
    await _cerrarPanel(tester);
    final ot = store.tarea(store.incidencias.firstWhere((x) => x.id == 'i1').trabajoId)!;
    await tester.tap(find.text('Ruido raro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar OT y desestimar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar OT y desestimar').last);
    await tester.pumpAndSettle();
    expect(ot.estado, EstadoTrabajo.noRealizado, reason: 'la OT queda cancelada');
    expect(store.estadoIncidencia(store.incidencias.firstWhere((x) => x.id == 'i1')), EstadoIncidencia.desestimada);
    expect(find.text('Ruido raro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seguir en la misma OT: la incidencia se une a ella y no se crea otra', skip: !industrial, (tester) async {
    await _pagina(tester);
    await tester.tap(find.text('Ruido raro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguir en la misma OT'));
    await tester.pumpAndSettle();
    final i1 = store.incidencias.firstWhere((x) => x.id == 'i1');
    expect(i1.trabajoId, 'origen');
    expect(store.estadoIncidencia(i1), EstadoIncidencia.conOt);
    expect(store.tarea('origen')!.estado.abierta, isTrue);
    expect(store.tareas.length, 1, reason: 'no se crea otra OT');
    expect(tester.takeException(), isNull);
  });

  testWidgets('seguir en la misma OT que ya resuelve otra: se une a ella y sube de nivel', skip: !industrial, (tester) async {
    store.incidencias.add(Incidencia(id: 'i0', activoId: 'a', tecnicoId: 'iker', origenTrabajoId: 'otra',
      trabajoId: 'origen', estado: EstadoIncidencia.conOt, gravedad: Gravedad.media, descripcion: 'Ruido leve'));
    store.incidencias.firstWhere((x) => x.id == 'i1').gravedad = Gravedad.grave;
    await _pagina(tester);
    await tester.tap(find.text('Ruido raro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguir en la misma OT'));
    await tester.pumpAndSettle();
    expect(store.incidencias.where((x) => x.id == 'i1'), isEmpty, reason: 'no quedan dos');
    final i0 = store.incidencias.firstWhere((x) => x.id == 'i0');
    expect(i0.gravedad, Gravedad.grave);
    expect(i0.descripcion, startsWith('Ruido raro'));
    expect(i0.descripcion, contains('Antes: Ruido leve'));
    expect(store.tarea('origen')!.tipoMantenimiento, TipoMantenimiento.correctivoCritico);
    expect(tester.takeException(), isNull);
  });
}
