import 'industrial/activo.dart';
import 'industrial/iconos.dart';
import 'industrial/plan.dart';
import 'industrial/planes.dart' show proximoPlan;
import 'models.dart';
import 'store.dart';
import 'theme.dart' show tipos, competencias, paleta;
import 'marca.dart';

/// Importar clientes, trabajadores y trabajos (Pultec: técnicos y activos) desde CSV (de Excel: «Guardar como →
/// CSV») y exportarlos. Las columnas de la exportación son las mismas que las de la importación: lo exportado se
/// vuelve a importar.
enum QueImportar { clientes, trabajadores, trabajos, activos }

/// Lo que se importa en esta app: Pultec, técnicos y activos; la residencial, clientes, trabajadores y trabajos.
List<QueImportar> get importables => industrial
    ? const [QueImportar.activos, QueImportar.trabajadores]
    : const [QueImportar.clientes, QueImportar.trabajadores, QueImportar.trabajos];

/// Pultec: un solo CSV de activos. Cada fila es un activo o un componente (por su «Tag»; con «Padre», el tag de
/// su activo). Si la fila trae «Mantenimiento», además le añade ese mantenimiento: repetir el tag en otra fila
/// añade otro mantenimiento al mismo activo (sus datos se toman de la primera fila de ese tag).
const _guiaActivos = <(String, String)>[
  (
    'Tag',
    'Obligatoria. Código único del activo o componente (PST-01, CAM-01-MOT). Repetido en varias filas = el mismo activo con varios mantenimientos.',
  ),
  ('Nombre', 'Obligatoria en la primera fila de cada activo nuevo. Nombre del activo o componente.'),
  (
    'Padre',
    'Tag del activo al que pertenece (vacío = activo principal). Puede estar en el mismo archivo o ya en Pultec.',
  ),
  ('Icono', 'Nombre o clave del icono (Camión, Motor, Compresor…). Vacío = máquina industrial.'),
  ('Descripción', 'Breve descripción del activo.'),
  ('Fabricante', ''),
  ('Modelo', ''),
  ('Número de serie', ''),
  ('División', 'Área o división de la planta.'),
  ('Horas contador', 'Horas que marca hoy su contador (solo activos principales).'),
  ('Horas al día', 'Horas de uso diario, para estimar cuándo toca lo que va por horas.'),
  ('Mantenimiento', 'Nombre del mantenimiento. Vacío = la fila solo crea el activo.'),
  ('Descripción del mantenimiento', ''),
  ('Prioridad', 'Normal, Alta o Muy alta. Vacío = Normal.'),
  ('Cada', 'Cada cuánto tiempo: 30, 30 días, 2 semanas, 6 meses, 1 año.'),
  ('Cada horas', 'Cada cuántas horas de uso (500). Con «Cada» también, toca lo que llegue antes.'),
  ('Próxima fecha', 'Fecha fija (dd/mm/aaaa) si no se repite por tiempo ni por horas.'),
  ('Última vez', 'Fecha en que se hizo por última vez (dd/mm/aaaa). Vacío = cuenta desde hoy.'),
  ('Horas última vez', 'Horas del contador cuando se hizo. Vacío = las de hoy.'),
  ('Especialidad', 'Especialidad del técnico que puede hacerlo (como en Ajustes).'),
  ('Técnico', 'Técnico fijo: nombre y apellidos o correo de uno que ya esté en Pultec.'),
  ('Duración (min)', 'Minutos que lleva. Vacío = 60.'),
];

extension QueImportarX on QueImportar {
  String get etiqueta => [m('Clientes'), m('Trabajadores'), m('Trabajos'), 'Activos'][index];

  /// Columna y qué lleva (vacío = se entiende sola), para la guía de formato.
  List<(String, String)> get guia => switch (this) {
    QueImportar.activos => _guiaActivos,
    QueImportar.trabajadores => [
      ('Nombre', 'Obligatoria.'),
      ('Apellidos', ''),
      ('Teléfono', ''),
      ('Email', 'Correo con el que entrará en Pultec.'),
      (_competencias, '${industrial ? 'Especialidades' : 'Competencias'} separadas por comas, como en Ajustes.'),
    ],
    _ => [for (final c in columnas) (c, '')],
  };

