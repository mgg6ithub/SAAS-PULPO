import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
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
/// · Se seleccionan días (tocándolos, arrastrando, por la cabecera del día de la semana o por la semana) y al
///   tocar una máquina salen sus opciones para esos días (turnos, su patrón o parada). También se marcan como
///   festivos.
/// · Se ve en su día cada mantenimiento (≈ si la fecha es estimada por horas) y las horas de cada semana.
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

  /// Número de semana ISO (la de su jueves).
  int _semana(DateTime lunes) {
    final jueves = masDias(lunes, 3);
    final primero = DateTime(jueves.year, 1, 1);
    return DateTime.utc(jueves.year, jueves.month, jueves.day).difference(DateTime.utc(primero.year, 1, 1)).inDays ~/
            7 +
        1;
  }

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
                    const Consejo(
                      'Cada máquina tiene su patrón semanal; aquí marcas las excepciones. Selecciona días (tocando, '
                      'arrastrando, por el día de la semana o por la semana) y toca una máquina para elegir qué hace '
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
                      _Maquinas(
                        activos: activos,
                        colorDe: _colorDe,
                        horasMes: (a) => _horas(a, _diasMes),
                        onAccion: _accion,
                        diasSel: _sel.isEmpty ? null : _dias(_sel.length),
                      ),
                      const SizedBox(height: 14),
                      Expanded(child: _vista == 0 ? _calendario(activos) : _porMaquina(activos)),
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
      TextButton(onPressed: () => setState(() => mes = DateTime(hoy().year, hoy().month)), child: const Text('Hoy')),
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

  static const _anchoSemana = 34.0, _anchoTotales = 104.0;

  TextStyle get _estiloCabecera =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .6, color: P.textoSuave);

  Widget _calendario(List<Activo> activos) {
    final inicio = lunesDe(mes);
    final fin = DateTime(mes.year, mes.month + 1, 0);
    final semanas = ((fin.difference(inicio).inDays + 1) / 7).ceil();
    final marcas = _marcas(activos, inicio, masDias(inicio, semanas * 7 - 1));
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: box.maxWidth < 820 ? 820 : box.maxWidth,
          height: box.maxHeight,
          child: SingleChildScrollView(
            child: SizedBox(
              height: box.maxHeight < 460 ? 460 : box.maxHeight,
              child: Column(
                children: [
                  // Cabecera: tocar un día de la semana selecciona todos los de ese día del mes.
                  Row(
                    children: [
                      const SizedBox(width: _anchoSemana),
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _Pulsable(
                            tooltip: 'Seleccionar todos los ${diasSemana[i].toLowerCase()} del mes',
                            onTap: () => _alternar(_diasMes.where((d) => d.weekday == i + 1)),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
                              child: Text(diasSemana[i].toUpperCase(), style: _estiloCabecera),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: _anchoTotales,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 0, 8),
                          child: Text('SEMANA', style: _estiloCabecera),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Número de semana: al tocarlo, la semana entera.
                        SizedBox(
                          width: _anchoSemana,
                          child: Column(
                            children: [
                              for (var s = 0; s < semanas; s++)
                                Expanded(
                                  child: _Pulsable(
                                    tooltip: 'Seleccionar la semana',
                                    onTap: () => _alternar([for (var i = 0; i < 7; i++) masDias(inicio, s * 7 + i)]),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'S${_semana(masDias(inicio, s * 7))}',
                                        style: TextStyle(fontSize: 10.5, color: P.textoSuave.withValues(alpha: .8)),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(child: _rejilla(activos, inicio, semanas, marcas)),
                        // Horas de cada máquina en la semana (en rojo si algún día no le caben).
                        SizedBox(
                          width: _anchoTotales,
                          child: Column(
                            children: [
                              for (var s = 0; s < semanas; s++)
                                Expanded(
                                  child: _totalSemana(activos, [
                                    for (var i = 0; i < 7; i++) masDias(inicio, s * 7 + i),
                                  ]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// La rejilla de días, con su borde redondeado encima (el fondo de las celdas no lo tapa) y la selección
  /// arrastrando por encima de los días.
  Widget _rejilla(List<Activo> activos, DateTime inicio, int semanas, Map<DateTime, List<_Marca>> marcas) =>
      LayoutBuilder(
        builder: (context, box) {
          DateTime diaEn(Offset p) {
            final col = (p.dx / (box.maxWidth / 7)).floor().clamp(0, 6);
            final fila = (p.dy / (box.maxHeight / semanas)).floor().clamp(0, semanas - 1);
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
                    for (var s = 0; s < semanas; s++)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: _dia(
                                  masDias(inicio, s * 7 + i),
                                  activos,
                                  marcas[masDias(inicio, s * 7 + i)] ?? const [],
                                  derecha: i < 6,
                                  abajo: s < semanas - 1,
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

  Widget _totalSemana(List<Activo> activos, List<DateTime> dias) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 0, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, a) in activos.indexed)
          if (_horas(a, dias) case final h when h > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  // El icono de la máquina, en su color (en vez de un punto).
                  IconoActivo(a.icono, size: 14, color: _colorDe(i)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      activos.length > 1 ? '${_quien(a)} ${h.toStringAsFixed(0)} h' : '${h.toStringAsFixed(0)} h',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: dias.any((d) => turnosDe(a, d) * a.horasTurno > 24) ? P.rojo : P.textoSuave,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );

  Widget _dia(DateTime d, List<Activo> activos, List<_Marca> marcas, {bool derecha = true, bool abajo = true}) {
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
                          children: [
                            for (final (i, a) in activos.indexed)
                              if (turnosDe(a, d) > 0 || esExcepcion(a, d))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: _Turno(
                                    a,
                                    _colorDe(i),
                                    turnosDe(a, d),
                                    excepcion: esExcepcion(a, d),
                                    conNombre: activos.length > 1 && a.tag.isNotEmpty,
                                    opciones: _opcionesDia(a, d),
                                    onAccion: (accion) => _accionDia(a, d, accion),
                                  ),
                                ),
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
  const _Maquinas({
    required this.activos,
    required this.colorDe,
    required this.horasMes,
    required this.onAccion,
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
        child: SizedBox(width: 250, child: _Ficha(a, color, h, elevada: true)),
      ),
      childWhenDragging: Opacity(opacity: .4, child: _Ficha(a, color, h)),
      child: BotonMenu<String>(
        tooltip: diasSel == null
            ? 'Arrastra a un día o toca para ver las acciones'
            : 'Toca para elegir qué hace en los $diasSel',
        resaltarHover: false,
        relleno: EdgeInsets.zero,
        onSelected: (accion) => onAccion(a, color, accion),
        opciones: _opciones(a),
        child: MouseRegion(
          cursor: diasSel == null ? SystemMouseCursors.grab : SystemMouseCursors.click,
          child: _Ficha(a, color, h, aplicar: diasSel != null),
        ),
      ),
    );
  }

  /// Leyenda: claro = 1 turno, lleno = 2 o 3; rombo = mantenimiento.
  Widget get _leyenda => Wrap(
    spacing: 14,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _item(_Muestra(P.textoSuave, 1), '1 turno'),
      _item(_Muestra(P.textoSuave, 2), '2 o 3 turnos'),
      _item(Transform.rotate(angle: .785, child: Container(width: 7, height: 7, color: P.textoSuave)), 'Mantenimiento'),
    ],
  );

  Widget _item(Widget muestra, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      muestra,
      const SizedBox(width: 6),
      Text(texto, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
    ],
  );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final (i, a) in activos.indexed) SizedBox(width: 250, child: _ficha(i, a))],
        ),
      ),
      const SizedBox(width: 16),
      Padding(padding: const EdgeInsets.only(top: 8), child: _leyenda),
    ],
  );
}

/// Una máquina en un día: su color, claro con 1 turno y lleno con 2 o 3 («×2», «×3»). Con [conNombre], el
/// nombre debajo del tag, en neutro. Una excepción al patrón lleva un punto; una parada (0 en un día que el
/// patrón trabaja) sale en blanco con borde. Al tocarlo, sus opciones.
class _Turno extends StatelessWidget {
  final Activo a;
  final Color color;
  final int n;
  final bool conNombre, excepcion;
  final List<(String, Widget)> opciones;
  final ValueChanged<String> onAccion;
  const _Turno(
    this.a,
    this.color,
    this.n, {
    required this.onAccion,
    required this.opciones,
    this.conNombre = false,
    this.excepcion = false,
  });

  @override
  Widget build(BuildContext context) {
    final lleno = n >= 2;
    final tinta = lleno ? Colors.white : color;
    final pasa = n * a.horasTurno > 24;
    return BotonMenu<String>(
      tooltip: n == 0
          ? '${a.titulo}: parada (su patrón trabaja este día)'
          : '${a.titulo}: ${_turnos(n)}, ${(n * a.horasTurno).toStringAsFixed(0)} h${excepcion ? ' · excepción al patrón' : ''}'
                '${pasa ? ' · no caben en 24 h' : ''}',
      seleccionado: '$n',
      resaltarHover: false,
      relleno: EdgeInsets.zero,
      onSelected: onAccion,
      opciones: opciones,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
        decoration: BoxDecoration(
          color: n == 0 ? Colors.transparent : (lleno ? color : color.withValues(alpha: .12)),
          borderRadius: BorderRadius.circular(6),
          border: pasa
              ? Border.all(color: P.rojo, width: 1.5)
              : n == 0
              ? Border.all(color: color.withValues(alpha: .35))
              : Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    n == 0 ? '${a.tag.isEmpty ? a.nombre : a.tag} · parada' : (a.tag.isEmpty ? a.nombre : a.tag),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: n == 0 ? P.textoSuave : tinta,
                      decoration: n == 0 ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (lleno)
                  Text(
                    '×$n',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tinta),
                  ),
                if (excepcion && n > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: tinta, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
            if (conNombre && n > 0)
              Text(
                a.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: lleno ? Colors.white.withValues(alpha: .85) : P.textoSuave),
              ),
          ],
        ),
      ),
    );
  }
}

/// Muestra de la leyenda: claro (1 turno) o lleno (2 o 3).
class _Muestra extends StatelessWidget {
  final Color color;
  final int n;
  const _Muestra(this.color, this.n);

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 12,
    decoration: BoxDecoration(
      color: n >= 2 ? color : color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(3),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
  );
}

/// Una máquina: su color, icono, nombre y tag, su patrón y las horas del mes.
class _Ficha extends StatelessWidget {
  final Activo a;
  final Color color;
  final double horasMes;
  final bool elevada;

  /// Hay días seleccionados: se resalta, porque tocarla saca las opciones de esos días.
  final bool aplicar;
  const _Ficha(this.a, this.color, this.horasMes, {this.elevada = false, this.aplicar = false});

  /// La última lectura se aleja de lo estimado con los turnos más de medio turno (y al menos 2 h).
  bool get _desviada {
    final d = a.desvio;
    return d != null && d.abs() >= (a.horasTurno / 2).clamp(2, 12);
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: Color.alphaBlend(color.withValues(alpha: aplicar ? .12 : .06), P.superficie),
      borderRadius: BorderRadius.circular(P.radioControl),
      border: Border.all(color: elevada || aplicar ? color : color.withValues(alpha: .35), width: aplicar ? 1.5 : 1),
      boxShadow: elevada ? [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 12)] : null,
    ),
    child: Row(
      children: [
        IconoActivo(a.icono, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                    Text(
                      a.tag,
                      style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${resumenPatron(a)} · ${horasMes.toStringAsFixed(0)} h este mes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: P.textoSuave),
              ),
              if (_desviada) ...[
                const SizedBox(height: 2),
                Tooltip(
                  message:
                      'La última lectura del contador (${fecha(a.fechaLectura)}) se aleja de lo que suman sus turnos. '
                      'Revisa su patrón o los días marcados.',
                  child: Text(
                    'Lectura real ${a.desvio! > 0 ? '+' : '−'}${a.desvio!.abs().toStringAsFixed(0)} h sobre sus turnos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: P.ambar, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
