import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../screens/importar_exportar.dart' show Exportable, abrirExportar;
import '../store.dart';
import '../theme.dart';
import '../ajustes.dart' show ajustes;
import '../widgets.dart';
import '../marca.dart' show Marca;
import '../screens/vista_dias.dart' show meses, diasSemana, lunesDe;
import 'activo.dart';
import 'activos.dart' show abrirActivoForm;
import 'iconos.dart';
import 'plan.dart';
import 'planes.dart'
    show
        turnosDe,
        turnosPatron,
        esExcepcion,
        ponerTurnos,
        volverAlPatron,
        raizActivo,
        reprogramarOts;

/// Pide a la barra lateral que vaya a «Uso de activos» (desde el botón de Activos).
final pedirUsoActivos = ValueNotifier<int>(0);

/// Abre el calendario de uso de las máquinas en su propia pantalla, con flecha para volver.
Future<void> abrirUsoMaquinas(BuildContext context) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => const Scaffold(body: SafeArea(child: UsoMaquinas(conVolver: true))),
  ),
);

/// Activos principales con uso «Planificado por turnos»: los que salen en el calendario de uso.
List<Activo> activosPorTurnos() =>
    store.hijosDe(null).where((a) => a.activo && a.usoPlanificado).toList()
      ..sort((a, b) => a.titulo.compareTo(b.titulo));

/// Uso de [activos] en [dias] en texto: una fila por activo con sus turnos de cada día (vacío = no trabaja) y el
/// total de horas. Cabecera primero (el número de cada día). Para exportar o imprimir el mes.
List<List<String>> usoEnTexto(List<Activo> activos, List<DateTime> dias) => [
  ['Activo', for (final d in dias) '${d.day}', 'Horas'],
  for (final a in activos)
    [
      a.titulo,
      for (final d in dias) turnosDe(a, d) == 0 ? '' : '${turnosDe(a, d)}',
      '${(dias.fold<int>(0, (t, d) => t + turnosDe(a, d)) * a.horasTurno).round()}',
    ],
];

/// Cuántos turnos caben en un día con las horas por turno de la máquina (de 1 a 3).
int maxTurnos(Activo a) => a.horasTurno <= 0 ? 3 : (24 / a.horasTurno).floor().clamp(1, 3);

const _letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

String _turnos(int n) => '$n ${n == 1 ? 'turno' : 'turnos'}';

/// Parte del día (24 h) que ocupan [n] turnos de la máquina: 1 turno de 8 h, un tercio; 3, lleno.
double _fraccion(Activo a, int n) => (n * a.horasTurno / 24).clamp(0, 1).toDouble();

/// El patrón semanal en pocas palabras: «L–V · 1 turno», «L–S · 2 turnos», «L1 M1 X2…» o «Sin patrón».
String resumenPatron(Activo a) {
  final p = a.patron;
  if (p.length != 7 || p.every((x) => x == 0)) return 'Sin patrón';
  final n = p.first;
  if (n > 0 && p.take(5).every((x) => x == n) && p[5] == 0 && p[6] == 0) return 'L–V · ${_turnos(n)}';
  if (n > 0 && p.take(6).every((x) => x == n) && p[6] == 0) return 'L–S · ${_turnos(n)}';
  if (n > 0 && p.every((x) => x == n)) return 'Todos los días · ${_turnos(n)}';
  return [
    for (var i = 0; i < 7; i++)
      if (p[i] > 0) '${_letras[i]}${p[i]}',
  ].join(' ');
}

/// Pone el patrón semanal de una máquina y quita las excepciones que ya coinciden con él.
void ponerPatron(Activo a, List<int> patron) {
  a.patron = patron.every((x) => x == 0) ? [] : [...patron];
  a.turnos.removeWhere((k, v) => v == turnosPatron(a, DateTime.parse(k)));
}

/// Editor del patrón semanal: un cuadro por día (lunes a domingo); tocarlo suma un turno (y vuelve a 0 tras el
/// máximo). Debajo, atajos: laborables con 1 o 2 turnos y quitar el patrón.
class EditorPatron extends StatelessWidget {
  final List<int> patron;
  final int maximo;
  final Color? color;
  final ValueChanged<List<int>> onChanged;
  const EditorPatron({super.key, required this.patron, required this.onChanged, this.maximo = 3, this.color});

  Color get _color => color ?? P.morado;

  List<int> get _p => patron.length == 7 ? patron : List.filled(7, 0);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Tooltip(
                message: '${diasSemana[i]}: ${_turnos(_p[i])}. Toca para cambiar',
                child: InkWell(
                  borderRadius: BorderRadius.circular(P.radioControl),
                  onTap: () => onChanged([for (var k = 0; k < 7; k++) k == i ? (_p[k] + 1) % (maximo + 1) : _p[k]]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 52,
                    decoration: BoxDecoration(
                      color: _p[i] == 0 ? P.superficie : _color.withValues(alpha: const [0.0, .14, .4, .75][_p[i]]),
                      borderRadius: BorderRadius.circular(P.radioControl),
                      border: Border.all(color: _p[i] == 0 ? P.borde : _color.withValues(alpha: .5)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _letras[i],
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: P.textoSuave),
                        ),
                        Text(
                          _p[i] == 0 ? '–' : '${_p[i]}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _p[i] >= 3 ? Colors.white : P.texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 4,
        children: [
          TextButton(onPressed: () => onChanged([1, 1, 1, 1, 1, 0, 0]), child: const Text('L–V · 1 turno')),
          if (maximo >= 2)
            TextButton(onPressed: () => onChanged([2, 2, 2, 2, 2, 0, 0]), child: const Text('L–V · 2 turnos')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: P.textoSuave),
            onPressed: () => onChanged(List.filled(7, 0)),
            child: const Text('Sin patrón'),
          ),
        ],
      ),
    ],
  );
}

/// Ventana para cambiar el patrón semanal de una máquina (se puede deshacer).
Future<void> abrirPatron(BuildContext context, Activo a, Color color) async {
  var p = a.patron.length == 7 ? [...a.patron] : List.filled(7, 0);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
          child: StatefulBuilder(
            builder: (c, set) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Patrón semanal',
                  style: TextStyle(fontFamily: P.titulos, fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${a.titulo}. Se repite cada semana; en el calendario solo marcas las excepciones. '
                  'Los festivos de la planta no trabajan.',
                  style: TextStyle(fontSize: 13, color: P.textoSuave),
                ),
                const SizedBox(height: 16),
                EditorPatron(patron: p, maximo: maxTurnos(a), color: color, onChanged: (v) => set(() => p = v)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (ok != true) return;
  final antes = _fechasOts([a]);
  store.deshacible('${a.tag.isEmpty ? a.nombre : a.tag}: patrón ${resumenPatron(Activo(id: '', patron: p))}', () {
    ponerPatron(a, p);
    store.guardarActivo(a);
    reprogramarOts(a);
  }, aviso: false);
  if (context.mounted) _avisarOts(context, antes);
}

/// OT abierta de cada mantenimiento de estas máquinas (y de sus componentes): su fecha antes de un cambio.
Map<String, DateTime?> _fechasOts(Iterable<Activo> activos) {
  final ids = {for (final a in activos) a.id};
  return {
    for (final p in store.planes.where((p) => p.activa && ids.contains(raizActivo(p.activoId)?.id))) p.id: _fechaOt(p.id),
  };
}

DateTime? _fechaOt(String planId) =>
    store.tareas.where((t) => t.planId == planId && t.activa && t.estado.abierta).firstOrNull?.proximo;

String _diaMes(DateTime d) => '${d.day} ${meses[d.month - 1].substring(0, 3).toLowerCase()}';

/// Tras cambiar el uso, qué órdenes de trabajo han cambiado de fecha (o se han creado): «Engrase pasa del 12 dic
/// al 15 dic». [abajo] lo sube por encima de la barra de selección.
void _avisarOts(BuildContext context, Map<String, DateTime?> antes, {double abajo = 16}) {
  final cambios = <String>[];
  for (final e in antes.entries) {
    final p = store.planes.where((p) => p.id == e.key).firstOrNull;
    final ahora = _fechaOt(e.key);
    if (p == null || ahora == null || (e.value != null && DateUtils.isSameDay(e.value, ahora))) continue;
    final esHoy = !ahora.isAfter(hoy());
    cambios.add(
      e.value == null
          ? '${p.nombre}: orden nueva para ${esHoy ? 'hoy' : 'el ${_diaMes(ahora)}'}'
          : '${p.nombre} pasa del ${_diaMes(e.value!)} ${esHoy ? 'a hoy' : 'al ${_diaMes(ahora)}'}',
    );
  }
  if (cambios.isEmpty) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        margin: EdgeInsets.fromLTRB(16, 0, 16, abajo),
        content: Text(
          cambios.length <= 3 ? cambios.join('\n') : '${cambios.take(3).join('\n')}\ny ${cambios.length - 3} más',
        ),
      ),
    );
}

