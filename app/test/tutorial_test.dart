import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/ajustes.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/screens/resumen.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ajustes.cargar();
    await store.cargar();
    store.vaciar();
  });

  test('completar el tutorial persiste aunque se vacíen los datos y se recargue', () async {
    ajustes.marcarGuiaOrganizar();
    store.vaciar();
    final recargados = Ajustes();
    await recargados.cargar();
    expect(recargados.guiaOrganizar, isTrue);
  });

  testWidgets('Inicio no vuelve a mostrar primeros pasos después de completarlos', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ajustes.marcarGuiaOrganizar();
    store.vaciar();
    await tester.pumpWidget(MaterialApp(theme: temaPulpo(), home: Scaffold(body: Resumen(onIr: (_) {}, onTrabajador: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.text('Primeros pasos'), findsNothing);
    expect(find.text('Tus activos'), findsNothing);
    expect(find.text('Tus clientes'), findsNothing);
    expect(find.text('Completa los primeros pasos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crear un técnico después de llegar a cero no reinicia el tutorial', (tester) async {
    ajustes.marcarGuiaOrganizar();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TrabajadorForm(
      incrustada: true, competencias: ['Electricidad'],
    ))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Nuevo técnico');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(store.trabajadores, hasLength(1));
    expect(ajustes.guiaOrganizar, isTrue);
    await ajustes.cargar();
    expect(ajustes.guiaOrganizar, isTrue);
    expect(tester.takeException(), isNull);
  });
}
