import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../forms.dart';
import '../informes.dart';
import '../marca.dart';
import '../industrial/incidencia_form.dart';
import '../industrial/mantenimientos.dart';
import '../plataforma_io.dart' if (dart.library.js_interop) '../plataforma_web.dart';
import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'informes.dart';

/// Trabajador con el que se ve la app (null = vista de administrador). '' = el primero activo.
/// Maqueta: con el login de Supabase lo decidirá el rol de la cuenta. `?rol=trabajador&t=<id>` lo abre directo.
final rolTrabajador = ValueNotifier<String?>(
  Uri.base.queryParameters['rol'] == 'trabajador' ? (Uri.base.queryParameters['t'] ?? '') : null,
);

const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _diaLargo(DateTime d) => '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

/// Elige con qué trabajador ver la app (hasta que haya login). Abre la vista de trabajador.
Future<void> abrirVistaTrabajador(BuildContext context) {
  final activos = store.trabajadores.where((w) => w.activo).toList();
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: P.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(P.radio),
        side: BorderSide(color: P.borde),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Text(
                m('Ver Pulpo como…'),
                style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Text(
                m('Así lo verá cada trabajador en su móvil.'),
                style: TextStyle(fontSize: 12.5, color: P.textoSuave),
              ),
            ),
            if (activos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Text(m('Aún no hay trabajadores.'), style: TextStyle(color: P.textoSuave)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final w in activos)
                      FilaLista(
                        lider: Avatar(
                          inicialesDe(w.nombreCompleto),
                          w.color == 0 ? Marca.color : Color(w.color),
                          size: 34,
                        ),
                        titulo: w.nombreCompleto,
                        subtitulo: m('${_misTrabajos(w).length} trabajos asignados'),
                        onTap: () {
                          Navigator.pop(c);
                          rolTrabajador.value = w.id;
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

List<Tarea> _misTrabajos(Trabajador w) => store.tareas
    .where(
      (t) =>
          !t.esPlantilla &&
          t.activa &&
          (t.trabajadorIds.contains(w.id) ||
              (industrial &&
                  t.tipoMantenimiento != null &&
                  t.trabajadorIds.isEmpty &&
                  t.competencias.every(w.competencias.contains) &&
                  (t.estado == EstadoTrabajo.pendiente || t.estado == EstadoTrabajo.enCurso))),
    )
    .toList();

int _porHora(Tarea a, Tarea b) => (a.inicioMin ?? 1 << 20).compareTo(b.inicioMin ?? 1 << 20);

/// Los trabajos de [w] de un día, ordenados por hora.
List<Tarea> _delDia(Trabajador w, DateTime dia) =>
    store.tareasDelDia(dia).where((t) => t.trabajadorIds.contains(w.id)).toList()..sort(_porHora);

/// Pestañas de la app del trabajador: arriba en escritorio, abajo en el móvil (a mano del pulgar).
const _pestanas = ['Hoy', 'Semana', 'Pendientes'];

/// La app del trabajador: su día, su semana, lo pendiente y los informes de cada trabajo. Pensada primero
/// para el móvil: lo siguiente en grande, botones de llamar y de ruta y marcar hecho con un toque.
class ShellTrabajador extends StatefulWidget {
  const ShellTrabajador({super.key});

  @override
  State<ShellTrabajador> createState() => _ShellTrabajadorState();
}

class _ShellTrabajadorState extends State<ShellTrabajador> {
  int pestana = 0;
  String? tareaId;
  DateTime semana = _lunes(hoy());

  Trabajador? get _yo {
    final id = rolTrabajador.value;
    return store.trabajador(id ?? '') ?? store.trabajadores.where((w) => w.activo).firstOrNull;
  }

  void _abrir(Tarea t) => setState(() => tareaId = t.id);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, informes]),
    builder: (context, _) {
      final w = _yo;
      final movil = esMovil(context);
      final tarea = tareaId == null ? null : store.tareas.where((t) => t.id == tareaId).firstOrNull;
      return Scaffold(
        backgroundColor: P.fondo,
        bottomNavigationBar: !industrial && movil && w != null && tarea == null
            ? _BarraInferior(pestana, (i) => setState(() => pestana = i))
            : null,
        body: w == null
            ? Vacio(
                icono: Icons.person_outline_rounded,
                titulo: m('Sin trabajadores'),
                texto: m('Crea un trabajador desde la vista de administrador.'),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: margenPagina,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BarraVista(
                          izquierda: tarea == null
                              ? [
                                  const LogoPulpo(size: 30),
                                  if (!movil && !industrial)
                                    Pestanas(
                                      opciones: _pestanas,
                                      seleccion: pestana,
                                      onChanged: (i) => setState(() => pestana = i),
                                    ),
                                ]
                              : [
                                  BotonAccion(
                                    'Volver',
                                    icono: CupertinoIcons.chevron_left,
                                    onPressed: () => setState(() => tareaId = null),
                                  ),
                                ],
                          principal: industrial && tarea == null
                              ? BotonPrimario(
                                  'Nueva incidencia',
                                  icono: Icons.add_rounded,
                                  onPressed: () => abrirPanel(context, const AvisoIncidenciaForm()),
                                )
                              : null,
                          derecha: [
                            if (store.nube?.esTrabajador ?? false)
                              BotonAccion(
                                'Cerrar sesión',
                                icono: Icons.logout_rounded,
                                tooltip: store.nube!.nombre,
                                onPressed: Nube.cerrarSesion,
                              )
                            else
                              BotonAccion(
                                'Vista de administrador',
                                icono: Icons.swap_horiz_rounded,
                                tooltip: 'Salir de la vista de ${w.nombre}',
                                onPressed: () => rolTrabajador.value = null,
                              ),
                          ],
                        ),
                        const SizedBox(height: huecoVista),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: KeyedSubtree(
                              key: ValueKey(tarea?.id ?? pestana),
                              child: tarea != null
                                  ? _DetalleTrabajo(tarea, w)
                                  : industrial
                                  ? _MisTrabajos(w, _abrir)
                                  : switch (pestana) {
                                      0 => _Hoy(w, _abrir),
                                      1 => _Semana(w, semana, _abrir, (d) => setState(() => semana = d)),
                                      _ => _MisTrabajos(w, _abrir),
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}

/// Barra de pestañas abajo, para el móvil: texto grande y una rayita morada en la elegida (sin iconos).
class _BarraInferior extends StatelessWidget {
  final int seleccion;
  final ValueChanged<int> onChanged;
  const _BarraInferior(this.seleccion, this.onChanged);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: P.superficie,
      border: Border(top: BorderSide(color: P.borde)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (final (i, o) in _pestanas.indexed)
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  hoverColor: P.hoverFila,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: i == seleccion ? 24 : 0,
                        height: 3,
                        decoration: BoxDecoration(color: P.morado, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        o,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: i == seleccion ? P.morado : P.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Teléfono al que llamar por un trabajo: el del contacto o, si no hay, el del cliente.
String _telefono(Cliente? c) => c == null ? '' : (c.telefonoContacto.isNotEmpty ? c.telefonoContacto : c.telefono);

/// Enlace de Google Maps con la ruta hasta el trabajo (null = sin dirección).
String? _ruta(Tarea t, Cliente? c) {
  const base = 'https://www.google.com/maps/dir/?api=1&destination=';
  if (t.ubicacion.isNotEmpty) return '$base${Uri.encodeComponent(t.ubicacion)}';
  if (c == null) return null;
  if (c.ubicado) return '$base${c.lat},${c.lng}';
  final d = c.direccionCompleta;
  return d.isEmpty ? null : '$base${Uri.encodeComponent(d)}';
}

/// Lo que se hace con un trabajo desde la calle: llamar, ir, informe y marcarlo hecho.
class _AccionesTrabajo extends StatelessWidget {
  final Tarea t;
  final Trabajador w;
  const _AccionesTrabajo(this.t, this.w);

  @override
  Widget build(BuildContext context) {
    if (industrial) return _AccionesOt(t, w);
    final cliente = store.cliente(t.clienteId);
    final tel = _telefono(cliente);
    final ruta = _ruta(t, cliente);
    final hecha = t.hechaEl(hoy());
    // En el móvil, botones de texto (sin icono) para que se entiendan sin pensar.
    final movil = esMovil(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (tel.isNotEmpty)
          BotonAccion(
            'Llamar',
            icono: movil ? null : Icons.call_outlined,
            tooltip: tel,
            onPressed: () => abrirEnlace('tel:${tel.replaceAll(' ', '')}'),
          ),
        if (ruta != null)
          BotonAccion(
            'Cómo llegar',
            icono: movil ? null : Icons.directions_outlined,
            onPressed: () => abrirEnlace(ruta),
          ),
        BotonAccion(
          'Informe',
          icono: movil ? null : Icons.edit_note_rounded,
          onPressed: () => abrirPanel(context, FormularioInforme(t, w)),
        ),
        if (hecha) ...[
          if (store.puedeDesmarcar(t)) BotonAccion('Quitar hecho', onPressed: () => store.desmarcarHecha(t)),
        ] else
          BotonAccion(
            'Hecho',
            icono: movil ? null : Icons.check_rounded,
            color: P.morado,
            onPressed: () => store.marcarHecha(t),
          ),
      ],
    );
  }
}

/// La duración se conserva al cerrar la ficha o recargar el navegador.
class _AccionesOt extends StatefulWidget {
  final Tarea t;
  final Trabajador w;
  const _AccionesOt(this.t, this.w);
  @override
  State<_AccionesOt> createState() => _AccionesOtState();
}

class _AccionesOtState extends State<_AccionesOt> {
  DateTime? inicio;
  bool ocupada = false;
  String get clave => 'ot_inicio_${store.nube?.empresaId ?? 'demo'}_${widget.t.id}';

  @override
  void initState() {
    super.initState();
    _leer();
  }

  Future<void> _leer() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString(clave);
    if (mounted) setState(() => inicio = valor == null ? null : DateTime.tryParse(valor));
  }

  Future<void> _empezar() async {
    if (ocupada) return;
    setState(() => ocupada = true);
    try {
      final nube = store.nube;
      if (nube != null) {
        await nube.empezarOt(widget.t.id);
      } else {
        widget.t.trabajadorIds = [widget.w.id];
        store.cambiarEstado([widget.t], EstadoTrabajo.enCurso);
      }
      final prefs = await SharedPreferences.getInstance();
      final ahora = DateTime.now();
      await prefs.setString(clave, ahora.toIso8601String());
      if (mounted) setState(() => inicio = ahora);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo empezar. Comprueba la conexión y que la OT siga disponible.')),
        );
      }
    } finally {
      if (mounted) setState(() => ocupada = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    if (t.estado == EstadoTrabajo.realizado || t.hechaEl(hoy())) return const SizedBox.shrink();
    final enCurso = t.estado == EstadoTrabajo.enCurso && t.trabajadorIds.contains(widget.w.id);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!enCurso)
          BotonAccion(
            ocupada ? 'Empezando…' : 'Empezar OT',
            icono: Icons.play_arrow_rounded,
            color: P.morado,
            onPressed: _empezar,
          )
        else ...[
          if (inicio != null)
            StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (n) => n),
              builder: (context, _) {
                final segundos = DateTime.now().difference(inicio!).inSeconds.clamp(0, 604800);
                return Text(
                  '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}',
                  semanticsLabel: '${segundos ~/ 60} minutos en esta OT',
                );
              },
            ),
          BotonAccion(
            'Cerrar OT',
            icono: Icons.check_rounded,
            color: P.morado,
            onPressed: () => abrirPanel(
              context,
              FormularioInforme(
                t,
                widget.w,
                cerrarOt: true,
                minutosIniciales: inicio == null
                    ? null
                    : (DateTime.now().difference(inicio!).inSeconds / 60).ceil().clamp(1, 10080),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Hoy ──────────────────────────────────────────────────

class _Hoy extends StatelessWidget {
  final Trabajador w;
  final ValueChanged<Tarea> abrir;
  const _Hoy(this.w, this.abrir);

  @override
  Widget build(BuildContext context) {
    final deHoy = _delDia(w, hoy());
    final hechos = deHoy.where((t) => t.hechaEl(hoy())).length;
    final siguiente = deHoy.where((t) => !t.hechaEl(hoy())).firstOrNull;
    return ListView(
      children: [
        Text(
          'Hola, ${w.nombre}',
          style: TextStyle(fontFamily: P.titulos, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.6),
        ),
        Text(
          [_diaLargo(hoy()), if (deHoy.isNotEmpty) '$hechos de ${deHoy.length} hechos'].join(' · '),
          style: TextStyle(color: P.textoSuave, fontSize: 13.5),
        ),
        const SizedBox(height: huecoVista + 4),
        if (siguiente == null)
          Tarjeta(
            child: Text(
              deHoy.isEmpty ? m('Hoy no tienes trabajos.') : 'Has terminado todo por hoy.',
              style: TextStyle(color: P.textoSuave, fontSize: 15),
            ),
          )
        else
          _Siguiente(siguiente, w, abrir),
        if (deHoy.isNotEmpty) ...[
          const SizedBox(height: huecoVista),
          SeccionTarjeta(
            titulo: 'Tu día',
            subtitulo: '$hechos de ${deHoy.length}',
            children: [for (final t in deHoy) _FilaTrabajo(t, abrir)],
          ),
        ],
      ],
    );
  }
}

/// El siguiente trabajo, en grande: hora, qué, dónde y los botones para llamar, ir y terminarlo.
class _Siguiente extends StatelessWidget {
  final Tarea t;
  final Trabajador w;
  final ValueChanged<Tarea> abrir;
  const _Siguiente(this.t, this.w, this.abrir);

  @override
  Widget build(BuildContext context) {
    final cliente = store.cliente(t.clienteId);
    final direccion = t.ubicacion.isNotEmpty ? t.ubicacion : (cliente?.direccionCompleta ?? '');
    return Tarjeta(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => abrir(t),
              hoverColor: P.hoverFila,
              borderRadius: BorderRadius.circular(P.radioControl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'SIGUIENTE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: P.morado),
                      ),
                      const Spacer(),
                      Icon(CupertinoIcons.chevron_right, size: 16, color: P.textoSuave),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.horario ?? 'Sin hora',
                    style: TextStyle(
                      fontFamily: P.titulos,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(t.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  if (cliente != null) Text(cliente.nombre, style: const TextStyle(fontSize: 15)),
                  if (direccion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(direccion, style: TextStyle(color: P.textoSuave, fontSize: 14)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AccionesTrabajo(t, w),
        ],
      ),
    );
  }
}

/// Una fila de trabajo: tipo, nombre, cliente y hora, con el círculo para marcarlo hecho de un toque.
class _FilaTrabajo extends StatelessWidget {
  final Tarea t;
  final ValueChanged<Tarea> abrir;
  final bool mostrarDia;
  const _FilaTrabajo(this.t, this.abrir, {this.mostrarDia = false});

  @override
  Widget build(BuildContext context) {
    final hecha = t.hechaEl(hoy());
    final cliente = store.cliente(t.clienteId);
    // Solo se marca lo de hoy o lo atrasado; lo de otros días todavía no se ha hecho.
    final marcable = hecha || (t.proximo != null && diasHasta(t.proximo!) <= 0);
    // Lo hecho se atenúa pero se puede abrir (para el informe) y desmarcar.
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: hecha ? .5 : 1,
      child: FilaLista(
        lider: TipoIcono(t.tipo, size: 36),
        titulo: t.nombre,
        subtitulo: [
          if (industrial) dondeEs(t.activoId) else if (cliente != null) cliente.nombre,
          if (mostrarDia && t.proximo != null) relativo(t.proximo!),
        ].join(' · '),
        derecha: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.horario ?? 'Sin hora', style: TextStyle(fontSize: 13, color: P.textoSuave)),
            if (marcable && !industrial) ...[const SizedBox(width: 6), _MarcaHecho(t)],
          ],
        ),
        onTap: () => abrir(t),
      ),
    );
  }
}

/// Círculo de 40 px: vacío = pendiente, verde con check = hecho. Un toque cambia el estado.
class _MarcaHecho extends StatelessWidget {
  final Tarea t;
  const _MarcaHecho(this.t);

  @override
  Widget build(BuildContext context) {
    final hecha = t.hechaEl(hoy());
    return Tooltip(
      message: hecha ? (store.puedeDesmarcar(t) ? 'Quitar hecho' : 'Hecho') : 'Marcar hecho',
      child: InkWell(
        // Solo se deshace lo marcado en esta sesión (el store guarda cómo estaba antes).
        onTap: !hecha
            ? () => store.marcarHecha(t)
            : store.puedeDesmarcar(t)
            ? () => store.desmarcarHecha(t)
            : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hecha ? P.verde : Colors.transparent,
                border: Border.all(color: hecha ? P.verde : P.textoSuave, width: 1.6),
              ),
              child: hecha ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mis trabajos ─────────────────────────────────────────

class _MisTrabajos extends StatelessWidget {
  final Trabajador w;
  final ValueChanged<Tarea> abrir;
  const _MisTrabajos(this.w, this.abrir);

  @override
  Widget build(BuildContext context) {
    final pendientes =
        _misTrabajos(w)
            .where((t) => (industrial || t.proximo != null) && t.estado != EstadoTrabajo.realizado && !t.hechaEl(hoy()))
            .toList()
          ..sort((a, b) {
            final c = (a.proximo ?? DateTime(2100)).compareTo(b.proximo ?? DateTime(2100));
            return c != 0 ? c : _porHora(a, b);
          });
    if (pendientes.isEmpty) {
      return Vacio(icono: Icons.task_alt_rounded, titulo: 'Todo al día', texto: m('No tienes trabajos pendientes.'));
    }
    // Atrasados primero; luego un bloque por día.
    final grupos = <String, List<Tarea>>{};
    for (final t in pendientes) {
      final n = t.proximo == null ? null : diasHasta(t.proximo!);
      final clave = n == null
          ? 'Sin fecha'
          : n < 0
          ? 'Atrasados'
          : '${relativo(t.proximo!)} · ${_diaLargo(t.proximo!)}';
      (grupos[clave] ??= []).add(t);
    }
    if (industrial) {
      final filas = <(String, Tarea?)>[
        for (final g in grupos.entries) ...[(g.key, null), for (final t in g.value) (g.key, t)],
      ];
      return ListView.builder(
        itemCount: filas.length,
        itemBuilder: (context, i) {
          final (grupo, tarea) = filas[i];
          return tarea == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: huecoVista),
                  child: Text(grupo, style: const TextStyle(fontWeight: FontWeight.w600)),
                )
              : _FilaTrabajo(tarea, abrir, mostrarDia: grupo == 'Atrasados');
        },
      );
    }
    return ListView(
      children: [
        for (final g in grupos.entries) ...[
          SeccionTarjeta(
            titulo: g.key,
            subtitulo: '${g.value.length}',
            children: [for (final t in g.value) _FilaTrabajo(t, abrir, mostrarDia: g.key == 'Atrasados')],
          ),
          const SizedBox(height: huecoVista),
        ],
      ],
    );
  }
}

// ── Semana ───────────────────────────────────────────────

DateTime _lunes(DateTime d) => masDias(DateUtils.dateOnly(d), 1 - d.weekday);

String _diaMes(DateTime d) => '${d.day} ${_meses[d.month - 1].substring(0, 3)}';

/// Qué le toca cada día de la semana, en una lista simple (un bloque por día).
class _Semana extends StatelessWidget {
  final Trabajador w;
  final DateTime lunes;
  final ValueChanged<Tarea> abrir;
  final ValueChanged<DateTime> cambiar;
  const _Semana(this.w, this.lunes, this.abrir, this.cambiar);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${_diaMes(lunes)} – ${_diaMes(masDias(lunes, 6))}',
              style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.4),
            ),
          ),
          NavegadorFecha(
            anterior: 'Semana anterior',
            siguiente: 'Semana siguiente',
            onAnterior: () => cambiar(masDias(lunes, -7)),
            onHoy: () => cambiar(_lunes(hoy())),
            onSiguiente: () => cambiar(masDias(lunes, 7)),
          ),
        ],
      ),
      const SizedBox(height: huecoVista),
      Expanded(
        child: ListView.separated(
          itemCount: 7,
          separatorBuilder: (_, _) => const SizedBox(height: huecoVista),
          itemBuilder: (context, i) {
            final d = masDias(lunes, i);
            final trabajos = _delDia(w, d);
            final esHoy = DateUtils.isSameDay(d, hoy());
            final nombre = _dias[d.weekday - 1];
            return SeccionTarjeta(
              titulo: '${esHoy ? 'Hoy, $nombre' : '${nombre[0].toUpperCase()}${nombre.substring(1)}'} ${d.day}',
              subtitulo: trabajos.isEmpty ? null : '${trabajos.length}',
              children: [
                if (trabajos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    child: Text('Libre', style: TextStyle(color: P.textoSuave)),
                  )
                else
                  for (final t in trabajos) _FilaTrabajo(t, abrir),
              ],
            );
          },
        ),
      ),
    ],
  );
}

// ── Detalle de un trabajo e informes ─────────────────────

class _DetalleTrabajo extends StatelessWidget {
  final Tarea t;
  final Trabajador w;
  const _DetalleTrabajo(this.t, this.w);

  Widget _dato(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(etiqueta, style: TextStyle(color: P.textoSuave, fontSize: 13)),
        ),
        Expanded(child: Text(valor, style: const TextStyle(fontSize: 13.5))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cliente = store.cliente(t.clienteId);
    final hecha = t.hechaEl(hoy());
    final lista = informes.de(t.id);
    final maquina = [t.marca, t.modelo].where((x) => x.isNotEmpty).join(' ');
    return ListView(
      children: [
        Row(
          children: [
            TipoIcono(t.tipo, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.nombre,
                    style: TextStyle(
                      fontFamily: P.titulos,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      Pill(hecha ? 'Hecho' : t.estado.etiqueta, hecha ? P.verde : t.estado.color, punto: true),
                      Pill(t.criticidad.etiqueta, t.criticidad.color),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: huecoVista + 4),
        _AccionesTrabajo(t, w),
        const SizedBox(height: huecoVista + 4),
        SeccionTarjeta(
          titulo: 'Información',
          children: [
            _dato(m('Cliente'), industrial ? dondeEs(t.activoId) : cliente?.nombre ?? '—'),
            _dato('Dirección', t.ubicacion.isNotEmpty ? t.ubicacion : (cliente?.direccionCompleta ?? '—')),
            _dato('Cuándo', [if (t.proximo != null) relativo(t.proximo!), t.horario ?? 'Sin hora'].join(' · ')),
            if (maquina.isNotEmpty) _dato('Máquina', maquina),
            if (t.notas.isNotEmpty) _dato('Notas', t.notas),
            if (t.competencias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in t.competencias) Etiqueta(c, P.morado)],
                ),
              ),
          ],
        ),
        const SizedBox(height: huecoVista),
        SeccionTarjeta(
          titulo: 'Informes',
          subtitulo: lista == null || lista.isEmpty ? null : '${lista.length}',
          children: [
            if (lista == null)
              const Padding(padding: EdgeInsets.all(18), child: LinearProgressIndicator())
            else if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  m('Aún no has enviado ningún informe de este trabajo.'),
                  style: TextStyle(color: P.textoSuave),
                ),
              )
            else
              for (final i in lista) FilaInforme(i, t),
          ],
        ),
      ],
    );
  }
}

/// Informe del trabajo: cómo ha ido, qué se ha hecho y fotos. Con sesión se guarda en Supabase.
class FormularioInforme extends StatefulWidget {
  final Tarea t;
  final Trabajador w;
  final bool cerrarOt;
  final int? minutosIniciales;
  const FormularioInforme(this.t, this.w, {super.key, this.cerrarOt = false, this.minutosIniciales});

  @override
  State<FormularioInforme> createState() => _FormularioInformeState();
}

class _FormularioInformeState extends State<FormularioInforme> {
  final notas = TextEditingController(), material = TextEditingController(), minutos = TextEditingController();
  final firmante = TextEditingController();
  final fotos = <Uint8List>[];
  final firma = Firma();
  int resultado = 0;
  bool intentado = false, guardando = false, leyendoFotos = false;

  @override
  void initState() {
    super.initState();
    if (widget.minutosIniciales != null) minutos.text = '${widget.minutosIniciales}';
  }

  @override
  void dispose() {
    for (final c in [notas, material, minutos, firmante]) {
      c.dispose();
    }
    firma.dispose();
    super.dispose();
  }

  /// Minutos escritos (null = vacío); -1 = no es un número válido.
  int? get _minutos {
    final m = minutos.text.trim();
    if (m.isEmpty) return null;
    final n = int.tryParse(m);
    return n == null || n < 0 || n > 10080 ? -1 : n;
  }

  Future<void> _anadirFotos() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (r == null) return;
    setState(() => leyendoFotos = true);
    for (final f in r.files.take(maxFotosInforme - fotos.length)) {
      try {
        final c = await comprimirFoto(f.bytes!);
        if (mounted) setState(() => fotos.add(c));
      } catch (e) {
        debugPrint('Pulpo: no se pudo leer la foto ${f.name}: $e');
      }
    }
    if (mounted) setState(() => leyendoFotos = false);
  }

  Future<void> _guardar() async {
    if (guardando || leyendoFotos) return;
    if (notas.text.trim().isEmpty || _minutos == -1) {
      setState(() => intentado = true);
      return;
    }
    setState(() => guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    void aviso(String texto) =>
        messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text(texto)));
    bool subido;
    try {
      subido = await informes.crear(
        Informe(
          trabajoId: widget.t.id,
          trabajadorId: widget.w.id,
          resultado: resultado,
          notas: notas.text.trim(),
          material: material.text.trim(),
          minutos: _minutos,
          firmante: firma.vacia ? '' : firmante.text.trim(),
        ),
        fotos: fotos,
        firma: await firma.png(),
      );
    } catch (e) {
      debugPrint('Pulpo: no se pudo guardar el informe: $e');
      if (mounted) setState(() => guardando = false);
      aviso('No se pudo guardar el informe. Inténtalo de nuevo.');
      return;
    }
    if (widget.cerrarOt && resultado != 2) {
      store.marcarHecha(widget.t);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ot_inicio_${store.nube?.empresaId ?? 'demo'}_${widget.t.id}');
    }
    if (mounted) Navigator.pop(context);
    aviso(subido ? 'Informe guardado' : 'Sin conexión: el informe se ha guardado aquí y se subirá al volver');
  }

  Widget _miniatura(int n) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(P.radio),
        child: Image.memory(fotos[n], width: 84, height: 84, fit: BoxFit.cover),
      ),
      Positioned(
        top: 4,
        right: 4,
        child: Tooltip(
          message: 'Quitar',
          child: InkWell(
            onTap: () => setState(() => fotos.removeAt(n)),
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _anadir() => Tooltip(
    message: 'Añadir fotos',
    child: InkWell(
      onTap: leyendoFotos ? null : _anadirFotos,
      borderRadius: BorderRadius.circular(P.radio),
      child: CustomPaint(
        painter: BordeDiscontinuo(P.textoSuave.withValues(alpha: .6), BorderRadius.circular(P.radio)),
        child: SizedBox(
          width: 84,
          height: 84,
          child: Center(
            child: leyendoFotos
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.add_photo_alternate_outlined, size: 22, color: P.textoSuave),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'Informe',
    titulo: widget.t.nombre,
    onGuardar: _guardar,
    avisos: [
      if (intentado && notas.text.trim().isEmpty) ('Cuenta qué has hecho', () {}),
      if (intentado && _minutos == -1) ('El tiempo va en minutos', () {}),
    ],
    campos: [
      Bloque('Resultado', primero: true, descripcion: m('Cómo ha ido el trabajo.'), [
        Pestanas(opciones: resultadosInforme, seleccion: resultado, onChanged: (i) => setState(() => resultado = i)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Pill(resultadosInforme[resultado], coloresResultado[resultado], punto: true),
        ),
      ]),
      Bloque('Qué has hecho', descripcion: 'Lo que ha pasado, lo que has cambiado y lo que queda pendiente.', [
        campo(
          industrial ? 'Trabajo realizado y mediciones' : 'Notas',
          notas,
          lineas: 6,
          hint: 'Ej.: revisado el motor, cambiada la correa. Falta pedir una pieza.',
          error: intentado && notas.text.trim().isEmpty ? 'Escribe qué has hecho' : null,
        ),
      ]),
      Bloque('Material y tiempo', descripcion: 'Lo que has usado y cuánto has tardado.', [
        campo(industrial ? 'Repuestos' : 'Material', material, lineas: 2, hint: 'Ej.: 1 correa, 2 l de aceite'),
        campo(
          'Minutos',
          minutos,
          hint: 'Ej.: 90',
          error: intentado && _minutos == -1 ? 'Escribe solo los minutos, con números' : null,
        ),
      ]),
      Bloque('Fotos', descripcion: m('Del equipo, de la avería o del trabajo terminado. Hasta $maxFotosInforme.'), [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 0; n < fotos.length; n++) _miniatura(n),
            if (fotos.length < maxFotosInforme) _anadir(),
          ],
        ),
      ]),
      Bloque(m('Firma del cliente'), descripcion: 'Que firme con el dedo en el recuadro. Si no está, déjalo en blanco.', [
        PanelFirma(firma),
        campo('Nombre de quien firma', firmante, hint: 'Ej.: Ana López, presidenta'),
      ]),
    ],
  );
}
