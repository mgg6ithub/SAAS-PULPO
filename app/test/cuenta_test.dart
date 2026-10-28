import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/screens/cuenta.dart';

void main() {
  Future<void> pintar(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
    await tester.pumpAndSettle();
  }

  testWidgets('nueva empresa: sin nombre no se guarda y avisa en el campo y abajo', (tester) async {
    await pintar(tester, const EmpresaForm(nueva: true));
    expect(find.text('Nueva empresa'), findsOneWidget);
    expect(find.text('Varios'), findsOneWidget); // tipo por defecto: todas las plantillas
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ponle un nombre'), findsOneWidget);
    expect(find.text('Te falta el nombre'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Ascensores Altura');
    await tester.pumpAndSettle();
    expect(find.text('Ponle un nombre'), findsNothing);
    expect(find.text('Te falta el nombre'), findsNothing);
  });

  testWidgets('borrar solo se acepta escribiendo la palabra', (tester) async {
    bool? r;
    await pintar(
      tester,
      Builder(
        builder: (c) => TextButton(
          onPressed: () async =>
              r = await confirmarEscribiendo(c, titulo: 'Borrar Altura', texto: 'Se borra todo.', palabra: 'Altura'),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final borrar = find.widgetWithText(FilledButton, 'Borrar');
    expect(tester.widget<FilledButton>(borrar).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Altur');
    await tester.pump();
    expect(tester.widget<FilledButton>(borrar).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Altura');
    await tester.pump();
    await tester.tap(borrar);
    await tester.pumpAndSettle();
    expect(r, isTrue);
  });

  testWidgets('cambiar contraseña pide 6 caracteres y que coincidan', (tester) async {
    await pintar(
      tester,
      Builder(
        builder: (c) => TextButton(onPressed: () => cambiarClave(c), child: const Text('abrir')),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Al menos 6 caracteres.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '1234567');
    await tester.enterText(find.byType(TextField).last, '7654321');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Las dos no coinciden.'), findsOneWidget);
  });
}
