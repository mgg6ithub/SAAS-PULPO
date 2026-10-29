import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/screens/acceso.dart';

void main() {
  Future<void> pintar(WidgetTester tester, {Size tamano = const Size(1440, 1000)}) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PantallaAcceso()));
    await tester.pumpAndSettle();
  }

  testWidgets('Google se ofrece al entrar y al crear cuenta', (tester) async {
    await pintar(tester);
    expect(find.text('Continuar con Google'), findsOneWidget);
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar con Google'), findsOneWidget);
  });
}
