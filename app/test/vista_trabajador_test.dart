import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/vista_trabajador.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.guardarCliente(
      Cliente(id: 'c1', nombre: 'Comunidad Calle Mayor 12', telefono: '600 111 222', direccion: 'Calle Mayor 12'),
    );
    store.guardarTrabajador(Trabajador(id: 'w1', nombre: 'Javier', apellidos: 'Martínez'));
    for (final (i, h) in [(1, 9 * 60), (2, 11 * 60), (3, null)]) {
      store.guardarTarea(
        Tarea(
          id: 't$i',
          clienteId: 'c1',
          nombre: 'Revisión del ascensor del portal $i',
          tipo: 'Ascensor',
          trabajadorIds: ['w1'],
          proximo: hoy(),
          inicioMin: h,
        ),
      );
    }
    rolTrabajador.value = 'w1';
  });

  Future<void> pintar(WidgetTester tester, double ancho) async {
    tester.view.physicalSize = Size(ancho, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ShellTrabajador()));
    await tester.pumpAndSettle();
  }

  for (final ancho in [1440.0, 700.0, 420.0, 360.0]) {
    testWidgets('la vista del trabajador cabe a $ancho px en Hoy, Semana y Pendientes', (tester) async {
      await pintar(tester, ancho);
      expect(find.text('SIGUIENTE'), findsOneWidget);
      expect(find.text('Llamar'), findsWidgets);
      expect(tester.takeException(), isNull);
      for (final p in ['Semana', 'Pendientes']) {
        await tester.tap(find.text(p).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: p);
      }
    });
  }

  testWidgets('marcar hecho con un toque pasa al siguiente trabajo', (tester) async {
    await pintar(tester, 420);
    expect(find.text('Revisión del ascensor del portal 1'), findsWidgets);
    await tester.tap(find.text('Hecho'));
    await tester.pumpAndSettle();
    expect(store.tareas.firstWhere((t) => t.id == 't1').hechaEl(hoy()), isTrue);
    expect(find.text('1 de 3'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Quitar hecho').first);
    await tester.tap(find.byTooltip('Quitar hecho').first);
    await tester.pumpAndSettle();
    expect(store.tareas.firstWhere((t) => t.id == 't1').hechaEl(hoy()), isFalse);
  });
}
