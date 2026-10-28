import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Trabajador con el que se ve la app (null = vista de administrador). '' = el primero activo.
/// Maqueta: con el login de Supabase lo decidirá el rol de la cuenta. `?rol=trabajador&t=<id>` lo abre directo.
final rolTrabajador = ValueNotifier<String?>(
  Uri.base.queryParameters['rol'] == 'trabajador'
      ? (Uri.base.queryParameters['t'] ?? '')
      : null,
);

/// Informe de un trabajo hecho por un trabajador. Maqueta: viven en memoria y el envío es simulado.
class Informe {
  final String tareaId, trabajadorId, resultado, notas;
  final DateTime cuando;
  Informe(this.tareaId, this.trabajadorId, this.resultado, this.notas)
    : cuando = DateTime.now();
}

class _Informes extends ChangeNotifier {
  final lista = <Informe>[];
  List<Informe> de(String tareaId) =>
      lista.where((i) => i.tareaId == tareaId).toList().reversed.toList();
  void anadir(Informe i) {
    lista.add(i);
    notifyListeners();
  }
}

final informesTrabajador = _Informes();

const _resultados = ['Todo correcto', 'Con incidencias', 'No se pudo hacer'];
const _coloresResultado = [P.verde, P.ambar, P.rojo];
const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
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

String _diaLargo(DateTime d) =>
    '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

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
                'Ver Pulpo como…',
                style: TextStyle(
                  fontFamily: P.titulos,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Text(
                'Así lo verá cada trabajador en su móvil.',
                style: TextStyle(fontSize: 12.5, color: P.textoSuave),
              ),
            ),
            if (activos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Text(
                  'Aún no hay trabajadores.',
                  style: TextStyle(color: P.textoSuave),
                ),
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
                          Color(w.color == 0 ? 0xFF6A2FF6 : w.color),
                          size: 34,
                        ),
                        titulo: w.nombreCompleto,
                        subtitulo:
                            '${_misTrabajos(w).length} trabajos asignados',
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
    .where((t) => !t.esPlantilla && t.activa && t.trabajadorIds.contains(w.id))
    .toList();

int _porHora(Tarea a, Tarea b) =>
    (a.inicioMin ?? 1 << 20).compareTo(b.inicioMin ?? 1 << 20);

/// Los trabajos de [w] de un día, ordenados por hora.
List<Tarea> _delDia(Trabajador w, DateTime dia) =>
    store
        .tareasDelDia(dia)
        .where((t) => t.trabajadorIds.contains(w.id))
        .toList()
      ..sort(_porHora);

/// La app del trabajador: sus trabajos, su horario y los informes de cada trabajo.
class ShellTrabajador extends StatefulWidget {
  const ShellTrabajador({super.key});

  @override
  State<ShellTrabajador> createState() => _ShellTrabajadorState();
}

class _ShellTrabajadorState extends State<ShellTrabajador> {
  int pestana = 0;
  String? tareaId;
  DateTime dia = hoy();

  Trabajador? get _yo {
    final id = rolTrabajador.value;
    return store.trabajador(id ?? '') ??
        store.trabajadores.where((w) => w.activo).firstOrNull;
  }

  void _abrir(Tarea t) => setState(() => tareaId = t.id);

