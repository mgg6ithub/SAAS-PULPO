import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/hoja_calculo.dart';
import 'package:pultec/informes.dart' show guiaPdf, listadoPdf;
import 'package:pultec/importar.dart';
import 'package:pultec/industrial/activo.dart';
import 'package:pultec/industrial/plan.dart';
import 'package:pultec/models.dart';
import 'package:pultec/store.dart';
import 'package:pultec/theme.dart' show competencias;
import 'package:shared_preferences/shared_preferences.dart';

/// Pultec (DEV-050): volcado de activos, componentes, mantenimientos y técnicos desde CSV, con sus OT.
/// Correr con `flutter test --dart-define=MARCA=industrial test/importar_activos_test.dart`.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store
      ..activos = []
      ..planes = []
      ..trabajadores = []
      ..tareas.removeWhere((t) => !t.esPlantilla);
  });

  Importacion preparar(QueImportar q, String csv) => prepararImportacion(q, leerCsv(csv), store);
  List<Tarea> otsDe(PlanMantenimiento p) => store.tareas.where((t) => t.planId == p.id).toList();

  test('cada: días, semanas, meses y años', () {
    expect(leerCadaDias('30'), 30);
    expect(leerCadaDias('2 semanas'), 14);
    expect(leerCadaDias('1 mes'), 30);
    expect(leerCadaDias('6 Meses'), 182);
    expect(leerCadaDias('2 meses'), 60);
    expect(leerCadaDias('1 año'), 365);
    expect(leerCadaDias('pronto'), isNull);
  });

  test('solo activos: sin mantenimientos ni OT; sin tag o sin nombre avisa', () {
    final imp = preparar(QueImportar.activos, 'Tag;Nombre;Icono;Horas contador\nCAM-01;Camión;camion;1500\nCAM-02;Camión 2;Cohete;\n;Sin tag;;\nCAM-03;;;');
    expect(imp.activos.map((a) => a.tag), ['CAM-01', 'CAM-02']);
    expect(imp.activos.first.icono, 'camion');
    expect(imp.activos.first.horas, 1500);
    expect(imp.activos[1].icono, 'fabrica');
    expect(imp.avisos, hasLength(3));
    imp.aplicar(store);
    expect(store.activos, hasLength(2));
    expect(store.tareas.where((t) => t.activoId != null), isEmpty);
  });

  test('activos con componentes (padre después del hijo, de Pultec o inexistente)', () {
    store.guardarActivo(Activo(id: 'ya', tag: 'PST-09', nombre: 'Planta vieja'));
    final imp = preparar(
      QueImportar.activos,
      'Tag,Nombre,Padre\nMOT-1,Motor,PST-01\nPST-01,Planta,\nRED-1,Reductora,MOT-1\nVAL-1,Válvula,PST-09\nX-1,Huérfano,NO-EXISTE\nPST-09,Repetido,',
    );
    Activo a(String tag) => imp.activos.firstWhere((x) => x.tag == tag);
    expect(a('MOT-1').padreId, a('PST-01').id);
    expect(a('RED-1').padreId, a('MOT-1').id);
    expect(a('VAL-1').padreId, 'ya');
    expect(a('X-1').padreId, isNull);
    expect(imp.duplicados, 1);
    expect(imp.avisos.single, contains('NO-EXISTE'));
  });

  test('bucle de padres: se corta', () {
    final imp = preparar(QueImportar.activos, 'Tag;Nombre;Padre\nA;A;B\nB;B;A');
    expect(imp.activos.where((a) => a.padreId == null), isNotEmpty);
    expect(imp.avisos.join(), contains('bucle'));
  });

  test('activos, componentes y mantenimientos del tirón: cada mantenimiento con su OT', () {
    store.guardarTrabajador(Trabajador(id: 'w1', nombre: 'Luis', apellidos: 'García', email: 'luis@x.es'));
    final esp = competencias.first;
    final hace10 = masDias(hoy(), -10);
    final f = '${hace10.day}/${hace10.month}/${hace10.year}';
    final imp = preparar(
      QueImportar.activos,
      'Tag;Nombre;Padre;Horas contador;Horas al día;Mantenimiento;Prioridad;Cada;Cada horas;Próxima fecha;Última vez;Especialidad;Técnico\n'
      'PST-01;Planta;;1000;10;Revisión;Alta;30 días;;;$f;$esp;luis@x.es\n'
      'PST-01;;;;;Aceite;;;200;;;;\n'
      'PST-01-M;Motor;PST-01;;;Engrase;Muy alta;1 mes;;;;;Luis García\n'
      'PST-01-M;;;;;Calibración;;;;31/12/2030;;;\n'
      'PST-01-M;;;;;Sin cada;;;;;;;\n'
      'PST-01;;;;;Revisión;;30;;;;;',
    );
    expect(imp.activos, hasLength(2));
    expect(imp.planes.map((p) => p.nombre), ['Revisión', 'Aceite', 'Engrase', 'Calibración']);
    expect(imp.duplicados, 1); // «Revisión» repetida
    expect(imp.avisos.single, contains('Sin cada'));
    final rev = imp.planes[0], aceite = imp.planes[1], eng = imp.planes[2], cal = imp.planes[3];
    expect(rev.prioridad, PrioridadMantenimiento.alta);
    expect(rev.cadaDias, 30);
    expect(rev.categoria, esp);
    expect(rev.trabajadorId, 'w1');
    expect(aceite.cadaHoras, 200);
    expect(aceite.ultimoHoras, 1000); // sin dato: desde las horas de hoy
    expect(eng.prioridad, PrioridadMantenimiento.critica);
    expect(eng.trabajadorId, 'w1');
    expect(cal.proximo, DateTime(2030, 12, 31));

    imp.aplicar(store);
    expect(store.planes, hasLength(4));
    for (final p in store.planes) {
      expect(otsDe(p), hasLength(1), reason: p.nombre);
    }
    expect(otsDe(rev).single.proximo, masDias(hoy(), 20));
    expect(otsDe(rev).single.trabajadorIds, ['w1']);
    expect(otsDe(aceite).single.proximo, masDias(hoy(), 20)); // 200 h a 10 h/día
    expect(otsDe(cal).single.proximo, DateTime(2030, 12, 31));
    expect(otsDe(eng).single.activoId, store.activos.firstWhere((a) => a.tag == 'PST-01-M').id);
  });

  test('mantenimientos nuevos a un activo que ya está en Pultec', () {
    store.guardarActivo(Activo(id: 'ya', tag: 'CAM-01', nombre: 'Camión'));
    final imp = preparar(QueImportar.activos, 'Tag;Mantenimiento;Cada\nCAM-01;ITV;1 año');
    expect(imp.activos, isEmpty);
    expect(imp.planes.single.activoId, 'ya');
    imp.aplicar(store);
    expect(otsDe(store.planes.single), hasLength(1));
  });

  test('lo exportado se vuelve a importar igual en otra cuenta', () {
    preparar(
      QueImportar.activos,
      'Tag;Nombre;Padre;Horas contador;Horas al día;Mantenimiento;Cada;Cada horas\nP;Planta;;500;8;Rev;6 meses;\nP;;;;;Aceite;;250\nC;Comp;P;;;;;',
    ).aplicar(store);
    final csv = exportarCsv(QueImportar.activos, store);
    final antes = (store.activos.length, store.planes.length);
    store
      ..activos = []
      ..planes = [];
    final imp = preparar(QueImportar.activos, csv);
    expect(imp.avisos, isEmpty);
    expect((imp.activos.length, imp.planes.length), antes);
    expect(imp.planes.firstWhere((p) => p.nombre == 'Rev').cadaDias, 182);
    expect(imp.activos.firstWhere((a) => a.tag == 'C').padreId, imp.activos.firstWhere((a) => a.tag == 'P').id);
  });

  test('plantilla de activos: se importa sin avisos', () {
    final imp = preparar(QueImportar.activos, plantillaCsv(QueImportar.activos));
    expect(imp.avisos, isEmpty);
    expect(imp.activos, hasLength(3));
    expect(imp.planes, hasLength(3));
    expect(guiaTexto(QueImportar.activos), contains('Padre'));
  });

  test('técnicos en bloque: especialidades, correo y sin duplicar', () {
    final esp = competencias.take(2).join(', ');
    final imp = preparar(
      QueImportar.trabajadores,
      'Nombre;Apellidos;Teléfono;Correo;Especialidades\nAna;Ruiz;600;ana@x.es;$esp\nPedro;Gil;;p@x.es;Magia\nana;ruiz;;;\n;Sin;;;',
    );
    expect(imp.trabajadores.map((w) => w.nombre), ['Ana', 'Pedro']);
    expect(imp.trabajadores.first.email, 'ana@x.es');
    expect(imp.trabajadores.first.competencias, competencias.take(2).toList());
    expect(imp.duplicados, 1);
    expect(imp.avisos, hasLength(2));
    imp.aplicar(store);
    expect(store.trabajadores, hasLength(2));
    expect(preparar(QueImportar.trabajadores, plantillaCsv(QueImportar.trabajadores)).avisos, isEmpty);
  });

  test('exportar en PDF, CSV y JSON', () async {
    preparar(
      QueImportar.activos,
      'Tag;Nombre;Padre;Mantenimiento;Cada\nP;Planta;;Rev;6 meses\nC;Comp;P;;',
    ).aplicar(store);
    final filas = [QueImportar.activos.columnas, ...filasExportar(QueImportar.activos, store)];
    final json = jsonDecode(filasJson(filas)) as List;
    expect(json, hasLength(2));
    expect(json.first, containsPair('Mantenimiento', 'Rev'));
    expect((json.last as Map).containsKey('Mantenimiento'), isFalse);
    final pdf = soloColumnas(filas, columnasPdf(QueImportar.activos));
    expect(pdf.first, columnasPdf(QueImportar.activos));
    expect(pdf[1].first, 'P');
    final bytes = await listadoPdf('Activos', pdf);
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('Excel: lo escrito se vuelve a leer igual, con tildes, saltos y celdas vacías', () {
    final filas = [
      ['Tag', 'Nombre', 'Notas'],
      ['PST-01', 'Planta de secado', 'Línea 1\nturno <noche> & "fin"'],
      ['C-1', '', 'Válvula'],
    ];
    final bytes = escribirXlsx([('Activos', filas), ('Guía', guiaFilas(QueImportar.activos))]);
    expect(bytes.sublist(0, 2), [0x50, 0x4b]); // zip
    expect(leerXlsx(bytes), filas);
    expect(() => leerXlsx([1, 2, 3]), throwsFormatException);
  });

  test('fechas de Excel como número de serie', () {
    expect(leerFecha('46022'), DateTime(2025, 12, 31));
    expect(leerFecha('12345'), isNull);
  });

  test('importar activos desde Excel y desde JSON da lo mismo que desde CSV', () {
    const csv = 'Tag;Nombre;Padre;Mantenimiento;Cada;Última vez\nP;Planta;;Rev;6 meses;01/10/2026\nC;Comp;P;;;';
    final filas = leerCsv(csv);
    final desdeCsv = preparar(QueImportar.activos, csv);
    for (final (nombre, bytes) in [
      ('activos.xlsx', escribirXlsx([('Activos', filas)])),
      ('activos.json', utf8.encode(filasJson(filas))),
    ]) {
      final imp = prepararImportacion(QueImportar.activos, leerArchivo(nombre, bytes), store);
      expect(imp.avisos, isEmpty, reason: nombre);
      expect([for (final a in imp.activos) a.tag], [for (final a in desdeCsv.activos) a.tag], reason: nombre);
      expect(imp.planes.single.cadaDias, 182, reason: nombre);
      expect(imp.planes.single.ultimo, DateTime(2026, 10, 1), reason: nombre);
    }
    expect(() => leerArchivo('x.json', utf8.encode('{"a":')), throwsFormatException);
  });

  test('plantillas en Excel, CSV y JSON se importan sin avisos; guía en PDF', () async {
    for (final f in [FormatoExportar.excel, FormatoExportar.csv, FormatoExportar.json]) {
      final imp = prepararImportacion(
        QueImportar.activos,
        leerArchivo('plantilla.${f.extension}', plantillaBytes(QueImportar.activos, f)),
        store,
      );
      expect(imp.avisos, isEmpty, reason: f.etiqueta);
      expect(imp.planes, hasLength(3), reason: f.etiqueta);
    }
    final guia = guiaFilas(QueImportar.activos);
    expect(guia[1], ['Tag', 'Sí', startsWith('Código único'), 'PST-01']);
    final pdf = await guiaPdf('activos', guia);
    expect(ascii.decode(pdf.sublist(0, 4)), '%PDF');
  });
}
