import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/activos.dart';
import 'package:pulpo/industrial/plantillas.dart';
import 'package:pulpo/marca.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/screens/tarea_detalle.dart';
import 'package:pulpo/theme.dart';
import 'package:pulpo/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('el catálogo industrial adapta solo las plantillas de serie y conserva sus ids', () {
    final vieja = Tarea(id: 'uuid-existente', nombre: 'Revisión caldera de gas', tipo: 'Caldera', plantilla: true);
    final propia = Tarea(id: 'propia', nombre: 'Mi revisión', tipo: 'Robot', plantilla: true);
    final real = vieja.copia()..plantilla = false;
    final nuevas = adaptarPlantillasIndustriales([vieja, propia, real]);
    expect(nuevas.first.id, vieja.id);
    expect(nuevas.first.nombre, 'Camión');
    expect(vieja.nombre, 'Revisión caldera de gas');
    expect(nuevas[1], same(propia));
    expect(nuevas[2], same(real));
    if (industrial) {
      final lista = tiposParaMarca([
        ...tiposResidenciales,
        const TipoInfo('robot', 'Robot', 'otro', Colors.blue, null),
      ]);
      expect(lista.map((t) => t.nombre), containsAll(['Camión', 'Prensa', 'Agua a presión', 'Compresor', 'Robot']));
      expect(lista.any((t) => t.nombre == 'Caldera' || t.nombre == 'Jardinería'), isFalse);
    }
  });

  testWidgets('los buscadores mantienen una sola línea aunque el texto sea largo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Buscador(hint: 'Buscar una orden de trabajo con un texto muy largo', onChanged: (_) {}),
          ),
        ),
      ),
    );
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.maxLines, 1);
    expect(tester.getSize(find.byType(InputDecorator)).height, 40);
    expect(campo.decoration!.hintMaxLines, 1);
    await tester.enterText(find.byType(TextField), 'Un texto largo que debe seguir en una línea');
    expect(tester.takeException(), isNull);
  });

  group('Ficha industrial del activo', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await store.cargar();
      store.activos = [
        Activo(id: 'a1', tag: 'CAM-01', nombre: 'Camión'),
        Activo(id: 'a2', padreId: 'a1', nombre: 'Motor'),
        Activo(id: 'a3', nombre: 'Prensa ajena'),
      ];
      store.tareas = [
        Tarea(
          id: 'ot1',
          nombre: 'Servicio motor',
          activoId: 'a2',
          plantilla: false,
          tipoMantenimiento: TipoMantenimiento.preventivo,
          proximo: hoy(),
        ),
        Tarea(
          id: 'ot2',
          nombre: 'Cambio filtro',
          activoId: 'a2',
          plantilla: false,
          tipoMantenimiento: TipoMantenimiento.preventivo,
          estado: EstadoTrabajo.realizado,
          historial: [hoy()],
        ),
        Tarea(
          id: 'ot3',
          nombre: 'Servicio ajeno',
          activoId: 'a3',
          plantilla: false,
          tipoMantenimiento: TipoMantenimiento.preventivo,
          estado: EstadoTrabajo.realizado,
          historial: [hoy()],
        ),
      ];
    });

    Future<void> pintar(WidgetTester tester, double ancho) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivoDetalle(activoId: 'a1', onVolver: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final ancho in [1440.0, 980.0, 700.0, 600.0, 420.0, 360.0]) {
      testWidgets('tabla de activos compacta con pie y tipo a $ancho', (tester) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        filtroActivos.value = 0;
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Activos())));
        await tester.pumpAndSettle();
        expect(find.text('Tipo de mantenimiento'), findsOneWidget);
        final filtro = tester.widget<Pestanas>(find.byType(Pestanas));
        expect(filtro.colores, [null, for (final t in TipoMantenimiento.values) t.color]);
        expect(tester.getSize(find.byType(Tabla)).height, lessThan(400));
        expect(find.textContaining('2 activos'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('componentes, datos, OT e histórico sin desbordar a $ancho', (tester) async {
        await pintar(tester, ancho);
        expect(find.text('Motor'), findsOneWidget);
        expect(find.text('Plan de mantenimiento'), findsNothing);
        for (final tab in ['Datos', 'Órdenes de trabajo', 'Histórico']) {
          await tester.tap(find.text(tab).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: tab);
        }
        expect(find.text('Cambio filtro'), findsOneWidget);
        expect(find.text('Servicio ajeno'), findsNothing);
        expect(find.text('Todos los activos'), findsNothing);
      });
    }

    testWidgets('lista compacta y componentes anidados como subtrabajos', (tester) async {
      await pintar(tester, 1440);
      expect(find.byType(Tabla), findsOneWidget);
      store.activos.add(Activo(id: 'filtro', padreId: 'a2', nombre: 'Filtro de aceite'));
      await tester.tap(find.text('Motor'));
      await tester.pumpAndSettle();
      expect(find.text('Filtro de aceite'), findsOneWidget);
      await tester.tap(find.text('Filtro de aceite'));
      await tester.pumpAndSettle();
      expect(find.text('Componente de Motor'), findsOneWidget);
      expect(find.text('Nuevo componente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las órdenes industriales no ofrecen subtrabajos', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TareaDetalle(tareaId: 'ot1', onVolver: () {}, onAbrir: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Subtrabajo'), findsNothing);
      expect(find.textContaining('dividir en subtrabajos'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cada componente abre su ficha y los datos se guardan sin cerrar la página', (tester) async {
      await pintar(tester, 980);
      await tester.tap(find.text('Motor'));
      await tester.pumpAndSettle();
      expect(find.text('Componente de CAM-01 · Camión'), findsOneWidget);
      await tester.tap(find.text('Datos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Motor revisado');
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();
      expect(store.activo('a2')!.nombre, 'Motor revisado');
      expect(find.byType(ActivoDetalle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }, skip: !industrial);
}
