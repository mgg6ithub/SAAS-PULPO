import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    expect(find.text('Pon una hora'), findsOneWidget);
    expect(store.tareas.where((t) => !t.esPlantilla), isEmpty);
    // Abajo, el primero que falta; al escribir el nombre, su aviso se va solo.
    expect(find.text('Te falta el nombre'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Revisión');
    await tester.pump();
    expect(find.text('Ponle un nombre'), findsNothing);
    expect(find.text('Te falta la hora'), findsOneWidget);
  });

  testWidgets('al guardar sin hora se desplaza hasta el campo de la hora', (tester) async {
    tester.view.physicalSize = const Size(1440, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => abrirTareaForm(context, null), child: const Text('Abrir trabajo')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir trabajo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Revisión puntual');
    final hora = find.text('Elegir hora');
    final antes = tester.getTopLeft(hora).dy;
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final despues = tester.getTopLeft(hora).dy;
    expect(despues, lessThan(antes));
    expect(despues, lessThan(600));
  });

  testWidgets('el menú de criticidad se maneja con las flechas', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Rutinaria'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Rutinaria'), findsNothing);
  });

  testWidgets('elegir hora permite guardar hoy sin cliente ni trabajador', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField).first, 'Revisión puntual');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Pon una hora'), findsOneWidget);
    await tester.ensureVisible(find.text('Elegir hora'));
    await tester.tap(find.text('Elegir hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Pon una hora'), findsNothing);
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
    expect(find.text('Pon una hora'), findsOneWidget);
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
