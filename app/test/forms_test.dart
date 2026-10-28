import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    // La cuenta empieza vacía (solo plantillas): creamos lo mínimo para probar.
    store.guardarCliente(Cliente(id: 'c3', nombre: 'Ascensores Altura'));
    store.guardarTrabajador(Trabajador(id: 'w3', nombre: 'Javier', competencias: ['Ascensores', 'Electricidad']));
    store.guardarTarea(Tarea(id: 't2', clienteId: 'c3', nombre: 'Ascensor portal A', tipo: 'Ascensor'));
  });

  test('una cuenta nueva solo trae las plantillas', () async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    expect(store.clientes, isEmpty);
    expect(store.trabajadores, isEmpty);
    expect(store.tareas.every((t) => t.esPlantilla), isTrue);
  });

  Future<void> pintar(WidgetTester tester, Widget ventana) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ventana)));
    await tester.pumpAndSettle();
  }

  testWidgets('los formularios se pintan sin errores', (tester) async {
    await pintar(tester, ClienteForm(original: store.clientes.first));
    await pintar(tester, TrabajadorForm(original: store.trabajadores.first));
    await pintar(tester, TareaForm(original: store.tareas.firstWhere((t) => !t.esPlantilla)));
  });

  testWidgets('desde un cliente la tarea va a ese cliente y la plantilla la rellena', (tester) async {
    await pintar(tester, const TareaForm(clienteId: 'c3'));
    expect(find.text('Sin cliente (plantilla)'), findsNothing);
    await tester.tap(find.text('Mantenimiento de ascensor'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Mantenimiento de ascensor'), findsOneWidget);
    // La plantilla propone al trabajador apto.
    expect(find.text('Javier'), findsOneWidget);
  });

  testWidgets('desde Tareas se puede elegir cliente', (tester) async {
    await pintar(tester, const TareaForm());
    // Un trabajo nuevo no propone cliente y empieza hoy.
    expect(find.text('Elegir cliente'), findsOneWidget);
    expect(find.textContaining('· hoy'), findsOneWidget);

    // El menú de clientes lista los clientes y ofrece crear uno nuevo.
    await tester.tap(find.text('Elegir cliente'));
    await tester.pumpAndSettle();
    expect(find.text('Ascensores Altura'), findsOneWidget);
    expect(find.text('Crear nuevo cliente'), findsOneWidget);
  });

  testWidgets('la ventana se acopla a la derecha y vuelve', (tester) async {
    await pintar(tester, const ClienteForm());
    await tester.tap(find.byTooltip('Acoplar a la derecha'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Acoplar al centro'), findsOneWidget);
    await tester.tap(find.byTooltip('Acoplar al centro'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Acoplar a la derecha'), findsOneWidget);
  });

  test('las plantillas se ordenan por uso reciente (LRU)', () async {
    final ids = store.plantillasPorUso.map((p) => p.id).toList();
    store.usarPlantilla(ids.last);
    expect(store.plantillasPorUso.first.id, ids.last);
    store.usarPlantilla(ids[1]);
    expect(store.plantillasPorUso.take(2).map((p) => p.id), [ids[1], ids.last]);
    // Se guarda al recargar.
    await store.cargar();
    expect(store.plantillasPorUso.first.id, ids[1]);
  });
}
