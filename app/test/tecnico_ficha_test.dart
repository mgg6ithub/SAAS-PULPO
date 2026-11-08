import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/screens/trabajador_detalle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ficha industrial consulta datos y permite editar explícitamente', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.trabajadores = [Trabajador(id: 'w', nombre: 'Juan', telefono: '123456789', email: 'juan@example.com')];
    store.tareas = [];
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TrabajadorDetalle(trabajadorId: 'w', onVolver: () {}))));
    await tester.pumpAndSettle();
    expect(find.byType(TrabajadorForm), findsNothing);
    expect(find.text('123456789'), findsOneWidget);
    expect(find.text('Hechas en 30 días'), findsOneWidget);
    expect(find.text('Pendientes · 0'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la OT existente no permite cambiar de activo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TareaForm(
      original: Tarea(id: 'ot', nombre: 'Revisión', plantilla: false,
        tipoMantenimiento: TipoMantenimiento.preventivo, activoId: 'a'),
    ))));
    await tester.pumpAndSettle();
    expect(find.byType(SelectorActivo), findsNothing);
    expect(find.byTooltip('El activo de una orden ya creada no se puede cambiar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