/// Un mantenimiento en su día del calendario: de qué máquina, cuál y si la fecha es estimada por horas.
typedef _Marca = ({Activo activo, PlanMantenimiento plan, bool estimada});

/// Calendario de uso de las máquinas por turnos. Dos vistas: el mes en cuadrícula o una fila por máquina.
///
/// · Cada máquina tiene su patrón semanal (se repite solo); en el calendario se marcan las excepciones.
/// · Se seleccionan días (tocándolos, arrastrando o por la cabecera del día de la semana) y al
///   tocar una máquina salen sus opciones para esos días (turnos, su patrón o parada). También se marcan como
///   festivos.
/// · Se ve en su día cada mantenimiento (≈ si la fecha es estimada por horas).
/// · Cambiar días pasados pide confirmación: altera las horas estimadas del contador.
/// · Tras cada cambio se avisa de las órdenes de trabajo que cambian de fecha (sin aviso de «Deshacer»).
class UsoMaquinas extends StatefulWidget {
  /// En su propia pantalla (no como sección de la barra lateral): con flecha para volver.
  final bool conVolver;
  const UsoMaquinas({super.key, this.conVolver = false});

  @override
  State<UsoMaquinas> createState() => _UsoMaquinasState();
}

class _UsoMaquinasState extends State<UsoMaquinas> {
  DateTime mes = DateTime(hoy().year, hoy().month);

  /// 0 = mes en cuadrícula; 1 = una fila por máquina.
  int _vista = 0;

  /// Días seleccionados. Con alguno, tocar una máquina saca sus opciones para esos días.
  final _sel = <DateTime>{};
  DateTime? _ultimoSel;

  /// Máquina elegida en el panel: el mes muestra solo la suya (null = todas, un punto por máquina en cada día).
  /// Activos elegidos en la lista: el mes muestra solo los suyos, una línea por activo (vacío = todos, en puntos).
  final _elegidas = <String>{};
  bool _visible(Activo a) => _elegidas.isEmpty || _elegidas.contains(a.id);

  /// Lista de activos a la izquierda, que se abre y cierra con el botón del activo que se ve, bajo el título.
  /// En un [ValueNotifier]: abrirla o cerrarla solo anima el panel y la flecha, sin reconstruir el calendario.
  final _panel = ValueNotifier(false);

  void _alternarPanel() => _panel.value = !_panel.value;

  @override
  void dispose() {
    _panel.dispose();
    super.dispose();
  }

  /// Selección arrastrando: desde qué día y qué había seleccionado antes.
  DateTime? _desde;
  Set<DateTime> _antes = {};

  /// Ya se aceptó cambiar días pasados (no se vuelve a preguntar en esta visita).
  bool _pasadoOk = false;

  // ── Fechas ──

  Iterable<DateTime> get _diasMes sync* {
    for (var d = DateTime(mes.year, mes.month); d.month == mes.month; d = masDias(d, 1)) {
      yield d;
    }
  }

  String get _nombreMes => meses[mes.month - 1].toLowerCase();
  String _dias(int n) => '$n ${n == 1 ? 'día' : 'días'}';
  bool _laborable(DateTime d) => d.weekday <= 5 && store.festivo(d) == null;

  Color _colorDe(int i) => paletaActivos[i % paletaActivos.length];
  String _quien(Activo a) => a.tag.isEmpty ? a.nombre : a.tag;

  double _horas(Activo a, Iterable<DateTime> dias) => dias.fold(0, (t, d) => t + turnosDe(a, d)) * a.horasTurno;

  /// Mantenimientos de cada máquina (y de sus componentes) por día, en el rango que se ve.
  // Solo los que ya tienen su orden de trabajo generada (abierta), en la fecha de esa OT: así se ve aquí cuándo
  // cae cada mantenimiento de verdad. Sin OT, no sale.
  Map<DateTime, List<_Marca>> _marcas(List<Activo> activos, DateTime desde, DateTime hasta) {
    final out = <DateTime, List<_Marca>>{};
    final ids = {for (final a in activos) a.id: a};
    for (final p in store.planes.where((p) => p.activa)) {
      final a = ids[raizActivo(p.activoId)?.id];
      if (a == null) continue;
      final d = _fechaOt(p.id);
      if (d == null || d.isBefore(desde) || d.isAfter(hasta)) continue;
      (out[DateUtils.dateOnly(d)] ??= []).add((activo: a, plan: p, estimada: p.proximo == null && p.cadaHoras != null));
    }
    return out;
  }

  // ── Selección ──

  void _tocarDia(DateTime d) => setState(() {
    final ultimo = _ultimoSel;
    if (HardwareKeyboard.instance.isShiftPressed && ultimo != null) {
      final (a, b) = ultimo.isBefore(d) ? (ultimo, d) : (d, ultimo);
      for (var x = a; !x.isAfter(b); x = masDias(x, 1)) {
        _sel.add(x);
      }
    } else if (!_sel.remove(d)) {
      _sel.add(d);
    }
    _ultimoSel = d;
  });

  /// Añade estos días a la selección o, si ya estaban todos, los quita.
  void _alternar(Iterable<DateTime> dias) => setState(() {
    final l = dias.toList();
    if (l.every(_sel.contains)) {
      _sel.removeAll(l);
    } else {
      _sel.addAll(l);
    }
  });

  void _deseleccionar() => setState(() {
    _sel.clear();
    _ultimoSel = null;
  });

  void _arrastrar(DateTime d) => setState(() {
    final desde = _desde ?? d;
    final (a, b) = desde.isBefore(d) ? (desde, d) : (d, desde);
    _sel
      ..clear()
      ..addAll(_antes);
    for (var x = a; !x.isAfter(b); x = masDias(x, 1)) {
      _sel.add(x);
    }
  });

  // ── Cambios ──

  /// Cambiar días pasados altera las horas estimadas del contador: se confirma una vez por visita.
  Future<bool> _confirmarPasado(Iterable<DateTime> dias) async {
    if (_pasadoOk || !dias.any((d) => d.isBefore(hoy()))) return true;
    final ok = await confirmar(
      context,
      '¿Cambiar días que ya han pasado?',
      accion: 'Cambiar',
      icono: Icons.history_rounded,
      destructivo: false,
      nota:
          'Cambia las horas estimadas del contador y recalcula las fechas de sus mantenimientos. '
          'La última lectura real se conserva.',
    );
    if (ok) _pasadoOk = true;
    return ok;
  }

  /// Hace un cambio de turnos tras confirmar si toca días pasados y avisa de las OT que cambian de fecha.
  /// Queda en el historial, pero sin aviso de «Deshacer».
  Future<void> _cambiar(String texto, Iterable<DateTime> dias, Iterable<Activo> activos, void Function() cambio) async {
    if (!await _confirmarPasado(dias)) return;
    final antes = _fechasOts(activos);
    store.deshacible(texto, () {
      cambio();
      for (final a in activos) {
        store.guardarActivo(a);
        // Sus OT por horas, a la nueva fecha.
        reprogramarOts(a);
      }
    }, aviso: false);
    if (!mounted) return;
    setState(() {});
    _avisarOts(context, antes, abajo: _abajoAviso);
  }

  /// Con días seleccionados, los avisos salen por encima de la barra de selección.
  double get _abajoAviso => _sel.isEmpty ? 16 : 92;

