import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/agenda_vistas.dart';
import 'package:pulpo/screens/planificacion.dart';
import 'package:pulpo/screens/vista_dias.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio San José'));
    store.guardarCliente(Cliente(id: 'c2', nombre: 'Hospital Norte', color: 1));
    store.guardarTrabajador(Trabajador(id: 'w1', nombre: 'Javier', competencias: ['Ascensores']));
    store.guardarTarea(
      Tarea(
        id: 'a',
        clienteId: 'c1',
        nombre: 'Ascensor',
        tipo: 'Ascensor',
        competencias: ['Ascensores'],
        proximo: hoy(),
      ),
    );
    store.guardarTarea(
      Tarea(id: 'b', clienteId: 'c2', nombre: 'Centralita', tipo: 'Contra incendios', proximo: masDias(hoy(), -3)),
    );
    store.guardarTarea(
      Tarea(
        id: 'c',
        clienteId: 'c2',
        nombre: 'Caldera',
        tipo: 'Caldera',
        competencias: ['Calderas (RITE)'],
        ultimo: masDias(hoy(), -2),
        proximo: masDias(hoy(), 5),
      ),
    );
  });

  test('cada tarea cae en su día', () {
    // Hoy: lo que toca hoy y lo vencido.
    expect(store.tareasDelDia(hoy()).map((t) => t.id), unorderedEquals(['a', 'b']));
    // Pasado: lo que se hizo ese día.
    expect(store.tareasDelDia(masDias(hoy(), -2)).map((t) => t.id), ['c']);
    // Futuro: lo que toca ese día.
    expect(store.tareasDelDia(masDias(hoy(), 5)).map((t) => t.id), ['c']);
    expect(store.tareasDelDia(masDias(hoy(), 1)), isEmpty);
  });

  test('el pulpo asigna solo a quien es apto', () {
    final actual = store.tareas.where((t) => !t.esPlantilla).toList();
    expect(store.automatizar(actual), 2); // ascensor y centralita → Javier; la caldera pide RITE y él no lo tiene
    expect(store.tareas.firstWhere((t) => t.id == 'a').trabajadorIds, ['w1']);
    expect(store.tareas.firstWhere((t) => t.id == 'c').trabajadorIds, isEmpty);
    expect(store.automatizar(actual), 0); // lo que queda no lo puede hacer nadie
  });

  for (final nombre in ['Plan', 'Calendario']) {
    testWidgets('La agenda se pinta en la vista $nombre', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Planificacion(mapa: false))));
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
      expect(find.text('Hoy'), findsWidgets);
      // El mapa va apagado al entrar; solo en Calendario está su botón.
      expect(find.byTooltip('Mostrar mapa'), nombre == 'Calendario' ? findsOneWidget : findsNothing);
      if (nombre == 'Calendario') {
        await tester.tap(find.byTooltip('Mostrar mapa'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(MapaAgenda), findsOneWidget);
        expect(find.byTooltip('Ocultar mapa'), findsOneWidget);
      }
    });
  }

  group('scroll de días con imán', () {
    Future<PageController> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VistaDias())));
      await tester.pumpAndSettle();
      return tester.widget<PageView>(find.byType(PageView)).controller!;
    }

    bool centrado(PageController pc) => (pc.page! - pc.page!.round()).abs() < .001;

    testWidgets('arrastrar un poco y soltar vuelve a centrar un día', (tester) async {
      final pc = await montar(tester);
      final antes = pc.page!.round();
      await tester.drag(find.byType(PageView), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(centrado(pc), isTrue);
      expect(pc.page!.round(), antes);
    });

    testWidgets('lanzarlo con fuerza avanza varios días y acaba centrado', (tester) async {
      final pc = await montar(tester);
      final antes = pc.page!.round();
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 3000);
      await tester.pumpAndSettle();
      expect(centrado(pc), isTrue);
      expect(pc.page!.round() - antes, greaterThan(1));
    });

    testWidgets('la rueda del ratón pasa de día en día', (tester) async {
      final pc = await montar(tester);
      final antes = pc.page!.round();
      final centro = tester.getCenter(find.byType(PageView));
      final raton = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(raton.hover(centro));
      await tester.sendEventToBinding(raton.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();
      expect(centrado(pc), isTrue);
      expect(pc.page!.round(), antes + 1);
    });
  });
}
