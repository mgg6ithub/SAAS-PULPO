import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/screens/ajustes_dialogo.dart';
import 'package:pulpo/screens/simulaciones.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes y Simulaciones se abren sin desbordes en móvil.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemo();
  });

  final dialogos = <String, Future<void> Function(BuildContext)>{
    'Ajustes': abrirAjustes,
    'Simulaciones': abrirSimulaciones,
  };

  for (final ancho in [700.0, 420.0, 360.0]) {
    for (final e in dialogos.entries) {
      testWidgets('${e.key} se abre a ${ancho.round()} px', (tester) async {
        tester.view.physicalSize = Size(ancho, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(onPressed: () => e.value(context), child: const Text('abrir')),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
      });
    }
  }
}
