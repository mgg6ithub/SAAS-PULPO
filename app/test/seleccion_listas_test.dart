import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/screens/clientes.dart';
import 'package:pulpo/screens/trabajadores.dart';
import 'package:pulpo/screens/tareas.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemo();
  });

  for (final nombre in ['Clientes', 'Trabajadores', 'Tareas']) {
    testWidgets('$nombre solo reserva espacio para casillas durante la selección', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final Widget pantalla = switch (nombre) {
        'Clientes' => Clientes(onAbrir: (_) {}),
        'Trabajadores' => Trabajadores(onAbrir: (_) {}),
        _ => const TareasPagina(),
      };
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: pantalla)));
      await tester.pumpAndSettle();
      final marca = nombre == 'Tareas' ? find.byType(BarraTipo).first : find.byType(Avatar).first;
      final izquierda = tester.getTopLeft(marca).dx;
      expect(find.byType(CirculoSeleccion), findsNothing);
      await tester.tap(find.byType(BotonSeleccionLista));
      await tester.pumpAndSettle();
      expect(find.byType(CirculoSeleccion), findsWidgets);
      final ejeSeleccion = tester.getCenter(find.byIcon(Icons.checklist_rounded)).dx;
      for (final casilla in find.byType(CirculoSeleccion).evaluate()) {
        expect(tester.getCenter(find.byWidget(casilla.widget)).dx, closeTo(ejeSeleccion, .01));
      }
      expect(tester.getCenter(find.byType(CirculoSeleccion).first).dy, closeTo(tester.getCenter(marca).dy, .01));
      final boton = find.descendant(of: find.byType(BotonSeleccionLista), matching: find.byType(IconButton));
      expect(tester.getSize(boton), const Size(32, 32));
      expect(tester.getTopLeft(marca).dx, closeTo(izquierda + 40, .01));
      await tester.tap(find.text('Seleccionar todo'));
      await tester.pumpAndSettle();
      final barra = tester.widget<BarraSeleccion>(find.byType(BarraSeleccion));
      expect(barra.seleccionados, barra.total);
      expect(barra.seleccionados, greaterThan(0));
      await tester.tap(find.byType(BotonSeleccionLista));
      await tester.pumpAndSettle();
      expect(find.byType(CirculoSeleccion), findsNothing);
      expect(find.byType(BarraSeleccion), findsNothing);
      expect(tester.getTopLeft(marca).dx, closeTo(izquierda, .01));
      expect(tester.takeException(), isNull);
    });
  }
}
