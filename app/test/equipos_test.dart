import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/cliente_detalle.dart';
import 'package:pulpo/screens/resumen.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Equipos de los clientes: vencimientos legales, borrado en cascada, ficha de cliente, formulario y aviso en Inicio.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio Arana'));
    store.guardarEquipo(Equipo(id: 'e1', clienteId: 'c1', tipo: 'Ascensor', nombre: 'Ascensor 1', marca: 'Orona'));
    store.guardarVencimiento(Vencimiento(id: 'v1', equipoId: 'e1', nombre: 'OCA', vence: masDias(hoy(), -3)));
    store.guardarVencimiento(Vencimiento(id: 'v2', equipoId: 'e1', nombre: 'Revisión', vence: masDias(hoy(), 20)));
    store.guardarVencimiento(Vencimiento(id: 'v3', equipoId: 'e1', nombre: 'Certificado', vence: masDias(hoy(), 200)));
    store.guardarTarea(
      Tarea(id: 't1', clienteId: 'c1', nombre: 'Revisión ascensor', tipo: 'Ascensor', equipoId: 'e1', proximo: hoy()),
    );
  });

  test('avisa de lo vencido y de lo que entra en plazo, lo más urgente primero', () {
    expect(store.vencimientosPorAvisar.map((v) => v.id), ['v1', 'v2']);
  });

  test('se guarda y se recarga en local', () async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await store.cargar();
    expect(store.equipo('e1')!.marca, 'Orona');
    expect(store.vencimientosDe('e1').length, 3);
    expect(store.tarea('t1')!.equipoId, 'e1');
  });

  test('borrar el equipo quita sus vencimientos y deja el trabajo sin equipo', () {
    store.borrarEquipo('e1');
    expect(store.equipos, isEmpty);
    expect(store.vencimientos, isEmpty);
    expect(store.tarea('t1')!.equipoId, isNull);
  });

  test('borrar el cliente quita sus equipos y vencimientos', () {
    store.borrarCliente('c1');
    expect(store.equipos, isEmpty);
    expect(store.vencimientos, isEmpty);
  });

  Future<void> abrirFicha(WidgetTester tester, double ancho) async {
    tester.view.physicalSize = Size(ancho, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // En la app, el shell reconstruye la vista con cada cambio del store.
          body: ListenableBuilder(
            listenable: store,
            builder: (_, _) => ClienteDetalle(clienteId: 'c1', onVolver: () {}),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Equipos'));
    await tester.pumpAndSettle();
  }

  for (final ancho in [1440.0, 700.0]) {
    testWidgets('pestaña Equipos y ficha del equipo a ${ancho.round()} px', (tester) async {
      await abrirFicha(tester, ancho);
      expect(find.text('Ascensor 1'), findsOneWidget);
      expect(find.textContaining('OCA'), findsOneWidget, reason: 'el vencimiento más urgente');

      await tester.tap(find.text('Ascensor 1'));
      await tester.pumpAndSettle();
      expect(find.text('Editar equipo'), findsOneWidget);
      expect(find.text('Vencimientos legales'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('crear un equipo con su vencimiento', (tester) async {
    await abrirFicha(tester, 1440);
    await tester.tap(find.text('Nuevo equipo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Caldera sótano');
    await tester.tap(find.text('Añadir vencimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Inspección OCA'), 'Inspección RITE');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final nuevo = store.equiposDe('c1').firstWhere((e) => e.nombre == 'Caldera sótano');
    expect(store.vencimientosDe(nuevo.id).single.nombre, 'Inspección RITE');
    expect(find.text('Caldera sótano'), findsOneWidget);
  });

  testWidgets('sin nombre no se guarda', (tester) async {
    await abrirFicha(tester, 1440);
    await tester.tap(find.text('Nuevo equipo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ponle un nombre'), findsOneWidget);
    expect(store.equiposDe('c1').length, 1);
  });

  testWidgets('Inicio avisa de los vencimientos legales', (tester) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Resumen(onIr: (_) {}, onTrabajador: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 vencimientos legales por renovar'), findsOneWidget);
  });
}
