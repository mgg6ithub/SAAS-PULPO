import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/store.dart';

void main() {
  testWidgets('solo muestra raíces y permite elegir descendientes o el padre', (tester) async {
    store.activos = [
      Activo(id: 'a', nombre: 'Camión'),
      Activo(id: 'b', padreId: 'a', nombre: 'Bomba'),
      Activo(id: 'c', padreId: 'b', nombre: 'Válvula'),
    ];
    String? elegido;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 320, child: SelectorActivo(null, (id) => elegido = id)),
    ))));
    await tester.tap(find.text('Elegir activo'));
    await tester.pumpAndSettle();
    expect(find.text('Camión'), findsOneWidget);
    expect(find.text('Bomba'), findsNothing);
    await tester.tap(find.text('Camión'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionar Camión'), findsOneWidget);
    expect(find.text('Bomba'), findsOneWidget);
    expect(find.text('Válvula'), findsNothing);
    await tester.tap(find.text('Bomba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Válvula'));
    await tester.pumpAndSettle();
    expect(elegido, 'c');
    expect(find.text('Válvula'), findsNothing);
    await tester.tap(find.text('Elegir activo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar Camión'));
    await tester.pumpAndSettle();
    expect(elegido, 'a');
    expect(tester.takeException(), isNull);
  });
}
