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
  });

  Future<void> abrir(WidgetTester tester, {DateTime? dia, int? hora}) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => abrirTareaForm(context, null, fecha: dia, horaMin: hora),
              child: const Text('Abrir trabajo'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir trabajo'));
    await tester.pumpAndSettle();
  }

  testWidgets('nombre y horario obligatorios impiden guardar el trabajo vacío', (tester) async {
    await abrir(tester);
    expect(find.text('Única'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ponle un nombre'), findsOneWidget);
    expect(find.text('El horario es obligatorio'), findsOneWidget);
    expect(store.tareas.where((t) => !t.esPlantilla), isEmpty);
  });

  testWidgets('elegir hora permite guardar hoy sin cliente ni trabajador', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField).first, 'Revisión puntual');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El horario es obligatorio'), findsOneWidget);
    await tester.ensureVisible(find.text('Elegir hora'));
    await tester.tap(find.text('Elegir hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('El horario es obligatorio'), findsNothing);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final trabajo = store.tareas.singleWhere((t) => !t.esPlantilla);
    expect(trabajo.nombre, 'Revisión puntual');
    expect(trabajo.clienteId, isNull);
    expect(trabajo.trabajadorIds, isEmpty);
    expect(trabajo.proximo, hoy());
    expect(trabajo.periodicidad, Periodicidad.unica);
    expect(trabajo.inicioMin, 9 * 60);
  });

  testWidgets('activar franja sin elegir horario tampoco permite guardar', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField).first, 'Revisión con franja');
    await tester.ensureVisible(find.text('Franja horaria'));
    await tester.tap(find.text('Franja horaria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El horario es obligatorio'), findsOneWidget);
    expect(store.tareas.where((t) => !t.esPlantilla), isEmpty);
  });

  testWidgets('conserva fecha y hora de agenda al aplicar plantilla', (tester) async {
    final dia = masDias(hoy(), 3);
    await abrir(tester, dia: dia, hora: 10 * 60);
    await tester.tap(find.text('Mantenimiento de ascensor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final trabajo = store.tareas.singleWhere((t) => !t.esPlantilla);
    expect(trabajo.proximo, dia);
    expect(trabajo.inicioMin, 10 * 60);
    expect(trabajo.periodicidad, Periodicidad.mensual);
  });
}
