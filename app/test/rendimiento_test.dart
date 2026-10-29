import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/ajustes.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/shell.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mide qué se reconstruye en cada fotograma con los datos de ejemplo (diagnóstico de fluidez).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ajustes.cargar();
    await store.cargar();
    store.cargarDemo();
  });

  Future<Map<String, int>> contar(Future<void> Function() accion) async {
    final c = <String, int>{};
    const zonas = {
      'Tabla',
      'ListaRejilla',
      '_Barra',
      'Planificacion',
      'VistaSemana',
      'VistaDiaTecnicos',
      'VistaCalendario',
      'MapaAgenda',
      'Resumen',
      'Clientes',
      'Trabajadores',
      'TareasPagina',
      'BarraVista',
      '_Capa',
      'Shell',
    };
    debugOnRebuildDirtyWidget = (e, _) {
      var zona = '?';
      if (zonas.contains(e.widget.runtimeType.toString())) zona = e.widget.runtimeType.toString();
      e.visitAncestorElements((a) {
        if (zona != '?') return false;
        final n = a.widget.runtimeType.toString();
        if (zonas.contains(n)) zona = n;
        return zona == '?';
      });
      final k = zona == 'Planificacion' ? 'P:${e.widget.runtimeType}' : zona;
      c[k] = (c[k] ?? 0) + 1;
    };
    await accion();
    debugOnRebuildDirtyWidget = null;
    return c;
  }

  void informe(String que, Map<String, int> c, int frames) {
    final orden = c.entries.toList()..sort((a, b) => b.value - a.value);
    final total = c.values.fold(0, (a, b) => a + b);
    debugPrint(
      '== $que: ${(total / frames).toStringAsFixed(0)} rebuilds/frame · top: '
      '${orden.take(25).map((e) => '${e.key} ${(e.value / frames).toStringAsFixed(1)}').join(', ')}',
    );
  }

  testWidgets('rendimiento', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Shell()));
    await tester.pumpAndSettle();
    // Ir al itinerario.
    await tester.tap(find.text('Itinerario').first);
    await tester.pumpAndSettle();

    // 1. Arrastrar la barra lateral 30 fotogramas.
    final borde = tester.getTopRight(find.byType(Scaffold)).dx; // no usado
    final x = ajustes.anchoBarra - 3;
    final g = await tester.startGesture(Offset(x, 400));
    await tester.pump();
    final sw = Stopwatch()..start();
    var c = await contar(() async {
      for (var i = 0; i < 30; i++) {
        await g.moveBy(const Offset(-3, 0));
        await tester.pump();
      }
    });
    informe('arrastrar barra (${sw.elapsedMilliseconds} ms)', c, 30);
    await g.up();
    await tester.pumpAndSettle();

    // 2. Contraer/expandir con el botón.
    sw.reset();
    c = await contar(() async {
      ajustes.alternarContraida();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
    informe('contraer (${sw.elapsedMilliseconds} ms)', c, 20);
    await tester.pumpAndSettle();
    ajustes.alternarContraida();
    await tester.pumpAndSettle();

    // 3. Cambiar de vista Plan -> Calendario (Mes -> Día -> Semana) -> Plan.
    for (final v in ['Calendario', 'Mes', 'Día', 'Semana', 'Plan']) {
      sw.reset();
      c = await contar(() async {
        await tester.tap(find.text(v).first);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      informe('vista $v (${sw.elapsedMilliseconds} ms)', c, 20);
      await tester.pumpAndSettle();
    }
    // 4. Otras secciones: arrastrar barra y cambiar filtros.
    for (final (seccion, filtros) in [
      ('Clientes', ['Activos', 'Inactivos', 'Todos · 8']),
      ('Trabajadores', ['Disponibles', 'Ocupados', 'Todos']),
      ('Trabajos', ['Todos', 'De clientes']),
      ('Inicio', <String>[]),
    ]) {
      ajustes.ponerAnchoBarra(260);
      await tester.pumpAndSettle();
      await tester.tap(find.text(seccion).first);
      await tester.pumpAndSettle();
      final g2 = await tester.startGesture(Offset(ajustes.anchoBarra - 3, 400));
      await tester.pump();
      sw.reset();
      c = await contar(() async {
        for (var i = 0; i < 30; i++) {
          await g2.moveBy(const Offset(-3, 0));
          await tester.pump();
        }
      });
      informe('$seccion: arrastrar barra (${sw.elapsedMilliseconds} ms)', c, 30);
      await g2.up();
      await tester.pumpAndSettle();
      for (final f in filtros) {
        final finder = find.textContaining(f.split(' ').first);
        if (finder.evaluate().isEmpty) continue;
        sw.reset();
        c = await contar(() async {
          await tester.tap(finder.first);
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        });
        informe('$seccion: filtro $f (${sw.elapsedMilliseconds} ms)', c, 20);
        await tester.pumpAndSettle();
      }
    }
    expect(borde, isNonNegative);
  });

  // Con muchos datos: 3000 trabajos repartidos en 60 días entre los técnicos de ejemplo.
  testWidgets('rendimiento con 3000 trabajos', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final clientes = store.clientes.map((c) => c.id).toList();
    final tecnicos = store.trabajadores.map((w) => w.id).toList();
    store.tareas.addAll(
      List.generate(
        3000,
        (i) => Tarea(
          id: 'm$i',
          plantilla: false,
          clienteId: clientes[i % clientes.length],
          nombre: 'Revisión $i',
          proximo: masDias(hoy(), i % 60 - 10),
          inicioMin: 480 + (i % 20) * 30,
          trabajadorIds: i % 7 == 0 ? [] : [tecnicos[i % tecnicos.length]],
          periodicidad: Periodicidad.unica,
        ),
      ),
    );
    final sw = Stopwatch()..start();
    await tester.pumpWidget(const MaterialApp(home: Shell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Itinerario').first);
    await tester.pumpAndSettle();
    debugPrint('== 3000 trabajos · abrir itinerario: ${sw.elapsedMilliseconds} ms');
    for (final v in ['Calendario', 'Mes', 'Día', 'Semana', 'Plan']) {
      sw.reset();
      final c = await contar(() async {
        await tester.tap(find.text(v).first);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      informe('3000 trabajos · vista $v (${sw.elapsedMilliseconds} ms)', c, 20);
      await tester.pumpAndSettle();
    }
    for (final seccion in ['Trabajos', 'Clientes', 'Inicio']) {
      sw.reset();
      await tester.tap(find.text(seccion).first);
      await tester.pumpAndSettle();
      debugPrint('== 3000 trabajos · abrir $seccion: ${sw.elapsedMilliseconds} ms');
    }
  });
}
