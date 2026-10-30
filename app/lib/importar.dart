import 'models.dart';
import 'store.dart';
import 'theme.dart' show tipos, competencias, paleta;
import 'marca.dart';

/// Importar clientes, trabajadores y trabajos desde CSV (de Excel: «Guardar como → CSV») y exportarlos.
/// Las columnas de la exportación son las mismas que las de la importación: lo exportado se vuelve a importar.
enum QueImportar { clientes, trabajadores, trabajos }

extension QueImportarX on QueImportar {
  String get etiqueta => [m('Clientes'), m('Trabajadores'), m('Trabajos')][index];

  List<String> get columnas => const [
    [
      'Nombre',
      'CIF',
      'Dirección',
      'Código postal',
      'Ciudad',
      'Provincia',
      'Teléfono',
      'Email',
      'Contacto',
      'Teléfono contacto',
      'Notas',
    ],
    ['Nombre', 'Apellidos', 'Teléfono', 'Email', 'Competencias'],
    [
      'Cliente',
      'Nombre',
      'Tipo',
      'Periodicidad',
      'Próximo',
      'Último',
      'Duración (min)',
      'Ubicación',
      'Marca',
      'Modelo',
      'Número de serie',
      'Notas',
    ],
  ][index];

  /// Una fila de ejemplo para la plantilla.
  List<String> get ejemplo => const [
    [
      'Colegio San José',
      'B12345678',
      'Calle Mayor 3',
      '48001',
      'Bilbao',
      'Bizkaia',
      '944000000',
      'info@sanjose.es',
      'Ana (conserje)',
      '600000000',
      'Llave en conserjería',
    ],
    ['Luis', 'García', '600111222', 'luis@empresa.es', 'Ascensores, Electricidad'],
    [
      'Colegio San José',
      'Revisión ascensor',
      'Ascensor',
      'Mensual',
      '15/11/2026',
      '15/10/2026',
      '60',
      'Portal',
      'Orona',
      '3G',
      'S-1234',
      '',
    ],
  ][index];
}

/// Sin tildes, en minúsculas y sin espacios de más: para comparar nombres y cabeceras.
String normalizar(String s) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñç', a = 'aaaaeeeeiiiioooouuuunc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().trim().split('')) {
    final i = de.indexOf(ch);
    b.write(i < 0 ? ch : a[i]);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Lee un CSV con `;`, `,` o tabulador (el que más salga en la cabecera), comillas y saltos dentro de ellas.
List<List<String>> leerCsv(String texto) {
  if (texto.startsWith('﻿')) texto = texto.substring(1);
  final cabecera = texto.split('\n').first;
  final sep = [';', ',', '\t'].reduce((a, b) => a.allMatches(cabecera).length >= b.allMatches(cabecera).length ? a : b);
  final filas = <List<String>>[];
  var fila = <String>[];
  final celda = StringBuffer();
  var comillas = false;
  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];
    if (comillas) {
      if (c == '"' && i + 1 < texto.length && texto[i + 1] == '"') {
        celda.write('"');
        i++;
      } else if (c == '"') {
        comillas = false;
      } else {
        celda.write(c);
      }
    } else if (c == '"') {
      comillas = true;
    } else if (c == sep) {
      fila.add(celda.toString().trim());
      celda.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < texto.length && texto[i + 1] == '\n') i++;
      fila.add(celda.toString().trim());
      celda.clear();
      if (fila.any((x) => x.isNotEmpty)) filas.add(fila);
      fila = [];
    } else {
      celda.write(c);
    }
  }
  fila.add(celda.toString().trim());
  if (fila.any((x) => x.isNotEmpty)) filas.add(fila);
  return filas;
}

/// CSV con `;` y BOM, como lo abre Excel en español sin preguntar.
String escribirCsv(List<List<String>> filas) {
  String celda(String x) => x.contains(RegExp('[;"\n\r]')) ? '"${x.replaceAll('"', '""')}"' : x;
  return '﻿${filas.map((f) => f.map(celda).join(';')).join('\r\n')}\r\n';
}

String _fecha(DateTime? d) => d == null ? '' : fecha(d);