  List<String> get columnas => switch (this) {
    QueImportar.activos => [for (final (c, _) in _guiaActivos) c],
    QueImportar.trabajadores => ['Nombre', 'Apellidos', 'Teléfono', 'Email', _competencias],
    _ => _columnas[index],
  };

  /// Filas de ejemplo para la plantilla.
  List<List<String>> get ejemplos => switch (this) {
    QueImportar.activos => const [
      [
        'PST-01',
        'Planta de secado',
        '',
        'fabrica',
        'Línea de secado térmico',
        'Andritz',
        'DDS-40',
        'S-001',
        'Secado',
        '12000',
        '16',
        'Revisión general',
        'Inspección visual y apriete',
        'Normal',
        '6 meses',
        '',
        '',
        '15/09/2026',
        '',
        'Mecánica',
        '',
        '120',
      ],
      [
        'PST-01',
        'Planta de secado',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Cambio de aceite',
        '',
        'Alta',
        '',
        '500',
        '',
        '',
        '11800',
        'Mecánica',
        '',
        '60',
      ],
      [
        'PST-01-MOT',
        'Motor principal',
        'PST-01',
        'motor',
        '',
        'Siemens',
        '1LE1',
        'M-77',
        '',
        '',
        '',
        'Engrase de rodamientos',
        '',
        'Normal',
        '1 mes',
        '',
        '',
        '01/11/2026',
        '',
        'Eléctrica',
        '',
        '30',
      ],
      [
        'PST-01-BOM',
        'Bomba de alimentación',
        'PST-01',
        'bomba',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ],
    ],
    QueImportar.trabajadores => [
      [
        'Luis',
        'García',
        '600111222',
        'luis@empresa.es',
        industrial ? competencias.take(2).join(', ') : 'Ascensores, Electricidad',
      ],
    ],
    _ => [_ejemplos[index]],
  };
}

String get _competencias => industrial ? 'Especialidades' : 'Competencias';

const _columnas = [
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
];

const _ejemplos = [
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
];

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
  final activos = <Activo>[];
  final planes = <PlanMantenimiento>[];

  /// «Fila 4: …», en el orden del archivo.
  final avisos = <String>[];

  /// Filas que ya estaban (en Pultec o repetidas en el archivo) y no se importan.
  int duplicados = 0;
  Importacion(this.que);

  int get total => clientes.length + trabajadores.length + tareas.length + activos.length + planes.length;

  /// Lo guarda todo de una vez. Pultec: cada mantenimiento nuevo sale con su OT. Con la nube la crea la base al
  /// recibirlo (como al crearlo a mano); sin ella (demo, local), se crea aquí.
  void aplicar(Store s) {
    s.importar(clientes: clientes, trabajadores: trabajadores, tareas: tareas, activos: activos, planes: planes);
    if (s.nube != null) return;
    for (final p in planes.where((p) => p.activa)) {
      final d = proximoPlan(p);
      if (d == null) continue;
      s.guardarTarea(
        p.ot(s.nuevoId())
          ..proximo = d
          ..trabajadorIds = [?p.trabajadorId],
      );
    }
  }
}

/// Otros nombres de columna que también valen (como los escribe la gente en su Excel).
const _alias = {
  'Email': ['Correo', 'Correo electrónico'],
  'Competencias': ['Especialidades'],
  'Especialidades': ['Competencias'],
  'Tag': ['Código'],
  'Padre': ['Activo padre', 'Padre tag'],
};

/// Prepara la importación de [filas] (la primera, la cabecera) sin tocar nada todavía.
Importacion prepararImportacion(QueImportar que, List<List<String>> filas, Store s) {
  final imp = Importacion(que);
  if (filas.isEmpty) {
    imp.avisos.add('El archivo está vacío.');
    return imp;
  }
  final cab = [for (final c in filas.first) normalizar(c)];
  int col(String nombre) {
    for (final n in [nombre, ...?_alias[nombre]]) {
      final i = cab.indexOf(normalizar(n));
      if (i >= 0) return i;
    }
    return -1;
  }

  final obligatorias = switch (que) {
    QueImportar.trabajos => ['Cliente', 'Nombre'],
    // Nombre solo hace falta en los activos nuevos (para añadir mantenimientos a los que ya hay, basta el tag).
    QueImportar.activos => ['Tag'],
    _ => ['Nombre'],
  };
  for (final c in obligatorias.where((c) => col(c) < 0)) {
    imp.avisos.add('Falta la columna «$c». Descarga la plantilla para ver las columnas.');
  }
  if (imp.avisos.isNotEmpty) return imp;
  if (que == QueImportar.activos) {
    _prepararActivos(imp, filas, col, s);
    return imp;
  }

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
        for (final c in v(_competencias).split(RegExp('[,|]')).map((x) => x.trim()).where((x) => x.isNotEmpty)) {
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
      case QueImportar.activos:
        break;
    }
  }
  return imp;
}

