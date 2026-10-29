import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/tipos_competencias.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipos de trabajo y competencias editables por empresa.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.guardarTrabajador(Trabajador(id: 'w1', nombre: 'Ane', competencias: ['Ascensores']));
    store.guardarTarea(
      Tarea(id: 't1', clienteId: 'c1', nombre: 'Portal', tipo: 'Ascensor', competencias: ['Ascensores']),
    );
  });

  test('renombrar un tipo cambia sus trabajos y se guarda', () async {
    final t = tipos.firstWhere((x) => x.nombre == 'Ascensor');
    store.guardarTipo(t.cambiar(nombre: 'Elevador'));
    expect(store.tarea('t1')!.tipo, 'Elevador');
    expect(tipoDe('Elevador').id, t.id);
    await store.cargar();
    expect(tipos.any((x) => x.nombre == 'Elevador'), isTrue);
  });

  test('quitar un tipo pasa sus trabajos a «Otro», que no se puede quitar', () {
    store.borrarTipo(tipos.firstWhere((x) => x.nombre == 'Ascensor').id);
    expect(store.tarea('t1')!.tipo, 'Otro');
    final n = tipos.length;
    store.borrarTipo(tipos.last.id);
    expect(tipos.length, n);
    store.guardarTipo(TipoInfo('nuevo', 'Puertas', 'puerta', paleta.first, null));
    expect(tipos.last.nombre, 'Otro');
  });

  test('renombrar y quitar una competencia llega a trabajadores, trabajos y tipos', () {
    store.renombrarCompetencia('Ascensores', 'Elevadores');
    expect(store.trabajador('w1')!.competencias, ['Elevadores']);
    expect(store.tarea('t1')!.competencias, ['Elevadores']);
    expect(tipoDe('Ascensor').competencia, 'Elevadores');
    store.borrarCompetencia('Elevadores');
    expect(competencias.contains('Elevadores'), isFalse);
    expect(store.trabajador('w1')!.competencias, isEmpty);
    expect(tipoDe('Ascensor').competencia, isNull);
    store.anadirCompetencia('Puertas automáticas');
    expect(competencias.last, 'Puertas automáticas');
  });

  for (final ancho in [1440.0, 360.0]) {
    testWidgets('los editores se abren sin desbordes a ${ancho.round()} px', (tester) async {
      tester.view.physicalSize = Size(ancho, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(onPressed: () => abrirTipos(context), child: const Text('tipos')),
                  TextButton(onPressed: () => abrirCompetencias(context), child: const Text('competencias')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tipos'));
      await tester.pumpAndSettle();
      expect(find.text('Tipos de trabajo'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('competencias'));
      await tester.pumpAndSettle();
      expect(find.text('Competencias'), findsOneWidget);
      // La lista es larga: se baja hasta el campo de añadir.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(of: find.text('Nueva competencia'), matching: find.byType(TextField)),
        'Puertas',
      );
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
      expect(competencias.contains('Puertas'), isTrue);
    });
  }
}
