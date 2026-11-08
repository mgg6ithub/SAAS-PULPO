import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/incidencia.dart';
import 'package:pulpo/industrial/incidencia_form.dart';
import 'package:pulpo/informes.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/vista_trabajador.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.activos = [Activo(id: 'a', nombre: 'Camión')];
    store.trabajadores = [Trabajador(id: 'w-panel', nombre: 'Juan')];
    rolTrabajador.value = 'w-panel';
    store.incidencias = [];
    store.tareas = [
      for (final (i, tipo) in TipoMantenimiento.values.indexed)
        Tarea(
          id: 'ot$i',
          nombre: 'Orden $i',
          activoId: 'a',
          plantilla: false,
          trabajadorIds: ['w-panel'],
          tipoMantenimiento: tipo,
          proximo: masDias(hoy(), i),
        ),
    ];
  });
  tearDown(() => rolTrabajador.value = null);

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1300, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ShellTrabajador()));
    await tester.pumpAndSettle();
  }

  testWidgets('pendientes es una lista sin desplegable y filtra por tipo', (tester) async {
    await montar(tester);
    expect(find.text('Orden 2'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tipo de intervención'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Correctivo crítico'));
    await tester.pumpAndSettle();
    expect(find.text('Orden 2'), findsOneWidget);
    expect(find.text('Orden 0'), findsNothing);
    expect(find.text('Orden 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incidencias muestra solo las del técnico con origen y fecha', (tester) async {
    store.incidencias = [
      Incidencia(
        id: 'propia',
        activoId: 'a',
        tecnicoId: 'w-panel',
        origenTrabajoId: 'ot1',
        descripcion: 'Fuga detectada',
      ),
      Incidencia(id: 'ajena', activoId: 'a', tecnicoId: 'otro', descripcion: 'Aviso de otro técnico'),
    ];
    await montar(tester);
    await tester.tap(find.text('Incidencias · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Fuga detectada'), findsOneWidget);
    expect(find.text('Aviso de otro técnico'), findsNothing);
    expect(find.text('Orden de origen: Orden 1'), findsOneWidget);
    await tester.tap(find.text('Fuga detectada'));
    await tester.pumpAndSettle();
    expect(find.text('Incidencia enviada'), findsOneWidget);
    expect(find.textContaining('Enviada el'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el historial usa partes propios y permite filtrar no realizadas', (tester) async {
    for (var i = 0; i < 3; i++) {
      await informes.crear(Informe(trabajoId: 'ot$i', trabajadorId: 'w-panel', resultado: i, notas: 'Prueba'));
    }
    await informes.crear(Informe(trabajoId: 'ot0', trabajadorId: 'otro', resultado: 2, notas: 'Ajeno'));
    await montar(tester);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Orden 0'), findsOneWidget);
    expect(find.textContaining('No se pudo hacer'), findsOneWidget);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resultado del parte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No se pudo hacer').last);
    await tester.pumpAndSettle();
    expect(find.text('Orden 2'), findsOneWidget);
    expect(find.text('Orden 0'), findsNothing);
    expect(find.text('Orden 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comunicar desde una orden conserva autor y origen al guardar', (tester) async {
    tester.view.physicalSize = const Size(1400, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: AvisoIncidenciaForm(tecnicoId: 'w-panel', origenTrabajoId: 'ot1'),
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(tester.widget<SelectorActivo>(find.byType(SelectorActivo)).valor, 'a');
    await tester.enterText(find.byType(TextField), 'Fuga');
    tester.widget<VentanaFormulario>(find.byType(VentanaFormulario)).onGuardar();
    await tester.pumpAndSettle();
    final guardada = Incidencia.fromJson(store.incidencias.single.toJson());
    expect(guardada.tecnicoId, 'w-panel');
    expect(guardada.origenTrabajoId, 'ot1');
    expect(guardada.trabajoId, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final width in [1000.0, 700.0, 420.0, 360.0]) {
    testWidgets('panel sin desbordamientos a $width px', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ShellTrabajador()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