/// dd/mm/aaaa, d/m/aa o aaaa-mm-dd.
DateTime? leerFecha(String s) {
  s = s.trim();
  var m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2}|\d{4})$').firstMatch(s);
  if (m != null) {
    final y = int.parse(m[3]!);
    final d = DateTime(y < 100 ? 2000 + y : y, int.parse(m[2]!), int.parse(m[1]!));
    return d.day == int.parse(m[1]!) ? d : null;
  }
  m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m != null) return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return null;
}

/// Lo que se va a importar, con los avisos de lo que no cuadra, antes de guardarlo.
class Importacion {
  final QueImportar que;
  final clientes = <Cliente>[];
  final trabajadores = <Trabajador>[];
  final tareas = <Tarea>[];

  /// «Fila 4: …», en el orden del archivo.
  final avisos = <String>[];

  /// Filas que ya estaban (en Pulpo o repetidas en el archivo) y no se importan.
  int duplicados = 0;
  Importacion(this.que);

  int get total => clientes.length + trabajadores.length + tareas.length;

  /// Lo guarda todo de una vez.
  void aplicar(Store s) => s.importar(clientes: clientes, trabajadores: trabajadores, tareas: tareas);
}

/// Prepara la importación de [filas] (la primera, la cabecera) sin tocar nada todavía.
Importacion prepararImportacion(QueImportar que, List<List<String>> filas, Store s) {
  final imp = Importacion(que);
  if (filas.isEmpty) {
    imp.avisos.add('El archivo está vacío.');
    return imp;
  }
  final cab = [for (final c in filas.first) normalizar(c)];
  int col(String nombre) => cab.indexOf(normalizar(nombre));
  final obligatorias = que == QueImportar.trabajos ? ['Cliente', 'Nombre'] : ['Nombre'];
  for (final c in obligatorias.where((c) => col(c) < 0)) {
    imp.avisos.add('Falta la columna «$c». Descarga la plantilla para ver las columnas.');
  }
  if (imp.avisos.isNotEmpty) return imp;

  for (var n = 1; n < filas.length; n++) {
    final f = filas[n];
    String v(String nombre) {
      final i = col(nombre);
      return i < 0 || i >= f.length ? '' : f[i];
    }

    void aviso(String texto) => imp.avisos.add('Fila ${n + 1}: $texto');
    final nombre = v('Nombre');
    if (nombre.isEmpty) {
      aviso('sin nombre, no se importa.');
      continue;
    }
    switch (que) {
      case QueImportar.clientes:
        final cif = v('CIF').toUpperCase();
        final ya = [
          ...s.clientes,
          ...imp.clientes,
        ].any((c) => normalizar(c.nombre) == normalizar(nombre) || (cif.isNotEmpty && c.cif.toUpperCase() == cif));
        if (ya) {
          imp.duplicados++;
          continue;
        }
        imp.clientes.add(
          Cliente(
            id: s.nuevoId(),
            nombre: nombre,
            cif: cif,
            direccion: v('Dirección'),
            cp: v('Código postal'),
            ciudad: v('Ciudad'),
            provincia: v('Provincia'),
            telefono: v('Teléfono'),
            email: v('Email'),
            contacto: v('Contacto'),
            telefonoContacto: v('Teléfono contacto'),
            notas: v('Notas'),
            color: (s.clientes.length + imp.clientes.length) % paleta.length,
          ),
        );
      case QueImportar.trabajadores:
        final apellidos = v('Apellidos'), email = v('Email');
        final completo = normalizar('$nombre $apellidos');
        final ya = [...s.trabajadores, ...imp.trabajadores].any(
          (w) =>
              normalizar(w.nombreCompleto) == completo ||
              (email.isNotEmpty && w.email.toLowerCase() == email.toLowerCase()),
        );
        if (ya) {
          imp.duplicados++;
          continue;
        }
        final suyas = <String>[];
        for (final c in v('Competencias').split(RegExp('[,|]')).map((x) => x.trim()).where((x) => x.isNotEmpty)) {
          final conocida = competencias.where((x) => normalizar(x) == normalizar(c)).firstOrNull;
          conocida == null ? aviso('la competencia «$c» no existe; añádela en Ajustes.') : suyas.add(conocida);
        }
        imp.trabajadores.add(
          Trabajador(
            id: s.nuevoId(),
            nombre: nombre,
            apellidos: apellidos,
            telefono: v('Teléfono'),
            email: email,
            competencias: suyas,
            color: (s.trabajadores.length + imp.trabajadores.length) % paleta.length,
          ),
        );
      case QueImportar.trabajos:
        final cliente = s.clientes
            .where(
              (c) =>
                  normalizar(c.nombre) == normalizar(v('Cliente')) || c.cif.toUpperCase() == v('Cliente').toUpperCase(),
            )
            .firstOrNull;
        if (cliente == null) {
          aviso('no hay ningún cliente «${v('Cliente')}»; impórtalo antes.');
          continue;
        }
        var tipo = tipos.where((t) => normalizar(t.nombre) == normalizar(v('Tipo'))).firstOrNull?.nombre;
        if (tipo == null) {
          if (v('Tipo').isNotEmpty) aviso('el tipo «${v('Tipo')}» no existe; va como «Otro».');
          tipo = 'Otro';
        }
        var periodicidad = Periodicidad.values
            .where((p) => normalizar(p.etiqueta) == normalizar(v('Periodicidad')))
            .firstOrNull;
        if (periodicidad == null) {
          if (v('Periodicidad').isNotEmpty) aviso('periodicidad «${v('Periodicidad')}» desconocida; va como «Única».');
          periodicidad = Periodicidad.unica;
        }
        DateTime? leer(String columna) {
          if (v(columna).isEmpty) return null;
          final d = leerFecha(v(columna));
          if (d == null) aviso('fecha «${v(columna)}» de «$columna» no válida (usa dd/mm/aaaa).');
          return d;
        }

        final ultimo = leer('Último');
        var proximo = leer('Próximo');
        if (proximo == null && ultimo != null && periodicidad.repite) proximo = masDias(ultimo, periodicidad.dias);
        final ya = [...s.tareas, ...imp.tareas].any(
          (t) =>
              t.clienteId == cliente.id &&
              normalizar(t.nombre) == normalizar(nombre) &&
              t.proximo?.difference(proximo ?? DateTime(0)).inDays == 0,
        );
        if (ya) {
          imp.duplicados++;
          continue;
        }
        final duracion = int.tryParse(v('Duración (min)'));
        imp.tareas.add(
          Tarea(
            id: s.nuevoId(),
            clienteId: cliente.id,
            nombre: nombre,
            tipo: tipo,
            periodicidad: periodicidad,
            proximo: proximo,
            ultimo: ultimo,
            duracionMin: duracion == null || duracion <= 0 ? 60 : duracion,
            ubicacion: v('Ubicación'),
            marca: v('Marca'),
            modelo: v('Modelo'),
            numeroSerie: v('Número de serie'),
            notas: v('Notas'),
          ),
        );
    }
  }
  return imp;
}

