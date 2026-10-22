import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';

void main() {
  testWidgets('acoplar conserva los campos y no los vuelve a maquetar en cada fotograma', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final texto = TextEditingController(text: 'Sin perder lo escrito');
    addTearDown(texto.dispose);
    var maquetaciones = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VentanaFormulario(
            titulo: 'Nueva tarea',
            etiqueta: 'Tarea',
            subtitulo: 'Cliente',
            campos: [
              LayoutBuilder(
                builder: (_, box) {
                  maquetaciones++;
                  return TextField(controller: texto);
                },
              ),
            ],
            onGuardar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final destino in [
      'Acoplar a la derecha',
      'Acoplar a la izquierda',
      'Acoplar al centro',
      'Acoplar a la derecha',
      'Acoplar al centro',
    ]) {
      final antes = maquetaciones;
      await tester.tap(find.byTooltip(destino));
      await tester.pump();
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final campo = tester.renderObject<RenderBox>(find.byType(TextField));
        final anchoVisible = campo.localToGlobal(Offset(campo.size.width, 0)).dx - campo.localToGlobal(Offset.zero).dx;
        expect(anchoVisible, closeTo(campo.size.width, .01));
      }
      expect(maquetaciones - antes, lessThanOrEqualTo(2));
      expect(texto.text, 'Sin perder lo escrito');
      expect(tester.takeException(), isNull);
      if (destino != 'Acoplar al centro') {
        expect(find.byIcon(CupertinoIcons.line_horizontal_3), findsOneWidget);
        final centro = tester.getCenter(find.byTooltip('Acoplar al centro')).dx;
        if (destino == 'Acoplar a la derecha') {
          expect(tester.getCenter(find.byTooltip('Acoplar a la izquierda')).dx, lessThan(centro));
        } else {
          expect(tester.getCenter(find.byTooltip('Acoplar a la derecha')).dx, greaterThan(centro));
        }
      }
    }
    final ventana = find.descendant(of: find.byType(VentanaFormulario), matching: find.byType(Material)).first;
    final cerrar = tester.getRect(find.byTooltip('Cerrar'));
    final marco = tester.getRect(ventana);
    expect(cerrar.top - marco.top, closeTo(4, .01));
    expect(marco.right - cerrar.right, closeTo(4, .01));
  });
}
