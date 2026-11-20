import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/forms.dart';
import 'package:pultec/main.dart';
import 'package:pultec/shell.dart';
import 'package:pultec/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un aviso lanzado desde una ventana emergente sale encima de su fondo oscuro, no debajo.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemo();
  });

  testWidgets('el aviso de una ventana se ve y se puede tocar', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PultecApp());
    await tester.pump(const Duration(seconds: 1));

    abrirPanel(
      tester.element(find.byType(Shell)),
      Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('aviso de prueba'))),
            child: const Text('avisar'),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('avisar'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('aviso de prueba').hitTestable(), findsOneWidget);
  });
}
