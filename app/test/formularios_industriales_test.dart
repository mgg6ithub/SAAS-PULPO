import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/forms.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/activos.dart';
import 'package:pulpo/marca.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/tabla_trabajos.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Formularios industriales', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await store.cargar();
      store.nube = null;
      store.clientes = [];
      store.activos = [
        Activo(id: 'camion', tag: 'CAM-01', nombre: 'Camión'),
        Activo(id: 'motor', padreId: 'camion', nombre: 'Motor'),
      ];
      store.trabajadores = [];
      store.tareas = [
        Tarea(
          id: 'ot',
          nombre: 'Revisión del motor',
          plantilla: false,
          proximo: hoy(),
          inicioMin: 720,
          periodicidad: Periodicidad.unica,
        ),
      ];
    });

    Finder campo(String label) => find
        .descendant(
          of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
          matching: find.byType(TextField),
        )
        .first;

    Future<void> escribir(WidgetTester tester, String label, String valor) async {
      final f = campo(label);
      await tester.ensureVisible(f);
      await tester.enterText(f, valor);
      await tester.pump();
    }

    for (final ancho in [1440.0, 980.0, 700.0, 600.0, 420.0, 360.0]) {
      testWidgets('crear activo, OT y técnico sin campos residenciales ni overflow a $ancho', (tester) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final form in <Widget>[
          const ActivoForm(),
          TareaForm(original: store.tareas.single),
          const TrabajadorForm(),
        ]) {
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: form)));
          await tester.pumpAndSettle();
          expect(find.text('Calderas (RITE)'), findsNothing);
          expect(find.text('Piscinas'), findsNothing);
          expect(find.text('Precio'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('asigna un activo y un componente desde la tabla sin clientes', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: store,
              builder: (_, _) => TablaTrabajos(store.tareas, onAbrir: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectorCliente), findsNothing);
      await tester.tap(find.byType(SelectorActivo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAM-01 · Camión').last);
      await tester.pumpAndSettle();
      expect(store.tarea('ot')!.activoId, 'camion');
      await tester.tap(find.byType(SelectorActivo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Motor').last);
      await tester.pumpAndSettle();
      expect(store.tarea('ot')!.activoId, 'motor');
    });

    testWidgets('el formulario de OT guarda el activo y elimina restricciones residenciales ocultas', (tester) async {
      store.tareas.single.competencias = ['Piscinas'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => abrirTareaForm(context, store.tareas.single),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectorCliente), findsNothing);
      expect(find.text('Competencias'), findsNothing);
      expect(find.text('Se repite'), findsNothing);
      final selector = find.byType(SelectorActivo);
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAM-01 · Camión').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();
      expect(store.tarea('ot')!.activoId, 'camion');
      expect(store.tarea('ot')!.competencias, isEmpty);
      expect(store.tarea('ot')!.periodicidad, Periodicidad.unica);
    });

    testWidgets('crea un activo con 5000 horas y 7 horas al día, guardando la previsión', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(onPressed: () => abrirActivoForm(context), child: const Text('Abrir')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await escribir(tester, 'Tag', 'CAM-02');
      await escribir(tester, 'Nombre', 'Camión de prueba');
      final modo = find.byTooltip('Cómo se programa el mantenimiento');
      await tester.ensureVisible(modo);
      await tester.tap(modo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Horas de uso'));
      await tester.pumpAndSettle();
      await escribir(tester, 'Cada cuántas horas', '5.000');
      await escribir(tester, 'Horas de uso por día', '7');
      expect(find.textContaining('Fecha estimada:'), findsOneWidget);
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();
      final a = store.activos.singleWhere((a) => a.tag == 'CAM-02');
      expect(a.cadaHoras, 5000);
      expect(a.horasUso, 7);
      expect(a.proximoMantenimiento, DateTime(hoy().year, hoy().month, hoy().day + 715));
      expect(a.copia().proximoMantenimiento, a.proximoMantenimiento);
    });

    test('el catálogo industrial no contiene especialidades residenciales', () {
      expect(competenciasParaMarca(competenciasResidenciales), containsAll(['Mecánica', 'Hidráulica', 'Neumática']));
      expect(competenciasParaMarca(competenciasResidenciales), isNot(contains('Piscinas')));
      expect(competenciasParaMarca(competenciasResidenciales), isNot(contains('Calderas (RITE)')));
    });
  }, skip: !industrial);
}
