import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/cliente_detalle.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La ficha de cliente enseña todas las visitas de todos sus equipos, no solo la última.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio Arana'));
    final d = hoy();
    store.guardarTarea(
      Tarea(
        id: 't1',
        clienteId: 'c1',
        nombre: 'Caldera',
        tipo: 'Caldera',
        historial: [masDias(d, -60), masDias(d, -30)],
      ),
    );
    store.guardarTarea(
      Tarea(id: 't2', clienteId: 'c1', nombre: 'Ascensor', tipo: 'Ascensor', historial: [masDias(d, -10)]),
    );
  });

  for (final ancho in [1440.0, 700.0]) {
    testWidgets('historial completo del cliente a ${ancho.round()} px', (tester) async {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClienteDetalle(clienteId: 'c1', onVolver: () {}),
          ),
        ),
      );
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('Historial de mantenimientos'), findsOneWidget);
      expect(find.text('3 visitas'), findsOneWidget);
      // La más reciente arriba.
      final caldera = tester.getTopLeft(find.text('Caldera').first).dy;
      final ascensor = tester.getTopLeft(find.text('Ascensor').first).dy;
      expect(ascensor < caldera, isTrue);
    });
  }
}
