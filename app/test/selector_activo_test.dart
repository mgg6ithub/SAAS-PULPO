import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final filtro in [true, false]) {
    testWidgets('elige el activo padre y abre sus componentes (filtro: $filtro)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await store.cargar();
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store.activos = [
        Activo(id: 'a', tag: 'CAM-01', nombre: 'Camión'),
        Activo(id: 'c', padreId: 'a', tag: 'CAM-01-FRE', nombre: 'Frenos'),
      ];
      String? elegido;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topRight,
        child: SizedBox(width: 300, child: SelectorActivo(null, (v) => elegido = v, filtro: filtro))))));
      await tester.tap(find.text(filtro ? 'Activos' : 'Elegir activo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Camión'));
      await tester.pumpAndSettle();
      expect(elegido, 'a');
      await tester.tap(find.text(filtro ? 'Activos' : 'Elegir activo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SubmenuButton).first);
      await tester.pumpAndSettle();
      expect(find.text('Frenos'), findsOneWidget);
      await tester.tap(find.text('Frenos'));
      await tester.pumpAndSettle();
      expect(elegido, 'c');
      expect(tester.takeException(), isNull);
    });
  }
}
