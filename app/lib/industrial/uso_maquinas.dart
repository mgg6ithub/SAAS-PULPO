import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
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
        proximoPlan,
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

/// Cuántos turnos caben en un día con las horas por turno de la máquina (de 1 a 3).
int maxTurnos(Activo a) => a.horasTurno <= 0 ? 3 : (24 / a.horasTurno).floor().clamp(1, 3);

const _letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

String _turnos(int n) => '$n ${n == 1 ? 'turno' : 'turnos'}';

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
  String? _elegida;
  bool _visible(Activo a) => _elegida == null || _elegida == a.id;

  /// Lista de activos a la izquierda, que se abre y cierra con el botón del activo que se ve, bajo el título.
  bool _panel = false;

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

  /// Mantenimientos activos de cada máquina (y de sus componentes) por día, en el rango que se ve.
  Map<DateTime, List<_Marca>> _marcas(List<Activo> activos, DateTime desde, DateTime hasta) {
    final out = <DateTime, List<_Marca>>{};
    final ids = {for (final a in activos) a.id: a};
    for (final p in store.planes.where((p) => p.activa)) {
      final a = ids[raizActivo(p.activoId)?.id];
      if (a == null) continue;
      final d = proximoPlan(p);
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

  Future<void> _vaciarSel(List<Activo> activos) => _cambiar('Sin turnos en ${_dias(_sel.length)}', _sel, activos, () {
    for (final a in activos) {
      for (final d in _sel) {
        ponerTurnos(a, d, 0);
      }
    }
  });

  /// Marca (con su nombre) o desmarca como festivos los días seleccionados.
  Future<void> _festivoSel(List<Activo> activos) async {
    final dias = _sel.toList();
    final todos = dias.every((d) => store.festivo(d) != null);
    var nombre = '';
    if (!todos) {
      final r = await _pedirNombre();
      if (r == null) return;
      nombre = r;
    }
    if (!await _confirmarPasado(dias)) return;
    final antes = _fechasOts(activos);
    store.deshacible(
      todos
          ? 'Quitado festivo en ${_dias(dias.length)}'
          : '${nombre.isEmpty ? 'Festivo' : nombre}: ${_dias(dias.length)}',
      () {
        store.ponerFestivos(dias, festivo: !todos, nombre: nombre);
        for (final a in activos) {
          reprogramarOts(a);
        }
      },
      aviso: false,
    );
    if (!mounted) return;
    setState(() {});
    _avisarOts(context, antes, abajo: _abajoAviso);
  }

  Future<String?> _pedirNombre() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como festivo'),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Festivo, vacaciones, parada…'),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Marcar')),
        ],
      ),
    );
  }

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
                    // Debajo del título: el activo que se ve (o todos); abre y cierra la lista de activos.
                    if (activos.isNotEmpty) ...[
                      Align(alignment: Alignment.centerLeft, child: _botonActivos(activos)),
                      const SizedBox(height: 10),
                    ],
                    const Consejo(
                      'Cada máquina tiene su patrón semanal; aquí marcas las excepciones. Selecciona días (tocando, '
                      'arrastrando o por el día de la semana) y toca una máquina para elegir qué hace '
                      'esos días.',
                      clave: 'uso-activos-5',
                    ),
                    const SizedBox(height: 12),
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
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: _panel ? _anchoPanel + 10 : 0,
                              child: ClipRect(
                                child: OverflowBox(
                                  alignment: Alignment.centerLeft,
                                  minWidth: _anchoPanel + 10,
                                  maxWidth: _anchoPanel + 10,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: _Maquinas(
                                      activos: activos,
                                      colorDe: _colorDe,
                                      horasMes: (a) => _horas(a, _diasMes),
                                      onAccion: _accion,
                                      diasSel: _sel.isEmpty ? null : _dias(_sel.length),
                                      elegida: _elegida,
                                      // Tocar un activo abre su mes (también desde «Por máquina»); otra vez, todos.
                                      onElegir: (a) => setState(() {
                                        _elegida = a == null || _elegida == a.id ? null : a.id;
                                        _vista = 0;
                                      }),
                                      onCerrar: () => setState(() => _panel = false),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(child: _vista == 0 ? _calendario(activos) : _porMaquina(activos)),
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

  Widget _botonActivos(List<Activo> activos) {
    final a = activos.where((x) => x.id == _elegida).firstOrNull;
    return BotonAccion(
      a == null ? 'Todos los activos' : a.titulo,
      icono: a == null ? Marca.iconoCliente : iconoIndustrial(a.icono),
      tooltip: _panel ? 'Ocultar la lista de activos' : 'Ver la lista de activos',
      onPressed: () => setState(() => _panel = !_panel),
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
    ],
  );

  /// Barra de selección de días, como la de las listas: cuántos, todo el mes, festivo, vaciar los días y salir
  /// (también con Esc). Lo de cada máquina sale al tocarla.
  Widget _barraSeleccion(List<Activo> activos) {
    final delMes = _diasMes.toList();
    final festivos = _sel.every((d) => store.festivo(d) != null);
    return BarraSeleccion(
      seleccionados: _sel.length,
      total: delMes.length,
      nombre: 'días',
      textoEliminar: 'Vaciar días',
      onTodos: () => _alternar(delMes),
      onEliminar: () => _vaciarSel(activos),
      eliminar: _menuVaciar(activos),
      onSalir: _deseleccionar,
      acciones: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () => _festivoSel(activos),
          child: Text(festivos ? 'Quitar festivo' : 'Festivo'),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  /// «Vaciar días» como menú: todas las máquinas o solo una de las que trabajan en los días elegidos.
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
        ('*', const Text('Todas las máquinas')),
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
                Text(a.titulo),
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
            Text('Vaciar días', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
      _punto = 9.0,
      _huecoPunto = 4.0,
      _anchoHoras = 90.0,
      _maxMarcasTodas = 3,
      _anchoPanel = 260.0;

  TextStyle get _estiloCabecera =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .6, color: P.textoSuave);

  /// Máquinas (visibles) que salen en un día: con turnos o con una parada que es excepción.
  int _enDia(List<Activo> activos, DateTime d) =>
      activos.where((a) => _visible(a) && (turnosDe(a, d) > 0 || esExcepcion(a, d))).length;

  /// Alto de un día. Todas: las filas de puntos y hasta tres mantenimientos (más una línea «+N»). Una máquina:
  /// su pastilla y sus mantenimientos.
  double _altoDia(List<Activo> activos, DateTime d, int marcas, int puntosPorFila, bool todas) => todas
      ? _altoBaseDia +
            (activos.length / puntosPorFila).ceil() * (_punto + _huecoPunto) +
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
    final todas = _elegida == null;
    return LayoutBuilder(
      builder: (context, box) {
        final ancho = box.maxWidth < 640 ? 640.0 : box.maxWidth;
        // Hueco útil de un día (menos márgenes y bordes): la pastilla de la máquina elegida lo ocupa entero y,
        // con todas, caben tantos puntos por fila.
        final util = (ancho - _anchoHoras) / 7 - 22;
        final anchoTurno = util;
        final porLinea = ((util + _huecoPunto) / (_punto + _huecoPunto)).floor().clamp(1, 40);
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
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: ancho,
            height: box.maxHeight,
            child: Column(
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 0, 0),
                        child: Text('HORAS', style: _estiloCabecera),
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
            ),
          ),
        );
      },
    );
  }

  Widget _horasSemana(List<Activo> activos, List<DateTime> dias) {
    final a = _elegida == null ? null : activos.where((x) => x.id == _elegida).firstOrNull;
    final h = a != null ? _horas(a, dias) : activos.fold(0.0, (t, x) => t + _horas(x, dias));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 0, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Row(
          children: [
            a != null
                ? IconoActivo(a.icono, size: 15, color: _colorDe(activos.indexOf(a)))
                : Icon(Marca.iconoCliente, size: 15, color: P.textoSuave),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${h.toStringAsFixed(0)} h',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: h == 0 ? P.textoSuave : P.texto),
              ),
            ),
          ],
        ),
      ),
    );
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
  ) => LayoutBuilder(
    builder: (context, box) {
      DateTime diaEn(Offset p) {
        final col = (p.dx / (box.maxWidth / 7)).floor().clamp(0, 6);
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
                    Expanded(
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
                            // La máquina elegida: su pastilla a lo ancho, con sus turnos.
                            Wrap(
                              spacing: 3,
                              runSpacing: 3,
                              children: [
                                for (final (i, a) in activos.indexed)
                                  if (_visible(a) && (turnosDe(a, d) > 0 || esExcepcion(a, d)))
                                    SizedBox(
                                      width: anchoTurno,
                                      height: _altoTurno,
                                      child: _Turno(
                                        a,
                                        _colorDe(i),
                                        turnosDe(a, d),
                                        excepcion: esExcepcion(a, d),
                                        texto: turnosDe(a, d) == 0 ? 'Parada' : _turnos(turnosDe(a, d)),
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
                    for (final (i, a) in activos.indexed) _filaMaquina(i, a, dias, col, ancho, total, marcas),
                  ],
                ),
              );
              return SingleChildScrollView(
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: contenido),
              );
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
          for (final d in dias) SizedBox(width: col, child: _celdaMaquina(a, color, d, marcas[d] ?? const [])),
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

  /// Un día de una máquina: un bloque de su color, más intenso cuantos más turnos; un punto si es una
  /// excepción al patrón y una rayita abajo si ese día toca un mantenimiento.
  Widget _celdaMaquina(Activo a, Color color, DateTime d, List<_Marca> marcas) {
    final n = turnosDe(a, d);
    final elegido = _sel.contains(d);
    final festivo = store.festivo(d) != null;
    final mias = marcas.where((m) => m.activo.id == a.id).toList();
    final bloque = Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      decoration: BoxDecoration(
        color: n == 0 ? Colors.transparent : color.withValues(alpha: const [0.0, .22, .55, .9][n.clamp(0, 3)]),
        borderRadius: BorderRadius.circular(5),
        border: n * a.horasTurno > 24 ? Border.all(color: P.rojo, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (n > 1)
            Text(
              '$n',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: n >= 3 ? Colors.white : P.texto),
            ),
          if (esExcepcion(a, d))
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: n >= 2 ? Colors.white : color, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
    final celda = Container(
      color: elegido
          ? P.morado.withValues(alpha: .08)
          : festivo
          ? P.rojo.withValues(alpha: .035)
          : d.weekday >= 6
          ? P.fondo.withValues(alpha: .6)
          : null,
      child: Opacity(
        opacity: d.isBefore(hoy()) && !DateUtils.isSameDay(d, hoy()) ? .6 : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            bloque,
            if (mias.isNotEmpty)
              Positioned(
                left: 6,
                right: 6,
                bottom: 3,
                child: Tooltip(
                  message: mias.map((m) => '${m.estimada ? '≈ ' : ''}${m.plan.nombre}').join('\n'),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final texto =
        '${a.titulo} · ${d.day}: ${n == 0 ? 'sin turno' : '${_turnos(n)}, ${(n * a.horasTurno).toStringAsFixed(0)} h'}';
    return n == 0 && !esExcepcion(a, d)
        ? Tooltip(
            message: '$texto. Toca para darle un turno',
            child: InkWell(onTap: () => _poner(a, d, 1), child: celda),
          )
        : BotonMenu<String>(
            tooltip: texto,
            seleccionado: '$n',
            resaltarHover: false,
            relleno: EdgeInsets.zero,
            onSelected: (accion) => _accionDia(a, d, accion),
            opciones: _opcionesDia(a, d),
            child: celda,
          );
  }
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
  final String? elegida;
  final ValueChanged<Activo?> onElegir;
  final VoidCallback onCerrar;
  const _Maquinas({
    required this.onCerrar,
    required this.activos,
    required this.colorDe,
    required this.horasMes,
    required this.onAccion,
    required this.elegida,
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
    return [
      ('editar', const Text('Editar activo')),
      ('patron', const Text('Patrón semanal…')),
      ('lab1', const Text('1 turno los laborables del mes')),
      if (maxTurnos(a) >= 2) ('lab2', const Text('2 turnos los laborables del mes')),
      if (maxTurnos(a) >= 3) ('lab3', const Text('3 turnos los laborables del mes')),
      ('todos1', const Text('1 turno todos los días del mes')),
      ('copiar', const Text('Copiar el mes anterior')),
      if (a.patron.length == 7) ('patronMes', const Text('Quitar las excepciones del mes')),
      ('vaciar', Text('Vaciar el mes', style: TextStyle(color: P.rojo))),
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
              message: elegida == a.id ? 'Toca para volver a ver todas' : 'Toca para ver su mes; arrástrala a un día',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onElegir(a),
                  child: _Ficha(
                    a,
                    color,
                    h,
                    elegida: elegida == a.id,
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
    color: elegida == null ? P.morado.withValues(alpha: .07) : Colors.transparent,
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
                  'Todas las máquinas',
                  style: TextStyle(fontWeight: FontWeight.w600, color: elegida == null ? P.morado : P.texto),
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

/// Una máquina en un día, en una pastilla de una línea: su tag en su color, claro con 1 turno y lleno con 2 o 3
/// (el número exacto, con el nombre y las horas, en el tooltip). Una excepción al patrón lleva un punto; una parada
/// (0 en un día que el patrón trabaja) sale tachada con borde. Al tocarlo, sus opciones.
class _Turno extends StatelessWidget {
  final Activo a;
  final Color color;
  final int n;
  final bool excepcion;

  /// Lo que pone (por defecto, su tag): con una sola máquina en el mes, sus turnos («2 turnos»).
  final String? texto;
  final List<(String, Widget)> opciones;
  final ValueChanged<String> onAccion;
  const _Turno(
    this.a,
    this.color,
    this.n, {
    required this.onAccion,
    required this.opciones,
    this.excepcion = false,
    this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final lleno = n >= 2;
    final tinta = lleno ? Colors.white : color;
    final pasa = n * a.horasTurno > 24;
    return BotonMenu<String>(
      tooltip: n == 0
          ? '${a.titulo}: parada (su patrón trabaja este día)'
          : '${a.titulo}: ${_turnos(n)}, ${(n * a.horasTurno).toStringAsFixed(0)} h${excepcion ? ', excepción al patrón' : ''}'
                '${pasa ? ', no caben en 24 h' : ''}',
      seleccionado: '$n',
      resaltarHover: false,
      relleno: EdgeInsets.zero,
      onSelected: onAccion,
      opciones: opciones,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: n == 0 ? Colors.transparent : (lleno ? color : color.withValues(alpha: .12)),
          borderRadius: BorderRadius.circular(5),
          border: pasa
              ? Border.all(color: P.rojo, width: 1.5)
              : n == 0
              ? Border.all(color: color.withValues(alpha: .35))
              : Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                texto ?? (a.tag.isEmpty ? a.nombre : a.tag),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: n == 0 ? P.textoSuave : tinta,
                  decoration: n == 0 ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (excepcion && n > 0) ...[
              const SizedBox(width: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: tinta, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
    decoration: BoxDecoration(
      color: Color.alphaBlend(color.withValues(alpha: aplicar || elegida ? .14 : .05), P.superficie),
      borderRadius: BorderRadius.circular(P.radioControl),
      border: Border.all(
        color: elevada || aplicar || elegida ? color : color.withValues(alpha: .3),
        width: aplicar || elegida ? 1.5 : 1,
      ),
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
                    Text(a.tag, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
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

/// Un día con todas las máquinas: un punto por máquina, siempre en el mismo sitio y en su color (lleno con 2 o
/// 3 turnos, suave con 1); un hueco gris si no trabaja y un aro rojo si es una parada fuera de su patrón. Así se
/// ve de un vistazo cuáles faltan.
class _PuntosDia extends StatelessWidget {
  final List<Activo> activos;
  final DateTime d;
  final Color Function(int) colorDe;
  final int porFila;
  const _PuntosDia(this.activos, this.d, this.colorDe, this.porFila);

  @override
  Widget build(BuildContext context) {
    final turnos = [for (final a in activos) turnosDe(a, d)];
    final paradas = [for (final a in activos) esExcepcion(a, d)];
    final filas = (activos.length / porFila).ceil();
    return RepaintBoundary(
        child: CustomPaint(
          size: Size(
            porFila * (_UsoMaquinasState._punto + _UsoMaquinasState._huecoPunto),
            filas * (_UsoMaquinasState._punto + _UsoMaquinasState._huecoPunto),
          ),
          painter: _PintorPuntos(
            colores: [for (var i = 0; i < activos.length; i++) colorDe(i)],
            turnos: turnos,
            paradas: paradas,
            porFila: porFila,
            hueco: P.borde,
            rojo: P.rojo,
          ),
        ),
    );
  }
}

class _PintorPuntos extends CustomPainter {
  final List<Color> colores;
  final List<int> turnos;
  final List<bool> paradas;
  final int porFila;
  final Color hueco, rojo;
  _PintorPuntos({
    required this.colores,
    required this.turnos,
    required this.paradas,
    required this.porFila,
    required this.hueco,
    required this.rojo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const p = _UsoMaquinasState._punto, h = _UsoMaquinasState._huecoPunto;
    final lleno = Paint();
    final aro = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < colores.length; i++) {
      final c = Offset((i % porFila) * (p + h) + p / 2, (i ~/ porFila) * (p + h) + p / 2);
      if (turnos[i] > 0) {
        lleno.color = turnos[i] >= 2 ? colores[i] : colores[i].withValues(alpha: .45);
        canvas.drawCircle(c, p / 2, lleno);
      } else {
        aro.color = paradas[i] ? rojo : hueco;
        canvas.drawCircle(c, p / 2 - .6, aro);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorPuntos o) =>
      !listEquals(o.turnos, turnos) || !listEquals(o.paradas, paradas) || !listEquals(o.colores, colores) || o.porFila != porFila;
}