/// Plantilla para rellenar: la cabecera y una fila de ejemplo.
String plantillaCsv(QueImportar que) => escribirCsv([que.columnas, que.ejemplo]);

String exportarCsv(QueImportar que, Store s) => escribirCsv([
  que.columnas,
  ...switch (que) {
    QueImportar.clientes => [
      for (final c in s.clientes)
        [
          c.nombre,
          c.cif,
          c.direccion,
          c.cp,
          c.ciudad,
          c.provincia,
          c.telefono,
          c.email,
          c.contacto,
          c.telefonoContacto,
          c.notas,
        ],
    ],
    QueImportar.trabajadores => [
      for (final w in s.trabajadores) [w.nombre, w.apellidos, w.telefono, w.email, w.competencias.join(', ')],
    ],
    QueImportar.trabajos => [
      for (final t in s.tareas.where((t) => !t.esPlantilla))
        [
          s.cliente(t.clienteId)?.nombre ?? '',
          t.nombre,
          t.tipo,
          t.periodicidad.etiqueta,
          _fecha(t.proximo),
          _fecha(t.ultimo),
          '${t.duracionMin}',
          t.ubicacion,
          t.marca,
          t.modelo,
          t.numeroSerie,
          t.notas,
        ],
    ],
  },
]);

/// Todo lo hecho, una fila por visita (el histórico de cada trabajo).
String exportarHistorialCsv(Store s) {
  final visitas = [
    for (final t in s.tareas.where((t) => !t.esPlantilla))
      for (final d in {...t.historial, ?t.ultimo}) (d, t),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  return escribirCsv([
    ['Fecha', 'Cliente', 'Trabajo', 'Tipo'],
    for (final (d, t) in visitas) [fecha(d), s.cliente(t.clienteId)?.nombre ?? '', t.nombre, t.tipo],
  ]);
}