  Future<void> _poner(Activo a, DateTime d, int n) => _cambiar(
    n == 0 ? '${_quien(a)}: sin turno el ${d.day}' : '${_quien(a)}: ${_turnos(n)} el ${d.day}',
    [d],
    [a],
    () => ponerTurnos(a, d, n.clamp(0, maxTurnos(a))),
  );

  /// Opción de una máquina para los días seleccionados: «sel1»…«sel3» turnos, «sel0» parada o «selPatron».
  Future<void> _aplicarSel(Activo a, String accion) {
    final dias = _sel.toList();
    if (accion == 'selPatron') {
      return _cambiar('${_quien(a)}: su patrón en ${_dias(dias.length)}', dias, [a], () {
        for (final d in dias) {
          volverAlPatron(a, d);
        }
      });
    }
    final n = int.parse(accion.substring(3)).clamp(0, maxTurnos(a));
    return _cambiar(
      n == 0
          ? '${_quien(a)}: parada en ${_dias(dias.length)}'
          : '${_quien(a)}: ${_turnos(n)} en ${_dias(dias.length)}',
      dias,
      [a],
      () {
        for (final d in dias) {
          ponerTurnos(a, d, n);
        }
      },
    );
  }

  Future<void> _vaciarSel(List<Activo> activos) => _cambiar(
    '${activos.length == 1 ? '${_quien(activos.first)}: s' : 'S'}in turnos en ${_dias(_sel.length)}',
    _sel,
    activos,
    () {
      for (final a in activos) {
        for (final d in _sel) {
          ponerTurnos(a, d, 0);
        }
      }
    },
  );

  /// Acciones de una máquina: con días seleccionados, las de esos días; si no, editarla, su patrón y rellenar
  /// el mes.
  void _accion(Activo a, Color color, String accion) {
    if (accion.startsWith('sel')) {
      _aplicarSel(a, accion);
      return;
    }
    final q = _quien(a);
    final dias = _diasMes.toList();
    Future<void> rellenar(String texto, int Function(DateTime d) n) => _cambiar(texto, dias, [a], () {
      for (final d in dias) {
        ponerTurnos(a, d, n(d).clamp(0, maxTurnos(a)));
      }
    });
    switch (accion) {
      case 'editar':
        abrirActivoForm(context, original: a);
      case 'patron':
        abrirPatron(context, a, color).then((_) => mounted ? setState(() {}) : null);
      case 'lab1' || 'lab2' || 'lab3':
        final n = int.parse(accion.substring(3));
        rellenar('$q: ${_turnos(n)} los laborables de $_nombreMes', (d) => _laborable(d) ? n : 0);
      case 'todos1':
        rellenar('$q: 1 turno todos los días de $_nombreMes', (_) => 1);
      case 'copiar':
        // Cuatro semanas antes (cinco al final del mes): cada día cae en el mismo día de la semana.
        rellenar('$q: $_nombreMes como el mes anterior', (d) {
          final cuatro = masDias(d, -28);
          return turnosDe(a, cuatro.month != mes.month ? cuatro : masDias(d, -35));
        });
      case 'patronMes':
        _cambiar('$q: $_nombreMes según su patrón', dias, [a], () {
          for (final d in dias) {
            volverAlPatron(a, d);
          }
        });
      case 'vaciar':
        rellenar('$q: sin turnos en $_nombreMes', (_) => 0);
    }
  }

  /// Opciones del turno de un día: cuántos turnos, igual toda la semana, volver al patrón o quitarlo.
  void _accionDia(Activo a, DateTime d, String accion) {
    switch (accion) {
      case 'semana':
        final n = turnosDe(a, d);
        final semana = [for (var i = 0; i < 5; i++) masDias(lunesDe(d), i)];
        _cambiar('${_quien(a)}: ${_turnos(n)} de lunes a viernes', semana, [a], () {
          for (final x in semana) {
            ponerTurnos(a, x, n);
          }
        });
      case 'patron':
        _cambiar('${_quien(a)}: el ${d.day} según su patrón', [d], [a], () => volverAlPatron(a, d));
      default:
        _poner(a, d, int.parse(accion));
    }
  }

  List<(String, Widget)> _opcionesDia(Activo a, DateTime d) => [
    for (var k = 1; k <= maxTurnos(a); k++) ('$k', Text('${_turnos(k)} · ${(k * a.horasTurno).toStringAsFixed(0)} h')),
    ('semana', const Text('Igual de lunes a viernes')),
    if (esExcepcion(a, d)) ('patron', Text('Volver al patrón (${_turnos(turnosPatron(a, d))})')),
    ('0', Text('Quitar', style: TextStyle(color: P.rojo))),
  ];

  // ── Vista ──

