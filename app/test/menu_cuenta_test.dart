import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/main.dart';
import 'package:pulpo/screens/mi_cuenta.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abajo de la barra, un solo botón de usuario (sin «Ajustes» y «Mi cuenta» sueltos); sin sesión abre los Ajustes.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemo();
  });

  testWidgets('el botón de usuario abre los Ajustes en el modo de pruebas', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PulpoApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BotonUsuario), findsOneWidget);
    expect(find.text('Mi cuenta'), findsNothing);
    await tester.tap(find.text('Modo de pruebas'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('CONFIGURACIÓN'), findsOneWidget);
    expect(find.text('Cuenta'), findsNothing, reason: 'sin sesión no hay cuenta');
  });
}
