import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/screens/acceso.dart';
import 'package:pultec/screens/cuenta.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pintar(WidgetTester tester, {Size tamano = const Size(1440, 1000)}) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PantallaAcceso()));
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('una pantalla para entrar o crear cuenta, con Google en las dos', (tester) async {
    await pintar(tester);
    expect(find.text('Entra en Pulcón'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('¿Has olvidado la contraseña?'), findsOneWidget);
    await tester.tap(find.text('Crea una'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('¿Has olvidado la contraseña?'), findsNothing);
    await tester.tap(find.text('Entra'));
    await tester.pumpAndSettle();
    expect(find.text('Entra en Pulcón'), findsOneWidget);
  });

  testWidgets('errores en castellano y diciendo qué hacer, sin llamar a la nube', (tester) async {
    await pintar(tester);
    await tester.enterText(find.byType(TextField).first, 'pepe@');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Revisa el correo: falta algo (como nombre@empresa.com).'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'pepe@altura.com');
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('La contraseña necesita al menos 6 caracteres.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('¿Has olvidado la contraseña?'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe arriba tu correo y vuelve a pulsar.'), findsOneWidget);
  });

  testWidgets('ver u ocultar la contraseña y recordar el correo', (tester) async {
    SharedPreferences.setMockInitialValues({'pulpo_correo': 'pepe@altura.com'});
    await pintar(tester);
    expect(find.text('pepe@altura.com'), findsOneWidget);
    TextField clave() => tester.widget<TextField>(find.byType(TextField).last);
    expect(clave().obscureText, isTrue);
    await tester.tap(find.byTooltip('Ver contraseña'));
    await tester.pumpAndSettle();
    expect(clave().obscureText, isFalse);
  });

  testWidgets('cabe en un móvil de 360 px', (tester) async {
    await pintar(tester, tamano: const Size(360, 700));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Crea una'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('primer arranque: pide el nombre de la empresa y, con Google, explica que se ha creado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Es una pantalla propia (sale en lugar de la app). Sin nombre ya se puede empezar («Tu empresa»), y sus dos
    // botones guardan en la base: aquí solo se comprueba lo que enseña.
    await tester.pumpWidget(MaterialApp(home: PantallaNombrarEmpresa(porGoogle: true, onListo: () {})));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo se llama tu empresa?'), findsOneWidget);
    expect(find.textContaining('Hemos creado una empresa nueva'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);
    expect(find.text('Ahora no'), findsOneWidget);
  });
}
