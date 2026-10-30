import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/incidencia.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/nube.dart';
import 'package:pulpo/informes.dart';
import 'package:pulpo/marca.dart';
import 'package:pulpo/widgets.dart';
import 'package:pulpo/screens/vista_trabajador.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// flutter test --dart-define=MARCA=industrial test/tecnico_industrial_test.dart
void main() {
  group("Vista del técnico industrial", () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await store.cargar();
      store.nube = null;
      store.tareas = [];
      store.trabajadores = [
        Trabajador(id: 'w1', nombre: 'Ana', competencias: ['Mecánica']),
      ];
      store.activos = [Activo(id: 'a1', tag: 'CAM', nombre: 'Camión')];
      store.incidencias = [];
      for (final (id, nombre, categoria, ids) in [
        ('ot1', 'Cambiar aceite', 'Mecánica', <String>[]),
        ('ot2', 'Revisar cuadro', 'Electricidad', <String>[]),
        ('ot3', 'Asignada a otro', 'Mecánica', ['w2']),
      ]) {
        store.guardarTarea(
          Tarea(
            id: id,
            nombre: nombre,
            activoId: 'a1',
            plantilla: false,
            tipoMantenimiento: TipoMantenimiento.preventivo,
            periodicidad: Periodicidad.unica,
            proximo: hoy(),
            competencias: [categoria],
            trabajadorIds: ids,
          ),
        );
      }
      rolTrabajador.value = 'w1';
    });

    Future<void> pintar(WidgetTester tester, double ancho) async {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ShellTrabajador()));
      await tester.pumpAndSettle();
    }

    for (final ancho in [1440.0, 980.0, 700.0, 600.0, 420.0, 360.0]) {
      testWidgets('OT por categoría y formulario a $ancho', (tester) async {
        await pintar(tester, ancho);
        expect(find.text('Cambiar aceite'), findsOneWidget);
        expect(find.text('Revisar cuadro'), findsNothing);
        expect(find.text('Asignada a otro'), findsNothing);
        await tester.tap(find.byType(BotonPrimario));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar').last);
        await tester.pumpAndSettle();
        expect(find.text('Te falta el activo o componente'), findsWidgets);
        expect(store.incidencias, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    for (final admin in [true, false]) {
      testWidgets('inicia OT con sesión ${admin ? 'administrador en vista previa' : 'técnico'}', (tester) async {
        final t = store.tareas.first;
        t.trabajadorIds = ['w1', 'w2'];
        store.tareas = [t];
        store.activos.first
          ..icono = 'camion'
          ..tipo = TipoMantenimiento.correctivoNoCritico;
        final nube = _NubePrueba(admin);
        store.nube = nube;
        addTearDown(() => store.nube = null);
        await pintar(tester, 980);
        expect(tester.widget<Icon>(find.byIcon(Icons.local_shipping_outlined)).color,
            TipoMantenimiento.correctivoNoCritico.color);
        await tester.tap(find.text('Cambiar aceite'));
        await tester.pumpAndSettle();
        expect(tester.widget<Icon>(find.byIcon(Icons.local_shipping_outlined)).color,
            TipoMantenimiento.correctivoNoCritico.color);
        await tester.tap(find.byWidgetPredicate((w) => w is BotonAccion && w.texto == 'Empezar OT'));
        await tester.pumpAndSettle();
        expect(t.estado, EstadoTrabajo.enCurso);
        expect(t.trabajadorIds, ['w1', 'w2']);
        expect(nube.llamadasEmpezar, admin ? 0 : 1);
        expect(find.textContaining('No se pudo empezar'), findsNothing);
        expect(find.byWidgetPredicate((w) => w is BotonAccion && w.texto == 'Cerrar OT'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('empezar y cerrar con informe e histórico', (tester) async {
      await pintar(tester, 420);
      await tester.tap(find.text('Cambiar aceite'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is BotonAccion && w.texto == 'Empezar OT'));
      await tester.pumpAndSettle();
      final t = store.tareas.firstWhere((t) => t.id == 'ot1');
      expect(t.estado, EstadoTrabajo.enCurso);
      expect(t.trabajadorIds, ['w1']);
      await tester.tap(find.byWidgetPredicate((w) => w is BotonAccion && w.texto == 'Cerrar OT'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Presión 4 bar; cambiado el aceite');
      await tester.enterText(find.byType(TextField).at(1), '2 l de aceite');
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();
      expect(informes.de(t.id)!.first.material, '2 l de aceite');
      expect(informes.de(t.id)!.first.minutos, 1);
      expect(t.estado, EstadoTrabajo.realizado);
      expect(t.historial, contains(hoy()));
      expect(t.proximo, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('incidencia crea OT real en el activo', (tester) async {
      await pintar(tester, 700);
      await tester.tap(find.byType(BotonPrimario));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAM · Camión').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Fuga de aceite');
      await tester.tap(find.text('Guardar').last);
      await tester.pumpAndSettle();
      expect(store.incidencias.single.estado, EstadoIncidencia.conOt);
      final ot = store.tareas.firstWhere((t) => t.id == store.incidencias.single.trabajoId);
      expect(ot.esPlantilla, isFalse);
      expect(ot.activoId, 'a1');
      expect(ot.tipoMantenimiento, TipoMantenimiento.correctivoNoCritico);
      expect(tester.takeException(), isNull);
    });
  }, skip: !industrial);
}

/// La función del técnico rechaza a administradores, como la función real tomar_ot.
class _NubePrueba implements Nube {
  @override
  final bool esAdmin;
  _NubePrueba(this.esAdmin);
  int llamadasEmpezar = 0;
  @override
  bool get esTrabajador => !esAdmin;
  @override
  String get empresaId => 'empresa-prueba';
  @override
  String get nombre => 'Empresa de prueba';
  @override
  void sincronizar() {}
  @override
  Future<void> get guardado => Future.value();
  @override
  Future<List<Informe>> informes(String trabajoId) async => [];
  @override
  Future<void> empezarOt(String trabajoId) async {
    llamadasEmpezar++;
    if (esAdmin) throw StateError('Solo un técnico puede tomar una OT');
    store.cambiarEstado([store.tarea(trabajoId)!], EstadoTrabajo.enCurso);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