/// Icono por su clave o su nombre en el catálogo (sin tildes ni mayúsculas); null = no está.
String? _icono(String x) {
  final b = normalizar(x);
  if (b.isEmpty) return null;
  for (final (clave, nombre, _) in [...iconosIndustriales, for (final (_, l) in gruposIconos) ...l]) {
    if (normalizar(clave) == b || normalizar(nombre) == b) return clave;
  }
  for (final (clave, nombre) in iconosDibujados) {
    if (normalizar(clave) == b || normalizar(nombre) == b) return clave;
  }
  return null;
}

/// «30», «30 días», «2 semanas», «6 meses», «1 año» → días; null = no se entiende.
int? leerCadaDias(String x) {
  final r = RegExp(r'^(\d+)\s*([a-z]*)$').firstMatch(normalizar(x));
  if (r == null) return null;
  final n = int.parse(r[1]!);
  if (n <= 0) return null;
  final u = r[2]!;
  if (u.isEmpty || u.startsWith('d')) return n;
  if (u.startsWith('s')) return n * 7;
  // Los meses redondos, como los atajos del formulario (mensual 30, trimestral 91, semestral 182, anual 365).
  if (u.startsWith('m')) return const {1: 30, 3: 91, 6: 182, 12: 365}[n] ?? n * 30;
  if (u.startsWith('a')) return n * 365;
  return null;
}

double? _numero(String x) => double.tryParse(x.trim().replaceAll(' ', '').replaceAll(',', '.'));

