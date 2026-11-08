import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/incidencia.dart';
import 'package:pulpo/industrial/incidencia_form.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/vista_trabajador.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.activos = [
      Activo(id: 'a', nombre: 'Camión', icono: 'camion'),
      Activo(id: 'b', padreId: 'a', nombre: 'Motor'),
    ];
    store.trabajadores = [Trabajador(id: 'w', nombre: 'Juan')];
    store.tareas = [];
  });

  testWidgets('incidencia usa jerarquía y guarda el componente elegido', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvisoIncidenciaForm())));
    await tester.tap(find.text('Elegir activo'));
    await tester.pumpAndSettle();
    expect(find.text('Camión'), findsOneWidget);
    expect(find.text('Motor'), findsNothing);
    await tester.tap(find.text('Camión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motor'));
    await tester.pumpAndSettle();
    expect(tester.widget<SelectorActivo>(find.byType(SelectorActivo)).valor, 'b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('gravedad y categoría son compactas, alineadas y sin aura', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvisoIncidenciaForm())));
    final gravedad = find.byType(BotonMenu<Gravedad>);
    final categoria = find.byType(BotonMenu<String>);
    final descripcion = find.byType(TextField);
    expect(tester.getSize(gravedad).width, lessThan(tester.getSize(descripcion).width));
    expect(tester.getTopLeft(gravedad).dx, tester.getTopLeft(descripcion).dx);
    expect(tester.getTopLeft(categoria).dx, tester.getTopLeft(descripcion).dx);
    expect(tester.widget<BotonMenu<Gravedad>>(gravedad).resaltarHover, isFalse);
    expect(tester.widget<BotonMenu<String>>(categoria).resaltarHover, isFalse);
    expect(find.byIcon(Icons.unfold_more_rounded), findsNWidgets(3));
    await tester.tap(gravedad);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('Correctivo crítico')).style!.color, Gravedad.grave.color);
    await tester.tap(find.text('Correctivo crítico'));
    await tester.pumpAndSettle();
    await tester.tap(categoria);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    expect(find.byIcon(Icons.air_rounded), findsOneWidget);
    await tester.tap(find.text('Mecánica'));
    await tester.pumpAndSettle();
    expect(find.text('Mecánica'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [1000.0, 700.0, 420.0, 360.0]) {
    testWidgets('formulario sin desbordamiento a $width px', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvisoIncidenciaForm())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cerrar sesión está disponible también desde la vista previa', (tester) async {
    rolTrabajador.value = 'w';
    addTearDown(() => rolTrabajador.value = null);
    await tester.pumpWidget(const MaterialApp(home: ShellTrabajador()));
    await tester.pumpAndSettle();
    final salir = find.widgetWithText(BotonAccion, 'Cerrar sesión');
    expect(salir, findsOneWidget);
    await tester.tap(salir);
    await tester.pumpAndSettle();
    expect(rolTrabajador.value, isNull);
    expect(tester.takeException(), isNull);
  });
}
