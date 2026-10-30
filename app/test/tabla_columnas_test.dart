import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/theme.dart';
import 'package:pulpo/widgets.dart';

void main() {
  testWidgets('la columna arrastrada muestra fondo y guías hasta abajo y los retira al soltar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Tabla(
            columnas: const [Col('Tarea'), Col('Cliente'), Col('Periodicidad'), Col('Estado')],
            filas: 20,
            celdas: (i) => [Text('Tarea $i'), Text('Cliente $i'), const Text('Mensual'), const Text('Pendiente')],
          ),
        ),
      ),
    );
    final asas = find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn);
    final guias = find.descendant(of: find.byType(Tabla), matching: find.byType(CustomPaint)).first;
    expect(tester.widget<CustomPaint>(guias).foregroundPainter, isNull);
    final comienzoTarea = tester.getTopLeft(find.text('Tarea')).dx;
    final comienzoPeriodicidad = tester.getTopLeft(find.text('Periodicidad')).dx;
    final comienzoEstado = tester.getTopLeft(find.text('Estado')).dx;
    final limiteDerechoCliente = tester.getCenter(asas.at(1)).dx;
    final tooltip = find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Arrastrar para intercambiar Cliente');
    final gesto = await tester.startGesture(tester.getCenter(asas.first));
    await gesto.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(tester.state<TooltipState>(tooltip).ensureTooltipVisible(), isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Arrastrar para intercambiar Cliente'), findsNothing);
    for (final dx in [40.0, -80.0, 10000.0, -10000.0]) {
      await gesto.moveBy(Offset(dx, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.text('Tarea')).dx, closeTo(comienzoTarea, .01));
      expect(tester.getTopLeft(find.text('Periodicidad')).dx, closeTo(comienzoPeriodicidad, .01));
      expect(tester.getTopLeft(find.text('Estado')).dx, closeTo(comienzoEstado, .01));
      final origen = tester.getTopLeft(guias);
      final izquierda = tester.getCenter(asas.first).dx - origen.dx;
      final derecha = limiteDerechoCliente - origen.dx;
      expect(
        (Canvas canvas) => tester.widget<CustomPaint>(guias).foregroundPainter!.paint(canvas, tester.getSize(guias)),
        paints
          ..rect(
            rect: Rect.fromLTRB(izquierda, 0, derecha, tester.getSize(guias).height),
            color: P.morado.withValues(alpha: .07),
          )
          ..line(color: P.morado.withValues(alpha: .65)),
      );
    }
    await gesto.up();
    await tester.pump();
    expect(tester.widget<CustomPaint>(guias).foregroundPainter, isNull);
    expect(tester.state<TooltipState>(tooltip).ensureTooltipVisible(), isTrue);
    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('intercambiar columnas mueve títulos y datos juntos y permite redimensionar después', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Tabla(
            columnas: const [Col('Nombre'), Col('Competencias'), Col('Teléfono'), Col('Estado')],
            filas: 1,
            celdas: (_) => const [Text('Ana'), Text('Electricidad'), Text('600123456'), Text('Disponible')],
          ),
        ),
      ),
    );
    final inicioCompetencias = tester.getTopLeft(find.text('Competencias')).dx;
    final inicioTelefono = tester.getTopLeft(find.text('Teléfono')).dx;
    final inicioNombre = tester.getTopLeft(find.text('Nombre')).dx;
    final desde = tester.getCenter(find.text('Competencias'));
    final hasta = tester.getCenter(find.text('Teléfono'));
    final gesto = await tester.startGesture(desde);
    await gesto.moveBy(const Offset(25, 0));
    await tester.pump();
    await gesto.moveTo(hasta);
    await tester.pump();
    await gesto.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Teléfono')).dx, closeTo(inicioCompetencias, .01));
    expect(tester.getTopLeft(find.text('Competencias')).dx, closeTo(inicioTelefono, .01));
    expect(tester.getTopLeft(find.text('600123456')).dx, closeTo(inicioCompetencias, .01));
    expect(tester.getTopLeft(find.text('Electricidad')).dx, closeTo(inicioTelefono, .01));
    expect(tester.getTopLeft(find.text('Nombre')).dx, closeTo(inicioNombre, .01));
    final asas = find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn);
    await tester.drag(asas.first, const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('600123456')).dx, closeTo(tester.getTopLeft(find.text('Teléfono')).dx, .01));
    expect(tester.takeException(), isNull);
  });
}