/// Pultec: activos, componentes y sus mantenimientos de un solo CSV (ver [_guiaActivos]).
void _prepararActivos(Importacion imp, List<List<String>> filas, int Function(String) col, Store s) {
  String v(List<String> f, String nombre) {
    final i = col(nombre);
    return i < 0 || i >= f.length ? '' : f[i].trim();
  }

  // 1.ª pasada: un activo por tag (los que ya están en Pultec no se duplican).
  final porTag = <String, Activo>{for (final a in s.activos.where((a) => a.tag.isNotEmpty)) normalizar(a.tag): a};
  final nuevos = <String, (Activo, int, String)>{}; // tag → (activo, fila, tag del padre)
  final filasValidas = <(int, List<String>, Activo)>[];
  for (var n = 1; n < filas.length; n++) {
    final f = filas[n];
    void aviso(String texto) => imp.avisos.add('Fila ${n + 1}: $texto');
    final tag = v(f, 'Tag'), clave = normalizar(tag);
    if (tag.isEmpty) {
      aviso('sin tag, no se importa.');
      continue;
    }
    var a = porTag[clave];
    if (a == null) {
      final nombre = v(f, 'Nombre');
      if (nombre.isEmpty) {
        aviso('el activo $tag no tiene nombre, no se importa.');
        continue;
      }
      final icono = _icono(v(f, 'Icono'));
      if (icono == null && v(f, 'Icono').isNotEmpty) aviso('el icono «${v(f, 'Icono')}» no existe; va el de máquina.');
      final horas = v(f, 'Horas contador'), uso = v(f, 'Horas al día');
      if (horas.isNotEmpty && _numero(horas) == null) aviso('«$horas» no es un número de horas.');
      if (uso.isNotEmpty && _numero(uso) == null) aviso('«$uso» no es un número de horas al día.');
      a = Activo(
        id: s.nuevoId(),
        icono: icono ?? 'fabrica',
        tag: tag,
        nombre: nombre,
        descripcion: v(f, 'Descripción'),
        fabricante: v(f, 'Fabricante'),
        modelo: v(f, 'Modelo'),
        numeroSerie: v(f, 'Número de serie'),
        division: v(f, 'División'),
        horas: _numero(horas) ?? 0,
        horasUso: _numero(uso) ?? 0,
      );
      porTag[clave] = a;
      nuevos[clave] = (a, n, v(f, 'Padre'));
      imp.activos.add(a);
    } else if (!nuevos.containsKey(clave) && filasValidas.every((x) => x.$3 != a)) {
      // Ya estaba en Pultec: no se toca, pero sus mantenimientos nuevos sí entran.
      imp.duplicados++;
    }
    filasValidas.add((n, f, a));
  }

  // 2.ª pasada: cada componente a su padre (del archivo o de Pultec), sin bucles.
  for (final (a, n, padre) in nuevos.values) {
    if (padre.isEmpty) continue;
    final p = porTag[normalizar(padre)];
    if (p == null) {
      imp.avisos.add('Fila ${n + 1}: no hay ningún activo con tag «$padre»; ${a.tag} queda como activo principal.');
    } else if (p == a) {
      imp.avisos.add('Fila ${n + 1}: ${a.tag} no puede ser su propio padre.');
    } else {
      a.padreId = p.id;
    }
  }
  final porId = {
    for (final a in [...s.activos, ...imp.activos]) a.id: a,
  };
  for (final a in imp.activos) {
    final vistos = <String>{a.id};
    for (var x = porId[a.padreId]; x != null; x = porId[x.padreId]) {
      if (!vistos.add(x.id)) {
        imp.avisos.add('${a.tag}: su padre forma un bucle; queda como activo principal.');
        a.padreId = null;
        break;
      }
    }
  }
  Activo raiz(Activo a) {
    var r = a;
    for (var i = 0; i < 50 && porId[r.padreId] != null; i++) {
      r = porId[r.padreId]!;
    }
    return r;
  }

  // 3.ª pasada: los mantenimientos de cada fila.
  for (final (n, f, a) in filasValidas) {
    final nombre = v(f, 'Mantenimiento');
    if (nombre.isEmpty) continue;
    void aviso(String texto) => imp.avisos.add('Fila ${n + 1}: $texto');
    final ya = [
      ...s.planes,
      ...imp.planes,
    ].any((p) => p.activoId == a.id && normalizar(p.nombre) == normalizar(nombre));
    if (ya) {
      imp.duplicados++;
      continue;
    }
    final cada = v(f, 'Cada'), cadaH = v(f, 'Cada horas');
    final dias = cada.isEmpty ? null : leerCadaDias(cada);
    if (cada.isNotEmpty && dias == null) aviso('no se entiende «$cada» en «Cada» (usa 30, 2 semanas, 6 meses, 1 año).');
    final horas = cadaH.isEmpty ? null : _numero(cadaH)?.round();
    if (cadaH.isNotEmpty && (horas == null || horas <= 0)) aviso('«$cadaH» no es un número de horas.');
    DateTime? fecha(String columna) {
      final x = v(f, columna);
      if (x.isEmpty) return null;
      final d = leerFecha(x);
      if (d == null) aviso('fecha «$x» de «$columna» no válida (usa dd/mm/aaaa).');
      return d;
    }

    final proxima = fecha('Próxima fecha'), ultima = fecha('Última vez');
    if (dias == null && (horas == null || horas <= 0) && proxima == null) {
      aviso('«$nombre» sin «Cada», «Cada horas» ni «Próxima fecha»; no se importa el mantenimiento.');
      continue;
    }
    final prioridad = v(f, 'Prioridad');
    final pr = prioridad.isEmpty
        ? PrioridadMantenimiento.normal
        : PrioridadMantenimiento.values.where((p) => normalizar(p.etiqueta) == normalizar(prioridad)).firstOrNull ??
              (normalizar(prioridad) == 'critica' ? PrioridadMantenimiento.critica : null);
    if (pr == null) aviso('prioridad «$prioridad» desconocida; va como Normal.');
    final esp = v(f, 'Especialidad');
    final categoria = competencias.where((c) => normalizar(c) == normalizar(esp)).firstOrNull;
    if (esp.isNotEmpty && categoria == null) aviso('la especialidad «$esp» no existe; añádela en Ajustes.');
    final tec = normalizar(v(f, 'Técnico'));
    final w = tec.isEmpty
        ? null
        : s.trabajadores
              .where(
                (w) => normalizar(w.nombreCompleto) == tec || normalizar(w.email) == tec || normalizar(w.nombre) == tec,
              )
              .firstOrNull;
    if (tec.isNotEmpty && w == null) aviso('no hay ningún técnico «${v(f, 'Técnico')}»; queda sin asignar.');
    final hUltima = v(f, 'Horas última vez');
    final duracion = int.tryParse(v(f, 'Duración (min)'));
    final conHoras = horas != null && horas > 0;
    imp.planes.add(
      PlanMantenimiento(
        id: s.nuevoId(),
        activoId: a.id,
        nombre: nombre,
        descripcion: v(f, 'Descripción del mantenimiento'),
        prioridad: pr ?? PrioridadMantenimiento.normal,
        cadaDias: dias,
        cadaHoras: conHoras ? horas : null,
        // Fecha fija solo si no se repite por tiempo ni por horas (como «Fecha» en el formulario).
        proximo: dias == null && !conHoras ? proxima : null,
        ultimo: ultima,
        // Por horas sin dato: cuenta desde las horas de hoy (si no, tocaría ya), como en el formulario.
        ultimoHoras: _numero(hUltima) ?? (conHoras ? raiz(a).horas : null),
        categoria: categoria ?? '',
        trabajadorId: w?.id,
        duracionMin: duracion == null || duracion <= 0 ? 60 : duracion,
      ),
    );
  }
}

