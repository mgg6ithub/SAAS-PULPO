import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/estadisticas.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/resumen.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estadísticas de Inicio y avisos útiles: equipo que falla, técnico sobrecargado, cliente olvidado.
void main() {
  final d = hoy();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio Arana'));
    store.guardarCliente(Cliente(id: 'c2', nombre: 'Hospital Olvidado', fechaAlta: DateTime(2020)));
    store.guardarEquipo(Equipo(id: 'e1', clienteId: 'c1', tipo: 'Ascensor', nombre: 'Ascensor 1'));
    store.guardarTrabajador(Trabajador(id: 'w1', nombre: 'Ana'));
    for (var i = 0; i < 3; i++) {
      store.guardarTarea(
        Tarea(
          id: 'av$i',
          clienteId: 'c1',
          equipoId: 'e1',
          nombre: 'Avería $i',
          tipo: 'Ascensor',
          criticidad: Criticidad.critica,
          ultimo: masDias(d, -10 * (i + 1)),
          duracionMin: 120,
        ),
      );
    }
    // 6 trabajos de 8 h para Ana esta semana: 48 h.
    for (var i = 0; i < 6; i++) {
      store.guardarTarea(
        Tarea(
          id: 'r$i',
          clienteId: 'c1',
          nombre: 'Revisión $i',
          tipo: 'Caldera',
          periodicidad: Periodicidad.mensual,
          proximo: masDias(d, i),
          duracionMin: 480,
          trabajadorIds: ['w1'],
        ),
      );
    }
    store.guardarTarea(
      Tarea(id: 'o1', clienteId: 'c2', nombre: 'Extintores', tipo: 'Otro', ultimo: DateTime(2023, 5, 1)),
    );
  });

  test('averías, hechos por mes y por tipo', () {
    expect(esAveria(store.tarea('av0')!), isTrue);
    expect(esAveria(store.tarea('r0')!), isFalse);
    final meses = hechosPorMes(store, ahora: d);
    expect(meses.length, 6);
    expect(meses.last.$1, DateTime(d.year, d.month));
    expect(meses.fold(0, (n, m) => n + m.$2), 3, reason: 'las tres averías, hechas en el último mes y medio');
    final caldera = porTipo(store).first;
    expect((caldera.tipo, caldera.trabajos, caldera.minutosMedios, caldera.averias), ('Caldera', 6, 480, 0));
    expect(porTipo(store).firstWhere((t) => t.tipo == 'Ascensor').averias, 3);
    expect(clientesConAverias(store).single.$2, 3);
  });

  test('avisos: equipo que falla, técnico sobrecargado y cliente olvidado', () {
    expect(equiposQueFallan(store).map((e) => e.id), ['e1']);
    expect(sobrecargados(store).map((w) => w.id), ['w1']);
    expect(clientesOlvidados(store).map((c) => c.id), ['c2']);
    store.guardarTarea(store.tarea('o1')!..ultimo = masDias(d, -5));
    expect(clientesOlvidados(store), isEmpty);
  });

  for (final ancho in [1440.0, 600.0]) {
    testWidgets('Inicio con estadísticas y avisos a ${ancho.round()} px', (tester) async {
      tester.view.physicalSize = Size(ancho, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Resumen(onIr: (_) {}, onTrabajador: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Estadísticas'), findsOneWidget);
      expect(find.text('Clientes con más averías'), findsOneWidget);
      expect(find.text('Ascensor 1 falla demasiado'), findsOneWidget);
      expect(find.text('Ana va sobrecargado'), findsOneWidget);
      expect(find.text('1 cliente sin revisión desde hace más de un año'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
