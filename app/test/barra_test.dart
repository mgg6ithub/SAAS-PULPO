// ignore_for_file: prefer_const_constructors
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/ajustes.dart';
import 'package:pulpo/shell.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ajustes.cargar();
    await store.cargar();
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: ajustes,
          builder: (_, _) => Shell(key: UniqueKey()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('contraída solo muestra iconos y al pasar el ratón sale el nombre', (tester) async {
    ajustes.ponerAnchoBarra(Ajustes.anchoIconos);
    await montar(tester);
    // Contraída, en la barra no hay texto.
    expect(find.text('Itinerario'), findsNothing);

    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.addPointer(location: Offset.zero);
    addTearDown(raton.removePointer);
    await raton.moveTo(tester.getCenter(find.byIcon(Icons.calendar_month_outlined)));
    await tester.pumpAndSettle();
    expect(find.text('Itinerario'), findsOneWidget); // la pestañita
  });

  testWidgets('el botón de arriba contrae y vuelve al ancho anterior', (tester) async {
    ajustes.ponerAnchoBarra(400);
    await montar(tester);
    expect(find.text('Itinerario'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left_rounded));
    await tester.pumpAndSettle();
    expect(ajustes.barraContraida, isTrue);
    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right_rounded));
    await tester.pumpAndSettle();
    expect(ajustes.anchoBarra, 400);
  });

  test('por debajo del mínimo con textos se queda en solo iconos', () {
    // Entre solo iconos y el mínimo con textos se queda en lo más cercano.
    ajustes.ponerAnchoBarra(100);
    expect(ajustes.anchoBarra, Ajustes.anchoIconos);
    ajustes.ponerAnchoBarra(150);
    expect(ajustes.anchoBarra, Ajustes.anchoTextos);
  });
}