  @override
  Widget build(BuildContext context) {
    final activos = activosPorTurnos();
    final conSel = _sel.isNotEmpty && activos.isNotEmpty;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _deseleccionar},
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: margenPagina,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cabecera(),
                    const SizedBox(height: 10),
                    // El consejo solo ocupa sitio (con su hueco) mientras no se cierra.
                    ListenableBuilder(
                      listenable: ajustes,
                      builder: (context, _) => ajustes.consejoCerrado(_claveConsejo)
                          ? const SizedBox.shrink()
                          : const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Consejo(
                                'Cada máquina tiene su patrón semanal; aquí marcas las excepciones. Selecciona días '
                                '(tocando, arrastrando o por el día de la semana) y toca una máquina para elegir qué '
                                'hace esos días.',
                                clave: _claveConsejo,
                              ),
                            ),
                    ),
                    // Debajo del título: el activo que se ve (o todos); abre y cierra la lista de activos.
                    if (activos.isNotEmpty) ...[
                      SizedBox(
                        height: 40,
                        child: Row(children: [if (_vista == 0) _botonActivos(activos), const Spacer(), const _Leyenda()]),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (activos.isEmpty)
                      const Expanded(
                        child: Vacio(
                          icono: Icons.event_note_outlined,
                          titulo: 'Ninguna máquina por turnos',
                          texto: 'Elige «Planificado por turnos» en los datos de un activo (Contador y uso) y aparecerá aquí.',
                        ),
                      )
                    else ...[
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Lista de activos a la izquierda, dentro de la vista: se pliega deslizándose (ancho 0).
                            // Lista de activos: su hueco crece y el calendario se recoloca en cada fotograma sin
                            // reconstruirse (SegunTamano). En «Por máquina» no hace falta: las filas ya son los activos.
                            if (_vista == 0)
                              ValueListenableBuilder(
                                valueListenable: _panel,
                                builder: (context, abierto, hijo) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  width: abierto ? _anchoPanel + 10 : 0,
                                  child: hijo,
                                ),
                                child: ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.centerLeft,
                                    minWidth: _anchoPanel + 10,
                                    maxWidth: _anchoPanel + 10,
                                    child: RepaintBoundary(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: _Maquinas(
                                      activos: activos,
                                      colorDe: _colorDe,
                                      horasMes: (a) => _horas(a, _diasMes),
                                      onAccion: _accion,
                                      diasSel: _sel.isEmpty ? null : _dias(_sel.length),
                                      elegidas: _elegidas,
                                      // Tocar un activo abre su mes (también desde «Por máquina»); otra vez, todos.
                                      onElegir: (a) => setState(() {
                                        // Tocar uno lo añade o lo quita; «Todos los activos», ninguno.
                                        if (a == null) {
                                          _elegidas.clear();
                                        } else if (!_elegidas.remove(a.id)) {
                                          _elegidas.add(a.id);
                                        }
                                        _vista = 0;
                                      }),
                                      onCerrar: _alternarPanel,
                                    ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Mes y Por máquina con un fundido corto al cambiar de pestaña.
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                layoutBuilder: (actual, previos) =>
                                    Stack(fit: StackFit.expand, children: [...previos, ?actual]),
                                child: KeyedSubtree(
                                  key: ValueKey(_vista),
                                  child: _vista == 0 ? _calendario(activos) : _porMaquina(activos),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Abajo en el centro, encima de todo (no mueve el calendario): la barra de selección de las listas.
            // Sin pisar la campana de avisos (abajo a la derecha); si no cabe, se encoge en vez de cortarse.
            if (conSel)
              Positioned(
                left: 96,
                right: 96,
                bottom: 24,
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: _barraSeleccion(activos)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _claveConsejo = 'uso-activos-5';

  /// El activo que se ve (o todos), del mismo ancho que la lista y con el color del activo: abre y cierra la lista.
  Widget _botonActivos(List<Activo> activos) {
    final i = _elegidas.length == 1 ? activos.indexWhere((x) => x.id == _elegidas.first) : -1;
    final a = i < 0 ? null : activos[i];
    final color = a == null ? P.textoSuave : _colorDe(i);
    return ValueListenableBuilder(
      valueListenable: _panel,
      builder: (context, abierto, _) => Tooltip(
      message: abierto ? 'Ocultar la lista de activos' : 'Ver la lista de activos',
      child: Material(
        color: a == null ? P.superficie : Color.alphaBlend(color.withValues(alpha: .08), P.superficie),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(P.radioControl),
          side: BorderSide(color: a == null ? P.borde : color.withValues(alpha: .45)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(P.radioControl),
          hoverColor: P.hover,
          onTap: _alternarPanel,
          child: SizedBox(
            width: _anchoPanel,
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  a == null
                      ? Icon(Marca.iconoCliente, size: 17, color: color)
                      : IconoActivo(a.icono, size: 17, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a != null
                          ? (a.nombre.isEmpty ? a.tag : a.nombre)
                          : _elegidas.isEmpty
                          ? 'Todos los activos'
                          : '${_elegidas.length} activos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (a != null && a.tag.isNotEmpty && a.nombre.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(a.tag, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: abierto ? .5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, size: 18, color: P.textoSuave),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _cabecera() => BarraVista(
    izquierda: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.conVolver) ...[
            IconButton(
              tooltip: 'Volver a Activos',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 6),
          ],
          const Flexible(child: TituloVista('Uso de activos')),
        ],
      ),
    ],
    derecha: [
      Pestanas(
        opciones: const ['Mes', 'Por máquina'],
        compactas: true,
        anchosIguales: false,
        seleccion: _vista,
        onChanged: (i) => setState(() => _vista = i),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: 'Mes anterior',
        onPressed: () => setState(() => mes = DateTime(mes.year, mes.month - 1)),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      SizedBox(
        width: 124,
        child: Text(
          '${meses[mes.month - 1]} ${mes.year}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      IconButton(
        tooltip: 'Mes siguiente',
        onPressed: () => setState(() => mes = DateTime(mes.year, mes.month + 1)),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
      const SizedBox(width: 4),
      // Exportar o imprimir el mes que se ve (los activos elegidos, o todos).
      BotonImportarExportar(
        soloExportar: true,
        tooltip: 'Exportar o imprimir el uso de este mes',
        onPressed: () => abrirExportar(
          context,
          Exportable(
            'Uso de activos, $_nombreMes ${mes.year}',
            () => usoEnTexto([for (final a in activosPorTurnos()) if (_visible(a)) a], _diasMes.toList()),
          ),
        ),
      ),
    ],
  );

  /// Barra de selección de días, como la de las listas: cuántos, todo el mes, vaciar los días y salir
  /// (también con Esc). Lo de cada máquina sale al tocarla.
  Widget _barraSeleccion(List<Activo> activos) {
    final delMes = _diasMes.toList();
    final elegidos = activos.where((a) => _elegidas.contains(a.id)).toList();
    return BarraSeleccion(
      seleccionados: _sel.length,
      total: delMes.length,
      nombre: 'días',
      textoEliminar: 'Quitar turnos',
      onTodos: () => _alternar(delMes),
      // Con activos elegidos, vacía solo los suyos, sin preguntar de cuál; con todos, el menú para elegir.
      onEliminar: () => _vaciarSel(elegidos.isEmpty ? activos : elegidos),
      eliminar: elegidos.isEmpty ? _menuVaciar(activos) : null,
      onSalir: _deseleccionar,
    );
  }

  /// «Quitar turnos» como menú: todas las máquinas o solo una de las que trabajan en los días elegidos.
  Widget _menuVaciar(List<Activo> activos) {
    int diasCon(Activo a) => _sel.where((d) => turnosDe(a, d) > 0).length;
    final con = [
      for (final (i, a) in activos.indexed)
        if (diasCon(a) > 0) (i, a),
    ];
    return BotonMenu<String>(
      tooltip: 'Quitar los turnos de los días elegidos',
      resaltarHover: false,
      relleno: EdgeInsets.zero,
      onSelected: (v) {
        if (v == '*') {
          _vaciarSel(activos);
          return;
        }
        final a = activos.firstWhere((x) => x.id == v);
        _cambiar('${_quien(a)}: sin turnos en ${_dias(_sel.length)}', _sel, [a], () {
          for (final d in _sel) {
            ponerTurnos(a, d, 0);
          }
        });
      },
      opciones: [
        ('*', const Text('Todos los activos')),
        for (final (i, a) in con)
          (
            a.id,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _colorDe(i), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(a.titulo, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                Text(_dias(diasCon(a)), style: TextStyle(color: P.textoSuave, fontSize: 12.5)),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
        decoration: BoxDecoration(color: P.rojo, borderRadius: BorderRadius.circular(P.radioControl)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Quitar turnos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ── Mes en cuadrícula ──

  // Medidas de un día: cabecera (número), cada línea de turnos y cada mantenimiento. Con ellas, cada semana mide
  // lo que pida su día más lleno (y al menos lo que toque para llenar el alto): con muchas máquinas el
  // calendario crece y se desplaza en vertical en vez de amontonar los turnos.
  static const _altoBaseDia = 50.0,
      _altoTurno = 20.0,
      _altoMarca = 18.0,
      _altoCabecera = 26.0,
      _punto = 12.0,
      _puntoAlto = 7.0,
      _huecoPunto = 4.0,
      _anchoHoras = 64.0,
      _maxMarcasTodas = 3,
      _anchoPanel = 260.0;

  TextStyle get _estiloCabecera =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .6, color: P.textoSuave);

  /// Máquinas (visibles) que salen en un día: con turnos o con una parada que es excepción.
  int _enDia(List<Activo> activos, DateTime d) => activos.where(_visible).length;

  /// Alto de un día. Todas: las filas de puntos y hasta tres mantenimientos (más una línea «+N»). Una máquina:
  /// su pastilla y sus mantenimientos.
  double _altoDia(List<Activo> activos, DateTime d, int marcas, int puntosPorFila, bool todas) => todas
      ? _altoBaseDia +
            (activos.length / puntosPorFila).ceil() * (_puntoAlto + _huecoPunto) +
            (marcas > _maxMarcasTodas ? _maxMarcasTodas + 1 : marcas) * _altoMarca
      : _altoBaseDia + _enDia(activos, d) * (_altoTurno + 3) + marcas * _altoMarca;

  Widget _calendario(List<Activo> activos) {
    final inicio = lunesDe(mes);
    final fin = DateTime(mes.year, mes.month + 1, 0);
    final semanas = ((fin.difference(inicio).inDays + 1) / 7).ceil();
    final marcas = {
      for (final e in _marcas(activos, inicio, masDias(inicio, semanas * 7 - 1)).entries)
        e.key: [for (final m in e.value) if (_visible(m.activo)) m],
    };
    final todas = _elegidas.isEmpty;
    // Barritas por fila según el ancho útil de un día (menos márgenes y bordes).
    int porLineaDe(double ancho) =>
        (((ancho < 640 ? 640.0 : ancho) - _anchoHoras) / 7 - 22 + _huecoPunto) ~/ (_punto + _huecoPunto);
    // Solo se rehace si cambia lo que cambia la estructura (barritas por fila, alto o si cabe sin desplazar): al
    // abrir la lista de activos o cambiar el ancho de la ventana, el calendario solo se recoloca, sin reconstruirse.
    return SegunTamano(
      clave: (box) => (porLineaDe(box.maxWidth), box.maxHeight.round(), box.maxWidth < 640),
      builder: (context, box) {
        final estrecho = box.maxWidth < 640;
        const anchoTurno = double.infinity;
        final porLinea = porLineaDe(box.maxWidth).clamp(1, 40);
        final minimo = ((box.maxHeight - _altoCabecera) / semanas).clamp(90.0, double.infinity);
        final altos = [
          for (var s = 0; s < semanas; s++)
            [
              minimo,
              for (var i = 0; i < 7; i++)
                if (masDias(inicio, s * 7 + i) case final d)
                  _altoDia(activos, d, marcas[d]?.length ?? 0, porLinea, todas),
            ].reduce((x, y) => x > y ? x : y),
        ];
        final contenido = Column(
              children: [
                // Cabecera: tocar un día de la semana selecciona todos los de ese día del mes.
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _Pulsable(
                          tooltip: 'Seleccionar todos los ${diasSemana[i].toLowerCase()} del mes',
                          onTap: () => _alternar(_diasMes.where((d) => d.weekday == i + 1)),
                          child: SizedBox(
                            height: _altoCabecera,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 2, 4, 0),
                              child: Text(diasSemana[i].toUpperCase(), style: _estiloCabecera),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: _anchoHoras,
                      height: _altoCabecera,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('HORAS', textAlign: TextAlign.right, style: _estiloCabecera),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _rejilla(activos, inicio, altos, marcas, anchoTurno, todas, porLinea)),
                        // Horas de la semana: las de la máquina elegida o, con todas, la suma, con su icono.
                        SizedBox(
                          width: _anchoHoras,
                          child: Column(
                            children: [
                              for (var s = 0; s < altos.length; s++)
                                SizedBox(
                                  height: altos[s],
                                  child: _horasSemana(activos, [for (var i = 0; i < 7; i++) masDias(inicio, s * 7 + i)]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
        // En una ventana muy estrecha, el mes con su ancho mínimo y desplazable de lado.
        return estrecho
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: 640, height: box.maxHeight, child: contenido),
              )
            : contenido;
      },
    );
  }

  /// Clave de la selección de activos, para animar lo que cambia al elegir otros.
  String get _claveSel => _elegidas.join(',');

  /// Desde arriba de un día hasta su primera línea de turnos (margen, borde, relleno, número y hueco).
  static const _arribaLineas = 34.5;

  /// Horas de la semana, pegadas a la derecha. Con activos elegidos, las de cada uno con su icono, a la altura de
  /// su línea; con todos, la suma.
  Widget _horasSemana(List<Activo> activos, List<DateTime> dias) {
    // Primero el icono y luego las horas, en un hueco fijo alineado a la derecha: así los iconos quedan en
    // columna aunque cambien los dígitos.
    Widget linea(Widget icono, double h) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icono,
        SizedBox(
          width: 42,
          child: Text(
            '${h.toStringAsFixed(0)} h',
            maxLines: 1,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: h == 0 ? P.textoSuave : P.texto),
          ),
        ),
      ],
    );
    final hijo = _elegidas.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: linea(
              Icon(Marca.iconoCliente, size: 15, color: P.textoSuave),
              activos.fold(0.0, (t, x) => t + _horas(x, dias)),
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(top: _arribaLineas),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, a) in activos.indexed)
                  if (_visible(a))
                    SizedBox(
                      height: _altoTurno + 3,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: SizedBox(
                          height: _altoTurno,
                          child: linea(IconoActivo(a.icono, size: 14, color: _colorDe(i)), _horas(a, dias)),
                        ),
                      ),
                    ),
              ],
            ),
          );
    return Align(alignment: Alignment.topRight, child: _Aparece(clave: _claveSel, child: hijo));
  }

  /// La rejilla de días, con su borde redondeado encima (el fondo de las celdas no lo tapa) y la selección
  /// arrastrando por encima de los días. [altos]: el alto de cada semana.
  Widget _rejilla(
    List<Activo> activos,
    DateTime inicio,
    List<double> altos,
    Map<DateTime, List<_Marca>> marcas,
    double anchoTurno,
    bool todas,
    int puntosPorFila,
  ) => Builder(
    // Sin LayoutBuilder: el ancho se mira al arrastrar, así cambiarlo no reconstruye la rejilla.
    builder: (context) {
      DateTime diaEn(Offset p) {
        final ancho = (context.findRenderObject()! as RenderBox).size.width;
        final col = (p.dx / (ancho / 7)).floor().clamp(0, 6);
        var fila = 0;
        var y = p.dy;
        while (fila < altos.length - 1 && y >= altos[fila]) {
          y -= altos[fila];
          fila++;
        }
        return masDias(inicio, fila * 7 + col);
      }

      return GestureDetector(
        onPanStart: (e) {
          _desde = diaEn(e.localPosition);
          _antes = {..._sel};
          _arrastrar(_desde!);
        },
        onPanUpdate: (e) => _arrastrar(diaEn(e.localPosition)),
        onPanEnd: (_) => _desde = null,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(P.radio),
            border: Border.all(color: P.borde),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(P.radio),
            child: Column(
              children: [
                for (var s = 0; s < altos.length; s++)
                  SizedBox(
                    height: altos[s],
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: _dia(
                              masDias(inicio, s * 7 + i),
                              activos,
                              marcas[masDias(inicio, s * 7 + i)] ?? const [],
                              anchoTurno,
                              todas: todas,
                              puntosPorFila: puntosPorFila,
                              derecha: i < 6,
                              abajo: s < altos.length - 1,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _dia(
    DateTime d,
    List<Activo> activos,
    List<_Marca> marcas,
    double anchoTurno, {
    bool todas = false,
    int puntosPorFila = 10,
    bool derecha = true,
    bool abajo = true,
  }) {
    final delMes = d.month == mes.month;
    final esHoy = DateUtils.isSameDay(d, hoy());
    final pasado = d.isBefore(hoy());
    final festivo = store.festivo(d);
    final elegido = _sel.contains(d);
    return DragTarget<String>(
      onAcceptWithDetails: (det) {
        final a = store.activo(det.data);
        if (a == null) return;
        // Soltada en un día seleccionado: un turno en todos los seleccionados.
        if (elegido) {
          _aplicarSel(a, 'sel1');
        } else if (turnosDe(a, d) == 0) {
          _poner(a, d, 1);
        }
      },
      builder: (context, encima, _) => Container(
        decoration: BoxDecoration(
          color: !delMes
              ? P.fondo
              : festivo != null
              ? Color.alphaBlend(P.rojo.withValues(alpha: .035), P.superficie)
              : d.weekday >= 6
              ? Color.alphaBlend(P.fondo.withValues(alpha: .6), P.superficie)
              : P.superficie,
          border: Border(
            right: derecha ? BorderSide(color: P.borde) : BorderSide.none,
            bottom: abajo ? BorderSide(color: P.borde) : BorderSide.none,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _tocarDia(d),
            hoverColor: P.hover,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              // Elegido (o con una máquina encima): un recuadro redondeado por dentro, con fondo suave.
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: elegido || encima.isNotEmpty ? P.morado.withValues(alpha: .07) : Colors.transparent,
                borderRadius: BorderRadius.circular(P.radioControl),
                border: Border.all(
                  color: elegido ? P.morado : (encima.isNotEmpty ? P.morado.withValues(alpha: .4) : Colors.transparent),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
              // Los días pasados, atenuados.
              child: Opacity(
                opacity: pasado && !esHoy && delMes ? .6 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: esHoy ? BoxDecoration(color: P.morado, shape: BoxShape.circle) : null,
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: esHoy ? FontWeight.w700 : FontWeight.w500,
                              color: esHoy ? Colors.white : (delMes ? P.texto : P.textoSuave.withValues(alpha: .6)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          meses[d.month - 1].substring(0, 3).toLowerCase(),
                          style: TextStyle(fontSize: 11, color: P.textoSuave.withValues(alpha: delMes ? 1 : .6)),
                        ),
                        if (festivo != null) ...[
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              festivo.nombre.isEmpty ? 'Festivo' : festivo.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: P.rojo),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Al cambiar los activos elegidos, lo de cada día se desvanece y entra con un leve zoom.
                    Expanded(
                      child: _Aparece(
                        clave: _claveSel,
                        child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: todas
                              ? [
                                  _PuntosDia(activos, d, _colorDe, puntosPorFila),
                                  if (marcas.isNotEmpty) const SizedBox(height: 4),
                                  for (final m in marcas.take(_maxMarcasTodas))
                                    _MarcaMantenimiento(m, _colorDe(activos.indexOf(m.activo))),
                                  if (marcas.length > _maxMarcasTodas)
                                    Tooltip(
                                      message: [
                                        for (final m in marcas.skip(_maxMarcasTodas)) '${m.plan.nombre}, ${m.activo.titulo}',
                                      ].join('\n'),
                                      child: Text(
                                        '+${marcas.length - _maxMarcasTodas} mantenimientos',
                                        style: TextStyle(fontSize: 10.5, color: P.textoSuave, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ]
                              : [
                            // Los activos elegidos: una pastilla a lo ancho por activo, con sus turnos.
                            Wrap(
                              spacing: 3,
                              runSpacing: 3,
                              children: [
                                for (final (i, a) in activos.indexed)
                                  if (_visible(a))
                                    SizedBox(
                                      width: anchoTurno,
                                      height: _altoTurno,
                                      // Sin turnos, el hueco en blanco (mantiene alineadas las líneas y sus horas).
                                      child: turnosDe(a, d) == 0
                                          ? null
                                          : _Turno(
                                        a,
                                        _colorDe(i),
                                        turnosDe(a, d),
                                        // Uno: sus turnos en texto. Varios: su tag (los turnos, por la barra).
                                        texto: _elegidas.length > 1
                                            ? (a.tag.isEmpty ? a.nombre : a.tag)
                                            : _turnos(turnosDe(a, d)),
                                        opciones: _opcionesDia(a, d),
                                        onAccion: (accion) => _accionDia(a, d, accion),
                                      ),
                                    ),
                              ],
                            ),
                            if (marcas.isNotEmpty) const SizedBox(height: 3),
                            for (final m in marcas) _MarcaMantenimiento(m, _colorDe(activos.indexOf(m.activo))),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Una fila por máquina ──

  Widget _porMaquina(List<Activo> activos) {
    final dias = _diasMes.toList();
    final marcas = _marcas(activos, dias.first, dias.last);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(P.radio),
        border: Border.all(color: P.borde),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(P.radio),
        child: ColoredBox(
          color: P.superficie,
          child: LayoutBuilder(
            builder: (context, box) {
              const ancho = 200.0, total = 76.0;
              final col = ((box.maxWidth - ancho - total) / dias.length).clamp(26.0, 80.0);
              final contenido = SizedBox(
                width: ancho + total + col * dias.length,
                height: box.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera: letra y número de cada día (tocarlo lo selecciona).
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: P.borde)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: ancho,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text('MÁQUINA', style: _estiloCabecera),
                            ),
                          ),
                          for (final d in dias) SizedBox(width: col, child: _cabeceraDia(d)),
                          SizedBox(
                            width: total,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text('MES', textAlign: TextAlign.right, style: _estiloCabecera),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Solo se construyen las filas que se ven (alto fijo): cambiar de vista y desplazarse va fluido.
                    Expanded(
                      child: ListView.builder(
                        itemExtent: 52,
                        itemCount: activos.length,
                        itemBuilder: (_, i) => _filaMaquina(i, activos[i], dias, col, ancho, total, marcas),
                      ),
                    ),
                  ],
                ),
              );
              return SingleChildScrollView(scrollDirection: Axis.horizontal, child: contenido);
            },
          ),
        ),
      ),
    );
  }

  Widget _cabeceraDia(DateTime d) {
    final esHoy = DateUtils.isSameDay(d, hoy());
    final elegido = _sel.contains(d);
    final festivo = store.festivo(d);
    return Tooltip(
      message: festivo != null ? (festivo.nombre.isEmpty ? 'Festivo' : festivo.nombre) : '',
      child: InkWell(
        onTap: () => _tocarDia(d),
        child: Container(
          color: elegido ? P.morado.withValues(alpha: .1) : null,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _letras[d.weekday - 1],
                style: TextStyle(fontSize: 10, color: festivo != null ? P.rojo : P.textoSuave),
              ),
              const SizedBox(height: 2),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: esHoy ? BoxDecoration(color: P.morado, shape: BoxShape.circle) : null,
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: esHoy ? Colors.white : (festivo != null ? P.rojo : P.texto),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaMaquina(
    int i,
    Activo a,
    List<DateTime> dias,
    double col,
    double ancho,
    double total,
    Map<DateTime, List<_Marca>> marcas,
  ) {
    final color = _colorDe(i);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: P.borde)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: ancho,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconoActivo(a.icono, size: 16, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _quien(a),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          resumenPatron(a),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: P.textoSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Los días de la fila, pintados de una vez (sin un widget por celda): tocar uno da su turno o sus opciones.
          SizedBox(
            width: col * dias.length,
            child: _DiasMaquina(
              a: a,
              color: color,
              dias: dias,
              sel: _sel,
              conMarca: [for (final d in dias) (marcas[d] ?? const []).any((m) => m.activo.id == a.id)],
              onTocar: (d, ancla) async {
                if (turnosDe(a, d) == 0 && !esExcepcion(a, d)) {
                  _poner(a, d, 1);
                  return;
                }
                final v = await abrirMenu<String>(context, ancla, _opcionesDia(a, d), seleccionado: '${turnosDe(a, d)}');
                if (v != null) _accionDia(a, d, v);
              },
            ),
          ),
          SizedBox(
            width: total,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_horas(a, dias).toStringAsFixed(0)} h',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: P.textoSuave),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Los días de una máquina en «Por máquina», en un solo [CustomPaint]: la barra del día (24 h) rellena por la
/// parte que trabaja, como en la leyenda; un punto si es una excepción al patrón, borde rojo si no cabe en 24 h y
/// una rayita abajo si ese día toca un mantenimiento. El ratón resalta la celda (sin reconstruir la fila) y al
/// tocarla se llama a [onTocar] con su rectángulo en pantalla, para abrir sus opciones debajo.
class _DiasMaquina extends StatefulWidget {
  final Activo a;
  final Color color;
  final List<DateTime> dias;
  final Set<DateTime> sel;
  final List<bool> conMarca;
  final void Function(DateTime d, Rect ancla) onTocar;
  const _DiasMaquina({
    required this.a,
    required this.color,
    required this.dias,
    required this.sel,
    required this.conMarca,
    required this.onTocar,
  });

  @override
  State<_DiasMaquina> createState() => _DiasMaquinaState();
}

class _DiasMaquinaState extends State<_DiasMaquina> {
  final _encima = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _encima.dispose();
    super.dispose();
  }

  int _indice(double x, double ancho) => (x / (ancho / widget.dias.length)).floor().clamp(0, widget.dias.length - 1);

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final h = hoy();
    final turnos = [for (final d in widget.dias) turnosDe(a, d)];
    return LayoutBuilder(
      builder: (context, box) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (e) => _encima.value = _indice(e.localPosition.dx, box.maxWidth),
        onExit: (_) => _encima.value = null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) {
            final i = _indice(e.localPosition.dx, box.maxWidth);
            final caja = context.findRenderObject()! as RenderBox;
            final col = box.maxWidth / widget.dias.length;
            final origen = caja.localToGlobal(Offset(i * col, 0));
            widget.onTocar(widget.dias[i], origen & Size(col, box.maxHeight));
          },
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(box.maxWidth, box.maxHeight),
              painter: _PintorDias(
                encima: _encima,
                color: widget.color,
                turnos: turnos,
                fracciones: [for (final n in turnos) _fraccion(a, n)],
                excepciones: [for (final d in widget.dias) esExcepcion(a, d)],
                pasan: [for (final n in turnos) n * a.horasTurno > 24],
                pasados: [for (final d in widget.dias) d.isBefore(h) && !DateUtils.isSameDay(d, h)],
                fondos: [
                  for (final d in widget.dias)
                    widget.sel.contains(d)
                        ? P.morado.withValues(alpha: .08)
                        : store.festivo(d) != null
                        ? P.rojo.withValues(alpha: .035)
                        : d.weekday >= 6
                        ? P.fondo.withValues(alpha: .6)
                        : null,
                ],
                conMarca: widget.conMarca,
                hover: P.hover,
                rojo: P.rojo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorDias extends CustomPainter {
  final ValueNotifier<int?> encima;
  final Color color, hover, rojo;
  final List<int> turnos;
  final List<double> fracciones;
  final List<bool> excepciones, pasan, pasados, conMarca;
  final List<Color?> fondos;
  _PintorDias({
    required this.encima,
    required this.color,
    required this.turnos,
    required this.fracciones,
    required this.excepciones,
    required this.pasan,
    required this.pasados,
    required this.fondos,
    required this.conMarca,
    required this.hover,
    required this.rojo,
  }) : super(repaint: encima);

  @override
  void paint(Canvas canvas, Size size) {
    final col = size.width / turnos.length;
    final p = Paint();
    for (var i = 0; i < turnos.length; i++) {
      final celda = Rect.fromLTWH(i * col, 0, col, size.height);
      if (fondos[i] case final f?) canvas.drawRect(celda, p..color = f);
      if (encima.value == i) canvas.drawRect(celda, p..color = hover);
      final a = pasados[i] ? .6 : 1.0;
      final bloque = RRect.fromRectAndRadius(
        Rect.fromLTRB(celda.left + 2, 10, celda.right - 2, size.height - 10),
        const Radius.circular(5),
      );
      if (turnos[i] > 0) {
        canvas.drawRRect(bloque, p..color = color.withValues(alpha: .15 * a));
        canvas.save();
        canvas.clipRRect(bloque);
        canvas.drawRect(
          Rect.fromLTWH(bloque.left, bloque.top, bloque.width * fracciones[i], bloque.height),
          p..color = color.withValues(alpha: .75 * a),
        );
        canvas.restore();
      }
      if (pasan[i]) {
        canvas.drawRRect(
          bloque,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = rojo,
        );
      }
      if (excepciones[i] && turnos[i] > 0) {
        canvas.drawCircle(Offset(bloque.right - 4.5, bloque.top + 4.5), 2.5, p..color = color);
      }
      if (conMarca[i]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(celda.left + 6, size.height - 6, col - 12, 3),
            const Radius.circular(2),
          ),
          p..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorDias o) =>
      o.color != color ||
      !listEquals(o.fracciones, fracciones) ||
      !listEquals(o.excepciones, excepciones) ||
      !listEquals(o.fondos, fondos) ||
      !listEquals(o.conMarca, conMarca) ||
      !listEquals(o.pasados, pasados);
}

/// Algo pulsable sin onda (cabeceras de día y de semana): solo el cursor y un fondo suave al pasar.
class _Pulsable extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  const _Pulsable({required this.tooltip, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 500),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      hoverColor: P.hover,
      splashFactory: NoSplash.splashFactory,
      onTap: onTap,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

/// Un mantenimiento en su día: rombo del color de la máquina y su nombre en neutro («≈» si es estimado).
class _MarcaMantenimiento extends StatelessWidget {
  final _Marca m;
  final Color color;
  const _MarcaMantenimiento(this.m, this.color);

  @override
  Widget build(BuildContext context) => Tooltip(
    message:
        '${m.plan.nombre} · ${m.activo.titulo}${m.estimada ? '\nFecha estimada por horas: se mueve al cambiar los turnos' : ''}',
    child: Padding(
      padding: const EdgeInsets.only(top: 1, bottom: 2),
      child: Row(
        children: [
          Transform.rotate(angle: .785, child: Container(width: 6, height: 6, color: color)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${m.estimada ? '≈ ' : ''}${m.plan.nombre}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: P.textoSuave, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Las máquinas por turnos, en fila encima del calendario: cada una con su color, para arrastrarla a los días;
/// al tocarla, sus acciones (o, con días seleccionados, ponerle los turnos en ellos).
class _Maquinas extends StatelessWidget {
  final List<Activo> activos;
  final Color Function(int) colorDe;
  final double Function(Activo) horasMes;
  final void Function(Activo, Color, String) onAccion;

  /// Con días seleccionados («5 días»), tocar una máquina saca sus opciones para esos días.
  final String? diasSel;

  /// Sin días seleccionados, tocar una máquina abre su mes ([elegida]; null = todas); sus acciones, en su flecha.
  final Set<String> elegidas;
  final ValueChanged<Activo?> onElegir;
  final VoidCallback onCerrar;
  const _Maquinas({
    required this.onCerrar,
    required this.activos,
    required this.colorDe,
    required this.horasMes,
    required this.onAccion,
    required this.elegidas,
    required this.onElegir,
    this.diasSel,
  });

  List<(String, Widget)> _opciones(Activo a) {
    final dias = diasSel;
    if (dias != null) {
      return [
        for (var k = 1; k <= maxTurnos(a); k++) ('sel$k', Text('${_turnos(k)} en $dias')),
        if (a.patron.length == 7) ('selPatron', Text('Su patrón en $dias')),
        ('sel0', Text('Parada en $dias', style: TextStyle(color: P.rojo))),
      ];
    }
    // Lo justo: el patrón semanal decide los turnos; el resto se hace seleccionando días.
    return [
      ('patron', const Text('Patrón semanal…')),
      ('editar', const Text('Editar activo')),
    ];
  }

  Widget _ficha(int i, Activo a) {
    final color = colorDe(i);
    final h = horasMes(a);
    return Draggable<String>(
      data: a.id,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: _UsoMaquinasState._anchoPanel - 12, child: _Ficha(a, color, h, elevada: true)),
      ),
      childWhenDragging: Opacity(opacity: .4, child: _Ficha(a, color, h)),
      child: diasSel != null
          ? BotonMenu<String>(
              tooltip: '${a.titulo}\nToca para elegir qué hace en los $diasSel',
              resaltarHover: false,
              relleno: EdgeInsets.zero,
              onSelected: (accion) => onAccion(a, color, accion),
              opciones: _opciones(a),
              child: MouseRegion(cursor: SystemMouseCursors.click, child: _Ficha(a, color, h, aplicar: true)),
            )
          // Sin días elegidos: tocarla abre su mes; la flecha saca sus acciones.
          : Tooltip(
              message: elegidas.contains(a.id)
                  ? 'Toca para quitarlo del mes'
                  : 'Toca para verlo en el mes (puedes elegir varios); arrástralo a un día',
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(P.radioControl),
                  hoverColor: P.hover,
                  onTap: () => onElegir(a),
                  child: _Ficha(
                    a,
                    color,
                    h,
                    elegida: elegidas.contains(a.id),
                    menu: BotonMenu<String>(
                      tooltip: 'Acciones de ${a.titulo}',
                      relleno: EdgeInsets.zero,
                      onSelected: (accion) => onAccion(a, color, accion),
                      opciones: _opciones(a),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Icon(Icons.expand_more_rounded, size: 18, color: P.textoSuave),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// Primera fila: todas las máquinas (un punto por máquina en cada día).
  Widget get _todas => Material(
    color: elegidas.isEmpty ? P.morado.withValues(alpha: .07) : Colors.transparent,
    borderRadius: BorderRadius.circular(P.radioControl),
    child: InkWell(
      borderRadius: BorderRadius.circular(P.radioControl),
      hoverColor: P.hover,
      onTap: () => onElegir(null),
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Todos los activos',
                  style: TextStyle(fontWeight: FontWeight.w600, color: elegidas.isEmpty ? P.morado : P.texto),
                ),
              ),
              Text('${activos.length}', style: TextStyle(color: P.textoSuave)),
            ],
          ),
        ),
      ),
    ),
  );

  // Lista vertical (virtualizada) en su tarjeta; la primera fila vuelve a todas. La X, arriba a la derecha.
  @override
  Widget build(BuildContext context) => Container(
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(P.radio),
      border: Border.all(color: P.borde),
    ),
    decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(P.radio)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 4, 4),
          child: Row(
            children: [
              Expanded(child: _todas),
              const SizedBox(width: 4),
              IconButton(tooltip: 'Cerrar', onPressed: onCerrar, icon: const Icon(CupertinoIcons.xmark, size: 18)),
            ],
          ),
        ),
        Divider(height: 1, color: P.borde),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(6),
            itemCount: activos.length,
            itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 4), child: _ficha(i, activos[i])),
          ),
        ),
      ],
    ),
  );
}

/// Una máquina en un día, en una pastilla de una línea: la barra del día (24 h) rellena por la parte que trabaja,
/// con su tag o sus turnos (el detalle, en el tooltip). Al tocarla, sus opciones.
class _Turno extends StatelessWidget {
  final Activo a;
  final Color color;
  final int n;

  /// Lo que pone (por defecto, su tag): con una sola máquina en el mes, sus turnos («2 turnos»).
  final String? texto;
  final List<(String, Widget)> opciones;
  final ValueChanged<String> onAccion;
  const _Turno(this.a, this.color, this.n, {required this.onAccion, required this.opciones, this.texto});

  @override
  Widget build(BuildContext context) {
    final pasa = n * a.horasTurno > 24;
    return BotonMenu<String>(
      tooltip:
          '${a.titulo}: ${_turnos(n)}, ${(n * a.horasTurno).toStringAsFixed(0)} h${pasa ? ', no caben en 24 h' : ''}',
      seleccionado: '$n',
      resaltarHover: false,
      relleno: EdgeInsets.zero,
      onSelected: onAccion,
      opciones: opciones,
      // Una barra del día (24 h) rellena por la parte que trabaja, como en la leyenda: 1 turno, un tercio.
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(5),
          border: pasa ? Border.all(color: P.rojo, width: 1.5) : Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _fraccion(a, n),
              child: ColoredBox(color: color.withValues(alpha: .4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  texto ?? (a.tag.isEmpty ? a.nombre : a.tag),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: P.texto),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cambia su contenido con un fundido y un leve zoom cuando cambia [clave] (al elegir otros activos).
class _Aparece extends StatelessWidget {
  final String clave;
  final Widget child;
  const _Aparece({required this.clave, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 220),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (actual, previos) => Stack(
      alignment: Alignment.topLeft,
      children: [...previos, ?actual],
    ),
    transitionBuilder: (hijo, anim) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(anim), alignment: Alignment.topLeft, child: hijo),
    ),
    child: KeyedSubtree(key: ValueKey(clave), child: child),
  );
}

/// Leyenda del mes, arriba a la derecha: la barra del día (24 h) llena un tercio con 1 turno, dos con 2 y entera
/// con 3; el rombo, un mantenimiento. Sin turnos, el día queda en blanco.
class _Leyenda extends StatelessWidget {
  const _Leyenda();

  Widget _item(Widget muestra, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      muestra,
      const SizedBox(width: 6),
      Text(texto, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
    ],
  );

  Widget _barra(double f) => Container(
    width: 18,
    height: 9,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: P.morado.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(3.5),
      border: Border.all(color: P.morado.withValues(alpha: .4)),
    ),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: f,
      child: ColoredBox(color: P.morado.withValues(alpha: .7)),
    ),
  );

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _item(_barra(1 / 3), '1 turno'),
      _item(_barra(2 / 3), '2 turnos'),
      _item(_barra(1), '3 turnos'),
      _item(Transform.rotate(angle: .785, child: Container(width: 7, height: 7, color: P.textoSuave)), 'Mantenimiento'),
    ],
  );
}

/// Una máquina en el panel de la izquierda: su color e icono, nombre y tag, y debajo su patrón y las horas del mes.
class _Ficha extends StatelessWidget {
  final Activo a;
  final Color color;
  final double horasMes;
  final bool elevada;

  /// Hay días seleccionados: se resalta, porque tocarla saca las opciones de esos días.
  final bool aplicar;

  /// Es la máquina cuyo mes se está viendo.
  final bool elegida;

  /// Al final, la flecha con sus acciones.
  final Widget? menu;
  const _Ficha(
    this.a,
    this.color,
    this.horasMes, {
    this.elevada = false,
    this.aplicar = false,
    this.elegida = false,
    this.menu,
  });

  /// La última lectura se aleja de lo estimado con los turnos más de medio turno (y al menos 2 h).
  bool get _desviada {
    final d = a.desvio;
    return d != null && d.abs() >= (a.horasTurno / 2).clamp(2, 12);
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    height: 48,
    padding: EdgeInsets.fromLTRB(10, 0, menu == null ? 10 : 4, 0),
    // Sobria: sin fondo ni borde (el color, solo en el icono); la elegida, con un tinte y borde de su color.
    decoration: BoxDecoration(
      // Con días seleccionados no se tiñe ninguna más (el tooltip dice que tocarla aplica a esos días).
      color: elegida
          ? Color.alphaBlend(color.withValues(alpha: .08), P.superficie)
          : (elevada ? P.superficie : Colors.transparent),
      borderRadius: BorderRadius.circular(P.radioControl),
      border: Border.all(color: elegida || elevada ? color.withValues(alpha: .45) : Colors.transparent),
      boxShadow: elevada ? [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 12)] : null,
    ),
    child: Row(
      children: [
        IconoActivo(a.icono, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      a.nombre.isEmpty ? a.tag : a.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (a.tag.isNotEmpty && a.nombre.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(a.tag, style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${resumenPatron(a)}, ${horasMes.toStringAsFixed(0)} h este mes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: P.textoSuave),
              ),
            ],
          ),
        ),
        // La última lectura se aleja de sus turnos: un punto ámbar con su explicación.
        if (_desviada) ...[
          const SizedBox(width: 6),
          Tooltip(
            message:
                'Lectura real ${a.desvio! > 0 ? '+' : '−'}${a.desvio!.abs().toStringAsFixed(0)} h sobre sus turnos '
                '(${fecha(a.fechaLectura)}). Revisa su patrón o los días marcados.',
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: P.ambar, shape: BoxShape.circle),
            ),
          ),
        ],
        if (menu != null) ...[const SizedBox(width: 4), menu!],
      ],
    ),
  );
}

/// Un día con todas las máquinas: una barrita por máquina, siempre en el mismo sitio y en su color, rellena por
/// la parte del día que trabaja (como en la leyenda); sin turnos, el hueco en blanco.
class _PuntosDia extends StatelessWidget {
  final List<Activo> activos;
  final DateTime d;
  final Color Function(int) colorDe;
  final int porFila;
  const _PuntosDia(this.activos, this.d, this.colorDe, this.porFila);

  @override
  Widget build(BuildContext context) {
    final turnos = [for (final a in activos) turnosDe(a, d)];
    final filas = (activos.length / porFila).ceil();
    return RepaintBoundary(
        child: CustomPaint(
          size: Size(
            porFila * (_UsoMaquinasState._punto + _UsoMaquinasState._huecoPunto),
            filas * (_UsoMaquinasState._puntoAlto + _UsoMaquinasState._huecoPunto),
          ),
          painter: _PintorPuntos(
            colores: [for (var i = 0; i < activos.length; i++) colorDe(i)],
            turnos: turnos,
            fracciones: [for (final (i, a) in activos.indexed) _fraccion(a, turnos[i])],
            porFila: porFila,
          ),
        ),
    );
  }
}

class _PintorPuntos extends CustomPainter {
  final List<Color> colores;
  final List<int> turnos;
  final List<double> fracciones;
  final int porFila;
  _PintorPuntos({required this.colores, required this.turnos, required this.fracciones, required this.porFila});

  @override
  void paint(Canvas canvas, Size size) {
    const w = _UsoMaquinasState._punto, alto = _UsoMaquinasState._puntoAlto, h = _UsoMaquinasState._huecoPunto;
    final fondo = Paint(), lleno = Paint();
    for (var i = 0; i < colores.length; i++) {
      // Sin turnos, nada (el hueco en blanco); con turnos, la barra del día rellena por su parte.
      if (turnos[i] == 0) continue;
      final r = Rect.fromLTWH((i % porFila) * (w + h), (i ~/ porFila) * (alto + h), w, alto);
      fondo.color = colores[i].withValues(alpha: .22);
      lleno.color = colores[i];
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2.5)), fondo);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(2.5)));
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, w * fracciones[i], alto), lleno);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorPuntos o) =>
      !listEquals(o.fracciones, fracciones) || !listEquals(o.colores, colores) || o.porFila != porFila;
}