/// Plantilla para rellenar: la cabecera y una fila de ejemplo.
String plantillaCsv(QueImportar que) => escribirCsv([que.columnas, ...que.ejemplos]);

/// Guía de formato en texto, para descargarla junto a la plantilla.
String guiaTexto(QueImportar que) => [
  'Cómo rellenar el CSV de ${que.etiqueta.toLowerCase()} para importarlo en ${m('Pultec')}',
  '',
  'Guarda el Excel como CSV (separado por punto y coma, comas o tabuladores: se detecta solo).',
  'La primera fila son los nombres de las columnas; el orden da igual y las que no uses pueden faltar.',
  if (que == QueImportar.activos) ...[
    'Una fila por activo o componente. Para darle varios mantenimientos, repite su tag en otra fila.',
    'Al importar, cada mantenimiento sale ya con su orden de trabajo en la fecha que le toca.',
  ],
  '',
  for (final (c, texto) in que.guia) texto.isEmpty ? '- $c' : '- $c: $texto',
].join('\n');

String _horas(double h) => h == h.roundToDouble() ? '${h.round()}' : '$h';

/// Pultec: activos y componentes (padres antes que hijos), una fila por mantenimiento; sin ellos, una por activo.
List<List<String>> _filasActivos(Store s) {
  final porId = {for (final a in s.activos) a.id: a};
  final filas = <List<String>>[];
  void fila(Activo a) {
    final padre = porId[a.padreId]?.tag ?? '';
    final datos = [
      a.tag,
      a.nombre,
      padre,
      a.icono,
      a.descripcion,
      a.fabricante,
      a.modelo,
      a.numeroSerie,
      a.division,
      a.padreId == null ? _horas(a.horas) : '',
      a.padreId == null && a.horasUso > 0 ? _horas(a.usoDiario) : '',
    ];
    final ps = s.planesDe(a.id);
    if (ps.isEmpty) filas.add([...datos, ...List.filled(11, '')]);
    for (final p in ps) {
      filas.add([
        ...datos,
        p.nombre,
        p.descripcion,
        p.prioridad.etiqueta,
        p.cadaDias == null ? '' : '${p.cadaDias} días',
        p.cadaHoras == null ? '' : '${p.cadaHoras}',
        p.cadaDias == null && p.cadaHoras == null ? _fecha(p.proximo) : '',
        _fecha(p.ultimo),
        p.ultimoHoras == null ? '' : _horas(p.ultimoHoras!),
        p.categoria,
        p.trabajadorId == null ? '' : s.trabajador(p.trabajadorId!)?.nombreCompleto ?? '',
        '${p.duracionMin}',
      ]);
    }
    for (final h in s.activos.where((x) => x.padreId == a.id)) {
      fila(h);
    }
  }

  for (final a in s.activos.where((a) => porId[a.padreId] == null)) {
    fila(a);
  }
  return filas;
}

String exportarCsv(QueImportar que, Store s) => escribirCsv([
  que.columnas,
  ...switch (que) {
    QueImportar.activos => _filasActivos(s),
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
