import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/importar.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/importar_exportar.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Importar desde CSV (con avisos y sin duplicados) y exportar con las mismas columnas.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
  });

  test('lee CSV con ; o , comillas, saltos dentro y BOM', () {
    expect(leerCsv('﻿Nombre;Notas\r\n"Pérez; S.L.";"dice ""hola""\nadiós"\r\n\r\n'), [
      ['Nombre', 'Notas'],
      ['Pérez; S.L.', 'dice "hola"\nadiós'],
    ]);
    expect(leerCsv('Nombre,CIF\nAna,B1'), [
      ['Nombre', 'CIF'],
      ['Ana', 'B1'],
    ]);
  });

  test('fechas dd/mm/aaaa, d/m/aa y aaaa-mm-dd; las imposibles no valen', () {
    expect(leerFecha('05/11/2026'), DateTime(2026, 11, 5));
    expect(leerFecha('5/1/27'), DateTime(2027, 1, 5));
    expect(leerFecha('2026-11-05'), DateTime(2026, 11, 5));
    expect(leerFecha('31/02/2026'), isNull);
    expect(leerFecha('mañana'), isNull);
  });

  test('clientes: cabeceras sin tildes, sin nombre avisa y no duplica por nombre o CIF', () {
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio Arana', cif: 'B1'));
    final imp = prepararImportacion(
      QueImportar.clientes,
      leerCsv('nombre;cif;direccion;ciudad\nColegio Nuevo;B2;Calle 1;Bilbao\n;B3;;\ncolegio arana;;;\nOtro;b1;;'),
      store,
    );
    expect(imp.clientes.map((c) => c.nombre), ['Colegio Nuevo']);
    expect(imp.clientes.single.ciudad, 'Bilbao');
    expect(imp.duplicados, 2);
    expect(imp.avisos, ['Fila 3: sin nombre, no se importa.']);
    imp.aplicar(store);
    expect(store.clientes.length, 2);
  });

  test('falta una columna obligatoria', () {
    final imp = prepararImportacion(QueImportar.trabajos, leerCsv('Nombre;Tipo\nRevisión;Ascensor'), store);
    expect(imp.total, 0);
    expect(imp.avisos.single, contains('«Cliente»'));
  });

  test('trabajadores: competencias conocidas, avisa de las que no existen', () {
    final imp = prepararImportacion(
      QueImportar.trabajadores,
      leerCsv('Nombre;Apellidos;Competencias\nLuis;García;ascensores, Magia'),
      store,
    );
    expect(imp.trabajadores.single.competencias, ['Ascensores']);
    expect(imp.avisos.single, contains('«Magia»'));
  });

  test('trabajos: cliente por nombre, tipo, periodicidad y fechas; lo que no cuadra avisa', () {
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio Arana', cif: 'B1'));
    final imp = prepararImportacion(
      QueImportar.trabajos,
      leerCsv(
        'Cliente;Nombre;Tipo;Periodicidad;Próximo;Último;Duración (min)\n'
        'Colegio Arana;Revisión ascensor;ascensor;mensual;;01/10/2026;45\n'
        'B1;Caldera;Volcanes;Cada siglo;32/13/2026;;\n'
        'Nadie;Extintores;;;;;',
      ),
      store,
    );
    expect(imp.tareas.length, 2);
    final a = imp.tareas.first;
    expect((a.clienteId, a.tipo, a.periodicidad, a.duracionMin), ('c1', 'Ascensor', Periodicidad.mensual, 45));
    expect(a.proximo, masDias(DateTime(2026, 10, 1), Periodicidad.mensual.dias), reason: 'sale del último');
    expect(imp.tareas.last.tipo, 'Otro');
    expect(imp.avisos.length, 4, reason: 'tipo, periodicidad, fecha y cliente');
  });

  test('lo exportado se vuelve a importar sin duplicar nada', () {
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio "Arana"; Norte', direccion: 'Calle 1\nbajo'));
    store.guardarTrabajador(Trabajador(id: 'w1', nombre: 'Ana', competencias: ['Ascensores']));
    store.guardarTarea(
      Tarea(
        id: 't1',
        clienteId: 'c1',
        nombre: 'Revisión',
        tipo: 'Ascensor',
        proximo: DateTime(2026, 12, 1),
        historial: [DateTime(2026, 9, 1)],
      ),
    );
    for (final q in QueImportar.values) {
      final filas = leerCsv(exportarCsv(q, store));
      expect(filas.first, q.columnas);
      final imp = prepararImportacion(q, filas, store);
      expect(imp.total, 0, reason: q.etiqueta);
      expect(imp.avisos, isEmpty, reason: q.etiqueta);
      expect(imp.duplicados, greaterThan(0), reason: q.etiqueta);
    }
    expect(leerCsv(exportarCsv(QueImportar.clientes, store))[1][0], 'Colegio "Arana"; Norte');
    expect(leerCsv(exportarHistorialCsv(store)).length, 2);
  });

  test('la plantilla se importa tal cual', () {
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Colegio San José'));
    for (final q in [QueImportar.trabajadores, QueImportar.trabajos]) {
      final imp = prepararImportacion(q, leerCsv(plantillaCsv(q)), store);
      expect(imp.total, 1, reason: q.etiqueta);
      expect(imp.avisos, isEmpty, reason: q.etiqueta);
    }
  });

  testWidgets('la ventana se abre a 1440 y 400 px', (tester) async {
    for (final ancho in [1440.0, 400.0]) {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ImportarExportar())));
      await tester.tap(find.text('Trabajos').first);
      await tester.pumpAndSettle();
      expect(find.text('Elegir archivo CSV'), findsOneWidget);
      expect(find.text('Histórico'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
