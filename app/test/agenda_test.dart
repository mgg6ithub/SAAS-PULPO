import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/agenda_herramientas.dart';
import 'package:pulpo/screens/agenda_vistas.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    filtroAgenda.limpiar();
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio'));
    store.guardarTrabajador(Trabajador(id: 'w1', nombre: 'Javier', competencias: ['Ascensores']));
    store.guardarTrabajador(Trabajador(id: 'w2', nombre: 'Lucía', competencias: ['Ascensores']));
    store.guardarTarea(
      Tarea(
        id: 'a',
        clienteId: 'c1',
        nombre: 'Ascensor',
        tipo: 'Ascensor',
        proximo: hoy(),
        inicioMin: 600,
        trabajadorIds: ['w1'],
      ),
    );
    store.guardarTarea(Tarea(id: 'b', clienteId: 'c1', nombre: 'Caldera', tipo: 'Caldera', proximo: hoy()));
  });

  test('los filtros de la agenda filtran por técnico, tipo y estado', () {
    expect(tareasDe(hoy()).length, 2);
    filtroAgenda.soloTecnico('w1');
    expect(tareasDe(hoy()).map((t) => t.id), ['a']);
    filtroAgenda.limpiar();
    filtroAgenda.ponerEstado(EstadoFiltro.sinAsignar);
    expect(tareasDe(hoy()).map((t) => t.id), ['b']);
    filtroAgenda.limpiar();
    filtroAgenda.ponerTipo('Caldera');
    expect(tareasDe(hoy()).map((t) => t.id), ['b']);
    filtroAgenda.limpiar();
    filtroAgenda.buscar('javier');
    expect(tareasDe(hoy()).map((t) => t.id), ['a']);
    filtroAgenda.buscar('colegio');
    expect(tareasDe(hoy()).length, 2);
  });

  testWidgets('pulsar una tarea abre la ficha rápida y se puede asignar y marcar hecha', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VistaDiaTecnicos(hoy()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ascensor').first);
    await tester.pumpAndSettle();
    expect(find.text('Marcar hecha'), findsOneWidget);

    await tester.tap(find.text('Lucía').last);
    await tester.pumpAndSettle();
    expect(store.tareas.firstWhere((t) => t.id == 'a').trabajadorIds, unorderedEquals(['w1', 'w2']));

    await tester.tap(find.text('Marcar hecha'));
    await tester.pumpAndSettle();
    expect(store.tareas.firstWhere((t) => t.id == 'a').ultimo, hoy());
  });

  testWidgets('crear desde la agenda rellena fecha, hora y técnico', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TareaForm(fecha: masDias(hoy(), 2), horaMin: 630, trabajadorId: 'w2'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Revisión urgente');
    await tester.pumpAndSettle();
    expect(find.textContaining('10:30'), findsWidgets);
    expect(find.textContaining(fecha(masDias(hoy(), 2))), findsOneWidget);
  });

  testWidgets('una tarea nueva aparece al momento en el itinerario', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(listenable: store, builder: (_, _) => VistaDiaTecnicos(hoy())),
        ),
      ),
    );
    expect(find.text('Extintores planta 2'), findsNothing);
    store.guardarTarea(
      Tarea(
        id: 'n',
        clienteId: 'c1',
        nombre: 'Extintores planta 2',
        proximo: hoy(),
        inicioMin: 720,
        trabajadorIds: ['w2'],
      ),
    );
    expect(store.esRecien('n'), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Extintores planta 2'), findsOneWidget);
  });
}