  @override
  Widget build(BuildContext context) {
    final w = _yo;
    return Scaffold(
      backgroundColor: P.fondo,
      body: ListenableBuilder(
        listenable: Listenable.merge([store, informesTrabajador]),
        builder: (context, _) {
          if (w == null) {
            return const Vacio(
              icono: Icons.person_outline_rounded,
              titulo: 'Sin trabajadores',
              texto: 'Crea un trabajador desde la vista de administrador.',
            );
          }
          final tarea = tareaId == null
              ? null
              : store.tareas.where((t) => t.id == tareaId).firstOrNull;
          return Align(
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
                              Pestanas(
                                opciones: const [
                                  'Inicio',
                                  'Mis trabajos',
                                  'Horario',
                                ],
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
                      child: tarea != null
                          ? _DetalleTrabajo(tarea, w)
                          : switch (pestana) {
                              0 => _Inicio(
                                w,
                                _abrir,
                                () => setState(() => pestana = 1),
                              ),
                              1 => _MisTrabajos(w, _abrir),
                              _ => _Horario(
                                w,
                                dia,
                                _abrir,
                                (d) => setState(() => dia = d),
                              ),
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Inicio ───────────────────────────────────────────────

class _Inicio extends StatelessWidget {
  final Trabajador w;
  final ValueChanged<Tarea> abrir;
  final VoidCallback verTodos;
  const _Inicio(this.w, this.abrir, this.verTodos);

  @override
  Widget build(BuildContext context) {
    final deHoy = _delDia(w, hoy());
    final hechos = deHoy.where((t) => t.hechaEl(hoy())).length;
    final pendientes = deHoy.where((t) => !t.hechaEl(hoy())).toList();
    final siguiente = pendientes.firstOrNull;
    final cliente = siguiente == null
        ? null
        : store.cliente(siguiente.clienteId);
    return ListView(
      children: [
        Row(
          children: [
            Avatar(
              inicialesDe(w.nombreCompleto),
              Color(w.color == 0 ? 0xFF6A2FF6 : w.color),
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${w.nombre}',
                    style: TextStyle(
                      fontFamily: P.titulos,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.6,
                    ),
                  ),
                  Text(
                    _diaLargo(hoy()),
                    style: TextStyle(color: P.textoSuave, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: huecoVista + 4),
        Tarjeta(
          child: Row(
            children: [
              Expanded(child: Cifra('Hoy', deHoy.length)),
              Expanded(child: Cifra('Hechos', hechos, punto: P.verde)),
              Expanded(
                child: Cifra('Pendientes', pendientes.length, punto: P.ambar),
              ),
            ],
          ),
        ),
        const SizedBox(height: huecoVista),
        if (siguiente == null)
          Tarjeta(
            child: Text(
              deHoy.isEmpty
                  ? 'Hoy no tienes trabajos.'
                  : 'Has terminado todo por hoy.',
              style: TextStyle(color: P.textoSuave),
            ),
          )
        else
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIGUIENTE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                    color: P.morado,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TipoIcono(siguiente.tipo, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            siguiente.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              if (cliente != null) cliente.nombre,
                              siguiente.horario ?? 'Sin hora',
                            ].join(' · '),
                            style: TextStyle(color: P.textoSuave, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (siguiente.ubicacion.isNotEmpty || cliente != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    siguiente.ubicacion.isNotEmpty
                        ? siguiente.ubicacion
                        : cliente!.direccionCompleta,
                    style: TextStyle(color: P.textoSuave, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 14),
                BotonPrimario(
                  'Abrir trabajo',
                  icono: Icons.arrow_forward_rounded,
                  conIcono: true,
                  onPressed: () => abrir(siguiente),
                ),
              ],
            ),
          ),
        const SizedBox(height: huecoVista),
        SeccionTarjeta(
          titulo: 'Tu día',
          subtitulo: deHoy.isEmpty ? null : '${deHoy.length} trabajos',
          accion: Enlace('Ver todos', onTap: verTodos),
          children: [
            if (deHoy.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Nada programado para hoy.',
                  style: TextStyle(color: P.textoSuave),
                ),
              ),
            for (final t in deHoy) _FilaTrabajo(t, abrir, mostrarDia: false),
          ],
        ),
      ],
    );
  }
}

/// Una fila de trabajo: tipo, nombre, cliente y hora; hecho = atenuado con su estado.
class _FilaTrabajo extends StatelessWidget {
  final Tarea t;
  final ValueChanged<Tarea> abrir;
  final bool mostrarDia;
  const _FilaTrabajo(this.t, this.abrir, {required this.mostrarDia});

  @override
  Widget build(BuildContext context) {
    final hecha = t.hechaEl(hoy());
    final cliente = store.cliente(t.clienteId);
    return Atenuado(
      activo: hecha,
      child: FilaLista(
        lider: TipoIcono(t.tipo, size: 36),
        titulo: t.nombre,
        subtitulo: [
          if (cliente != null) cliente.nombre,
          if (mostrarDia && t.proximo != null) relativo(t.proximo!),
        ].join(' · '),
        derecha: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              t.horario ?? 'Sin hora',
              style: TextStyle(fontSize: 12.5, color: P.textoSuave),
            ),
            const SizedBox(height: 3),
            if (hecha) Pill('Hecho', P.verde, punto: true),
          ],
        ),
        onTap: () => abrir(t),
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
            .where((t) => t.proximo != null && !t.hechaEl(hoy()))
            .toList()
          ..sort((a, b) {
            final c = a.proximo!.compareTo(b.proximo!);
            return c != 0 ? c : _porHora(a, b);
          });
    if (pendientes.isEmpty) {
      return const Vacio(
        icono: Icons.task_alt_rounded,
        titulo: 'Todo al día',
        texto: 'No tienes trabajos pendientes.',
      );
    }
    // Atrasados primero; luego un bloque por día.
    final grupos = <String, List<Tarea>>{};
    for (final t in pendientes) {
      final n = diasHasta(t.proximo!);
      final clave = n < 0
          ? 'Atrasados'
          : '${relativo(t.proximo!)} · ${_diaLargo(t.proximo!)}';
      (grupos[clave] ??= []).add(t);
    }
    return ListView(
      children: [
        for (final g in grupos.entries) ...[
          SeccionTarjeta(
            titulo: g.key,
            subtitulo: '${g.value.length}',
            children: [
              for (final t in g.value)
                _FilaTrabajo(t, abrir, mostrarDia: g.key == 'Atrasados'),
            ],
          ),
          const SizedBox(height: huecoVista),
        ],
      ],
    );
  }
}

// ── Horario ──────────────────────────────────────────────

class _Horario extends StatelessWidget {
  final Trabajador w;
  final DateTime dia;
  final ValueChanged<Tarea> abrir;
  final ValueChanged<DateTime> cambiarDia;
  const _Horario(this.w, this.dia, this.abrir, this.cambiarDia);

  static const _altoHora = 64.0;

  @override
  Widget build(BuildContext context) {
    final trabajos = _delDia(w, dia);
    final conHora = trabajos.where((t) => t.inicioMin != null).toList();
    final sinHora = trabajos.where((t) => t.inicioMin == null).toList();
    // Franja visible: la jornada (8–18) ampliada si algún trabajo se sale.
    var desde = 8, hasta = 18;
    for (final t in conHora) {
      if (t.inicioMin! ~/ 60 < desde) desde = t.inicioMin! ~/ 60;
      if ((t.finMin! + 59) ~/ 60 > hasta) hasta = (t.finMin! + 59) ~/ 60;
    }
    hasta = hasta.clamp(desde + 1, 24);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _diaLargo(dia),
                style: TextStyle(
                  fontFamily: P.titulos,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4,
                ),
              ),
            ),
            NavegadorFecha(
              anterior: 'Día anterior',
              siguiente: 'Día siguiente',
              onAnterior: () => cambiarDia(masDias(dia, -1)),
              onHoy: () => cambiarDia(hoy()),
              onSiguiente: () => cambiarDia(masDias(dia, 1)),
            ),
          ],
        ),
        const SizedBox(height: huecoVista),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: P.superficie,
              borderRadius: BorderRadius.circular(P.radio),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(P.radio),
              border: Border.all(color: P.borde),
            ),
            clipBehavior: Clip.antiAlias,
            child: trabajos.isEmpty
                ? const Vacio(
                    icono: Icons.event_available_rounded,
                    texto: 'Nada programado este día.',
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      SizedBox(
                        height: (hasta - desde) * _altoHora,
                        child: Stack(
                          children: [
                            for (var h = desde; h < hasta; h++)
                              Positioned(
                                top: (h - desde) * _altoHora,
                                left: 0,
                                right: 0,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 56,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 14,
                                        ),
                                        child: Transform.translate(
                                          offset: const Offset(0, -7),
                                          child: Text(
                                            hhmm(h * 60),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: P.textoSuave,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(height: 1, color: P.borde),
                                    ),
                                  ],
                                ),
                              ),
                            for (final t in conHora)
                              Positioned(
                                top:
                                    (t.inicioMin! - desde * 60) /
                                        60 *
                                        _altoHora +
                                    1,
                                left: 62,
                                right: 12,
                                height: (t.duracionMin / 60 * _altoHora - 3)
                                    .clamp(30, 2000),
                                child: _Bloque(t, abrir),
                              ),
                          ],
                        ),
                      ),
                      if (sinHora.isNotEmpty) ...[
                        Divider(height: 1, color: P.borde),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                          child: Text(
                            'SIN HORA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                              color: P.textoSuave,
                            ),
                          ),
                        ),
                        for (final t in sinHora)
                          _FilaTrabajo(t, abrir, mostrarDia: false),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Bloque extends StatelessWidget {
  final Tarea t;
  final ValueChanged<Tarea> abrir;
  const _Bloque(this.t, this.abrir);

  @override
  Widget build(BuildContext context) {
    final cliente = store.cliente(t.clienteId);
    return Material(
      color: t.colorBloque.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(P.radioControl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        hoverColor: P.hoverFila,
        mouseCursor: SystemMouseCursors.click,
        onTap: () => abrir(t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: t.colorBloque, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                [t.horario, if (cliente != null) cliente.nombre].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: P.textoSuave),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          child: Text(
            etiqueta,
            style: TextStyle(color: P.textoSuave, fontSize: 13),
          ),
        ),
        Expanded(child: Text(valor, style: const TextStyle(fontSize: 13.5))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cliente = store.cliente(t.clienteId);
    final hecha = t.hechaEl(hoy());
    final informes = informesTrabajador.de(t.id);
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
                      Pill(
                        hecha ? 'Hecho' : t.estado.etiqueta,
                        hecha ? P.verde : t.estado.color,
                        punto: true,
                      ),
                      Pill(t.criticidad.etiqueta, t.criticidad.color),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: huecoVista + 4),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            BotonPrimario(
              'Nuevo informe',
              icono: Icons.edit_note_rounded,
              conIcono: true,
              onPressed: () => abrirPanel(context, FormularioInforme(t, w)),
            ),
            if (!hecha)
              BotonAccion(
                'Marcar hecho',
                icono: Icons.check_rounded,
                onPressed: () => store.marcarHecha(t),
              ),
          ],
        ),
        const SizedBox(height: huecoVista + 4),
        SeccionTarjeta(
          titulo: 'Información',
          children: [
            _dato('Cliente', cliente?.nombre ?? '—'),
            _dato(
              'Dirección',
              t.ubicacion.isNotEmpty
                  ? t.ubicacion
                  : (cliente?.direccionCompleta ?? '—'),
            ),
            _dato(
              'Cuándo',
              [
                if (t.proximo != null) relativo(t.proximo!),
                t.horario ?? 'Sin hora',
              ].join(' · '),
            ),
            if (maquina.isNotEmpty) _dato('Máquina', maquina),
            if (t.notas.isNotEmpty) _dato('Notas', t.notas),
            if (t.competencias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in t.competencias) Etiqueta(c, P.morado),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: huecoVista),
        SeccionTarjeta(
          titulo: 'Informes',
          subtitulo: informes.isEmpty ? null : '${informes.length}',
          children: [
            if (informes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Aún no has enviado ningún informe de este trabajo.',
                  style: TextStyle(color: P.textoSuave),
                ),
              ),
            for (final i in informes)
              FilaLista(
                lider: Icon(Icons.description_outlined, color: P.textoSuave),
                titulo: i.resultado,
                subtitulo: i.notas,
                derecha: Text(
                  '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}',
                  style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Informe del trabajo: cómo ha ido y qué se ha hecho. Maqueta: se guarda en memoria y el envío es simulado.
class FormularioInforme extends StatefulWidget {
  final Tarea t;
  final Trabajador w;
  const FormularioInforme(this.t, this.w, {super.key});

  @override
  State<FormularioInforme> createState() => _FormularioInformeState();
}

class _FormularioInformeState extends State<FormularioInforme> {
  final notas = TextEditingController();
  int resultado = 0;
  bool intentado = false;

  @override
  void dispose() {
    notas.dispose();
    super.dispose();
  }

  void _guardar() {
    if (notas.text.trim().isEmpty) {
      setState(() => intentado = true);
      return;
    }
    informesTrabajador.anadir(
      Informe(
        widget.t.id,
        widget.w.id,
        _resultados[resultado],
        notas.text.trim(),
      ),
    );
    final cliente = store.cliente(widget.t.clienteId);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 360,
        content: Text(
          'Informe guardado${cliente == null ? '' : ' y enviado a ${cliente.nombre}'} (simulado)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'Informe',
    titulo: widget.t.nombre,
    onGuardar: _guardar,
    avisos: [
      if (intentado && notas.text.trim().isEmpty)
        ('Cuenta qué has hecho', () {}),
    ],
    campos: [
      Bloque(
        'Resultado',
        primero: true,
        descripcion: 'Cómo ha ido el trabajo.',
        [
          Pestanas(
            opciones: _resultados,
            seleccion: resultado,
            onChanged: (i) => setState(() => resultado = i),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Pill(
              _resultados[resultado],
              _coloresResultado[resultado],
              punto: true,
            ),
          ),
        ],
      ),
      Bloque(
        'Qué has hecho',
        descripcion:
            'Lo que ha pasado, lo que has cambiado y lo que queda pendiente.',
        [
          campo(
            'Notas',
            notas,
            lineas: 6,
            hint: 'Ej.: revisado el motor, cambiada la correa. Falta pedir una pieza.',
            error: intentado && notas.text.trim().isEmpty
                ? 'Escribe qué has hecho'
                : null,
          ),
        ],
      ),
    ],
  );
}
