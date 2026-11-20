import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/iconos.dart';
import 'package:pulpo/store.dart';

/// Flecha de la derecha que abre los componentes de [nombre] (pulsar el nombre elige el activo).
Finder flechaDe(String nombre) =>
    find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('Componentes de') &&
        (w.message ?? '').contains(nombre));

void main() {
  testWidgets('muestra solo hijos en submenús compactos y permite elegir una hoja', (tester) async {
    store.activos = [
      Activo(id: 'a', nombre: 'Camión'),
      Activo(id: 'b', padreId: 'a', nombre: 'Bomba'),
      Activo(id: 'c', padreId: 'b', nombre: 'Válvula'),
    ];
    String? elegido;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: SelectorActivo(null, (id) => elegido = id))),
        ),
      ),
    );
    await tester.tap(find.text('Elegir activo'));
    await tester.pumpAndSettle();
    expect(find.text('Camión'), findsOneWidget);
    expect(find.text('Bomba'), findsNothing);
    await tester.tap(flechaDe('Camión'));
    await tester.pumpAndSettle();
    expect(find.text('Bomba'), findsOneWidget);
    expect(find.text('Válvula'), findsNothing);
    await tester.tap(flechaDe('Bomba'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Válvula')).leadingIcon,
      isA<IconoActivo>(),
    );
    await tester.tap(find.text('Válvula'));
    await tester.pumpAndSettle();
    expect(elegido, 'c');
    expect(find.text('Válvula'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtro abre hacia la izquierda y permite elegir la rama completa', (tester) async {
    store.activos = [Activo(id: 'a', nombre: 'Camión'), Activo(id: 'b', padreId: 'a', nombre: 'Bomba')];
    String? elegido;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: 260, child: SelectorActivo(null, (id) => elegido = id, filtro: true)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Activos'));
    await tester.pumpAndSettle();
    // Pulsar el activo lo elige entero, con sus componentes (la flecha solo los enseña).
    expect(flechaDe('Camión'), findsOneWidget);
    await tester.tap(find.text('Camión'));
    await tester.pumpAndSettle();
    expect(elegido, 'a');
    expect(tester.takeException(), isNull);
  });
}
