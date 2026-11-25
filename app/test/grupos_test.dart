import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/models.dart';
import 'package:pultec/screens/grupos.dart';
import 'package:pultec/screens/trabajadores.dart';
import 'package:pultec/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pultec: grupos de técnicos (un técnico en varios grupos, sin área).
/// Correr con `flutter test --dart-define=MARCA=industrial test/grupos_test.dart`.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store
      ..grupos = [GrupoTecnicos(id: 'g1', nombre: 'Hidráulica'), GrupoTecnicos(id: 'g2', nombre: 'Neumática')]
      ..trabajadores = [
        Trabajador(id: 'w1', nombre: 'Iker', grupoIds: ['g1', 'g2']),
        Trabajador(id: 'w2', nombre: 'Irene', grupoIds: ['g1']),
        Trabajador(id: 'w3', nombre: 'Ana'),
      ];
  });

  test('un técnico puede estar en varios grupos', () {
    expect([for (final w in store.tecnicosDe('g1')) w.id], ['w1', 'w2']);
    expect([for (final w in store.tecnicosDe('g2')) w.id], ['w1']);
    expect(store.sinGrupo(store.trabajador('w3')!), true);
    store.borrarGrupo('g1');
    expect(store.trabajador('w1')!.grupoIds, ['g2']);
    expect(store.sinGrupo(store.trabajador('w2')!), true);
  });

  test('lee el grupo único de antes', () {
    final w = Trabajador.fromJson({'id': 'x', 'nombre': 'X', 'grupoId': 'g1'});
    expect(w.grupoIds, ['g1']);
    expect(Trabajador.fromJson(w.toJson()).grupoIds, ['g1']);
  });

  testWidgets('el formulario de grupo mete y saca técnicos sin sacarlos de otros grupos', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GrupoForm(original: store.grupo('g2')))));
    await tester.pumpAndSettle();
    // Solo salen los que están: Iker. Irene se añade desde «+ Técnico»; a Iker se le saca con su aspa.
    expect(find.text('Irene'), findsNothing);
    await tester.tap(find.text('Técnico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Irene').last);
    await tester.pump();
    await tester.tap(find.text('Añadir 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sacar del grupo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(store.trabajador('w2')!.grupoIds, containsAll(['g1', 'g2']));
    expect(store.trabajador('w1')!.grupoIds, ['g1']);
  });

  testWidgets('Técnicos: grupos arriba, plegables, y un técnico en dos grupos sale en los dos', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Trabajadores(onAbrir: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.text('Hidráulica'), findsOneWidget);
    expect(find.text('Sin grupo'), findsOneWidget);
    expect(find.text('Iker'), findsNWidgets(2));
    await tester.tap(find.text('Neumática'));
    await tester.pumpAndSettle();
    expect(find.text('Iker'), findsOneWidget);
    expect(find.text('Área del grupo'), findsNothing);
  });
}
