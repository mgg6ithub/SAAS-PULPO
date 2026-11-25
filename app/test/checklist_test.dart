import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/industrial/activo.dart';
import 'package:pultec/industrial/checklist.dart';
import 'package:pultec/industrial/plan.dart';
import 'package:pultec/industrial/planes.dart' show PlanForm;
import 'package:pultec/informes.dart' show Informe, informePdf;
import 'package:pultec/models.dart';
import 'package:pultec/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pultec (DEV-052): checklists de activo y mantenimiento, copia en la OT, marcado y parte.
/// Correr con `flutter test --dart-define=MARCA=industrial test/checklist_test.dart`.
void main() {
  late Activo a;
  late PlanMantenimiento p;
  late Tarea ot;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    a = Activo(id: 'a1', tag: 'CAM-01', nombre: 'Camión', checklist: ['Revisar luces', 'Revisar frenos']);
    p = PlanMantenimiento(id: 'p1', activoId: 'a1', nombre: 'Cambio de aceite', cadaDias: 30);
    ot = Tarea(id: 'ot1', nombre: 'Cambio de aceite', activoId: 'a1', planId: 'p1', plantilla: false);
    store
      ..activos = [a]
      ..planes = [p]
      ..tareas.removeWhere((t) => !t.esPlantilla)
      ..tareas.add(ot);
  });

  test('la OT usa la del mantenimiento y, si no tiene, la del activo', () {
    expect([for (final x in checklistDe(ot)) x.paso], ['Revisar luces', 'Revisar frenos']);
    p.checklist = ['Vaciar', 'Cambiar filtro', 'Rellenar'];
    expect([for (final x in checklistDe(ot)) x.paso], ['Vaciar', 'Cambiar filtro', 'Rellenar']);
    expect(progresoChecklist(ot), '0 de 3');
  });

  test('marcar guarda la copia en la OT y no cambia al editar la plantilla', () async {
    final pasos = checklistDe(ot);
    pasos.first
      ..hecho = true
      ..cuando = DateTime(2026, 11, 25, 10, 32)
      ..nota = 'Luz trasera fundida';
    await store.marcarChecklist(ot, pasos);
    a.checklist = ['Otra cosa'];
    expect(progresoChecklist(ot), '1 de 2');
    // Ida y vuelta por JSON (lo que se guarda en el dispositivo).
    final copia = Tarea.fromJson(ot.toJson());
    expect(copia.checklist.first.nota, 'Luz trasera fundida');
    expect(copia.checklist.first.cuando, DateTime(2026, 11, 25, 10, 32));
    expect(copia.checklist.last.hecho, false);
    expect(PlanMantenimiento.fromJson((p..checklist = ['x']).toJson()).checklist, ['x']);
    expect(Activo.fromJson(a.toJson()).checklist, ['Otra cosa']);
  });

  test('checklists guardadas para reutilizar, sin repetir ni ofrecerse a sí misma', () {
    store.activos.add(Activo(id: 'a2', tag: 'CAM-02', checklist: ['Revisar luces', 'Revisar frenos']));
    p.checklist = ['Vaciar'];
    final g = checklistsGuardadas(salvo: 'p1');
    expect(g.length, 1);
    expect(g.single.$2, ['Revisar luces', 'Revisar frenos']);
  });

  test('el parte PDF se genera con la checklist', () async {
    final pdf = await informePdf(Informe(trabajoId: 'ot1', resultado: 0, notas: 'Hecho'), ot);
    expect(pdf.length, greaterThan(1000));
  });

  testWidgets('el editor añade, quita y avisa de los pasos', (tester) async {
    List<String>? ultimo;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EditorChecklist(const ['Uno'], (x) => ultimo = x)),
    ));
    // Con pasos se abre cerrada: «Editar» la abre.
    expect(find.text('Añadir paso'), findsNothing);
    await tester.tap(find.text('Editar'));
    await tester.pump();
    await tester.tap(find.text('Añadir paso'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Dos');
    expect(ultimo, ['Uno', 'Dos']);
    await tester.tap(find.byTooltip('Quitar paso').first);
    await tester.pump();
    expect(ultimo, ['Dos']);
    // «Listo» la cierra: ya no se puede escribir.
    await tester.tap(find.text('Listo'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Dos'), findsOneWidget);
  });

  testWidgets('el formulario de mantenimiento trae el bloque Checklist y Más opciones plegado', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PlanForm(activoId: 'a1'))));
    await tester.pumpAndSettle();
    expect(find.text('Qué se mide'), findsNothing);
    await tester.ensureVisible(find.text('Añadir paso'));
    await tester.tap(find.text('Añadir paso'));
    await tester.pumpAndSettle();
    expect(find.text('Describe el paso'), findsOneWidget);
    await tester.ensureVisible(find.text('Más opciones'));
    await tester.tap(find.text('Más opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Qué se mide'), findsOneWidget);
  });
}
