import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/shell.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('N abre «Nuevo cliente», otra N lo cierra y escribiendo no actúa', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Shell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clientes').first);
    await tester.pumpAndSettle();
    final ventana = find.text('CLIENTES');

    // Tras escribir en el buscador y hacer clic fuera, la N vuelve a funcionar.
    await tester.tap(find.byType(TextField).first);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(ventana, findsNothing);
    await tester.tapAt(const Offset(800, 700));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(ventana, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(ventana, findsNothing);
  });
}
