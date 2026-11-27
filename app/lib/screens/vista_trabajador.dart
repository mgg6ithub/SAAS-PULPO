import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show FontFeature, PointerDeviceKind;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../forms.dart';
import '../industrial/activo.dart';
import '../informes.dart';
import '../intro_pulpo.dart' show LogoBarra;
import '../marca.dart';
import '../industrial/activos.dart' show colorEstado, gravedadDe;
import '../notificaciones.dart' show Aviso, Notificaciones;
import '../shell.dart' show AsaBarra;
import '../industrial/gravedad.dart' show EstadoEnVivo, AnilloCiclo, cicloOt, descripcionOt, origenOt;
import '../industrial/iconos.dart';
import '../industrial/incidencia_form.dart';
import '../industrial/incidencia.dart';
import '../industrial/tipo_mantenimiento.dart';
import '../industrial/mantenimientos.dart';
import '../industrial/planes.dart' show raizActivo, horasHoy;
import '../plataforma_io.dart' if (dart.library.js_interop) '../plataforma_web.dart';
import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../industrial/checklist.dart';
import 'cuenta.dart' show BloquesAcceso;
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
                m('Ver Pultec como…'),
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

/// La orden tiene una incidencia que salió de ella y que la oficina aún no ha respondido (sin OT ni desestimar).
bool esperandoIncidencia(Tarea t) => store.incidencias.any(
  (i) => i.origenTrabajoId == t.id && store.estadoIncidencia(i) == EstadoIncidencia.abierta,
);

List<Tarea> _misTrabajos(Trabajador w) => store.tareas
    .where(
      (t) =>
          !t.esPlantilla &&
          t.activa &&
          // Solo las asignadas a él: las que no tienen técnico no le salen a nadie (antes, en Pultec, les salían a
          // todos los que podían hacerlas).
          t.trabajadorIds.contains(w.id),
    )
    .toList();

int _porHora(Tarea a, Tarea b) => (a.inicioMin ?? 1 << 20).compareTo(b.inicioMin ?? 1 << 20);

/// Los trabajos de [w] de un día, ordenados por hora.
List<Tarea> _delDia(Trabajador w, DateTime dia) =>
    store.tareasDelDia(dia).where((t) => t.trabajadorIds.contains(w.id)).toList()..sort(_porHora);

/// Desplazamiento de la vista del técnico en escritorio: la barra vertical va en un hueco propio a la derecha,
/// sin tapar las tarjetas.
class _BarraAparte extends MaterialScrollBehavior {
  /// Sin el hueco: dentro de las tablas, para que el fondo de la fila llegue hasta el borde.
  final bool conHueco;
  const _BarraAparte({this.conHueco = true});

  static const hueco = 14.0;

  // Como en el resto de la app: se arrastra también con el ratón y sin rebote.
  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) =>
      conHueco && axisDirectionToAxis(details.direction) == Axis.vertical
      ? super.buildScrollbar(context, Padding(padding: const EdgeInsets.only(right: hueco), child: child), details)
      : super.buildScrollbar(context, child, details);
}

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

  /// Pultec: qué se ve (0 órdenes, 1 incidencias, 2 histórico) y si está la ventana previa de máquinas,
  /// que sale cada vez que el técnico entra.
  int vista = 0;
  bool eligiendo = industrial;

  Trabajador? get _yo {
    final id = rolTrabajador.value;
    return store.trabajador(id ?? '') ?? store.trabajadores.where((w) => w.activo).firstOrNull;
  }

  void _abrir(Tarea t) => setState(() => tareaId = t.id);

  Future<void> _salir() async {
    if (store.nube != null) await Nube.cerrarSesion();
    rolTrabajador.value = null;
  }

  /// Se puede volver a la vista de administrador (no en una cuenta de técnico).
  bool get _puedeAdmin => !(store.nube?.esTrabajador ?? false);

  /// Menú del técnico en el móvil: su perfil, la vista de administrador y cerrar sesión.
  Widget _menuCuenta(Trabajador w) => BotonMenu<int>(
    tooltip: 'Tu cuenta',
    child: FotoTecnico(w, size: 30),
    onSelected: (i) {
      if (i == 0) {
        abrirPerfilTecnico(context, w);
      } else if (i == 1) {
        rolTrabajador.value = null;
      } else {
        _salir();
      }
    },
    opciones: [
      for (final (i, icono, texto) in [
        (0, Icons.person_outline_rounded, 'Mi perfil'),
        if (_puedeAdmin) (1, Icons.swap_horiz_rounded, 'Vista de administrador'),
        (2, Icons.logout_rounded, 'Cerrar sesión'),
      ])
        (i, Row(children: [Icon(icono, size: 18, color: P.textoSuave), const SizedBox(width: 10), Text(texto)])),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, informes]),
    builder: (context, _) {
      final w = _yo;
      final movil = esMovil(context);
      final tarea = tareaId == null ? null : store.tareas.where((t) => t.id == tareaId).firstOrNull;
      // Pultec: máquinas con órdenes del técnico. Con una o ninguna no hace falta elegir.
      final maquinas = w == null || !industrial ? const <(Activo, int)>[] : _maquinasDe(w);
      // Lo elegido la última vez se guarda en el dispositivo; hasta leerlo no se enseña la ventana.
      if (industrial && w != null && _maquinasCargadas.add(w.id)) {
        _cargarMaquinas(w.id).then((_) {
          if (mounted) setState(() {});
        });
      }
      final elegir = industrial && eligiendo && tarea == null && maquinas.length > 1;
      final escritorio = industrial && !movil && w != null;
      Widget? contenido;
      if (w != null) {
        contenido = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dentro de una orden no hay barra: la flecha para volver va a la izquierda del título.
            if (tarea == null && !escritorio) ...[
              BarraVista(
                izquierda: tarea == null
                    ? [
                        const LogoBarra(size: 30),
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
                // También mientras elige máquinas; en el móvil, con texto (solo el «+» no se entendía).
                principal: industrial && tarea == null
                    ? movil
                          ? SizedBox(
                              height: 40,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: P.rojo),
                                onPressed: () => abrirPanel(context, AvisoIncidenciaForm(tecnicoId: w.id)),
                                icon: const Icon(Icons.report_outlined, size: 19),
                                label: const Text('Crear incidencia'),
                              ),
                            )
                          : BotonPrimario(
                              'Crear incidencia',
                              icono: Icons.report_outlined,
                              conIcono: true,
                              color: P.rojo,
                              onPressed: () => abrirPanel(context, AvisoIncidenciaForm(tecnicoId: w.id)),
                            )
                    : null,
                derecha: industrial
                    ? [if (tarea == null) _menuCuenta(w)]
                    : [
                        BotonAccion('Cerrar sesión', icono: Icons.logout_rounded, onPressed: _salir),
                        if (_puedeAdmin)
                          BotonAccion(
                            'Vista de administrador',
                            icono: Icons.swap_horiz_rounded,
                            tooltip: 'Salir de la vista de ${w.nombre}',
                            onPressed: () => rolTrabajador.value = null,
                          ),
                      ],
              ),
              const SizedBox(height: huecoVista),
            ],
            Expanded(
              child: ScrollConfiguration(
                behavior: escritorio ? const _BarraAparte(conHueco: false) : ScrollConfiguration.of(context),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(tarea?.id ?? (elegir ? 'maquinas' : pestana)),
                  child: tarea != null
                      ? _DetalleTrabajo(tarea, w, onVolver: () => setState(() => tareaId = null))
                      : elegir && !_maquinasLeidas.contains(w.id)
                      ? const SizedBox.shrink()
                      : elegir
                      ? Builder(
                          builder: (_) {
                            // Las de la última vez siguen marcadas si aún tienen órdenes; las que ya no tienen
                            // salen al final, sin marcar.
                            final previas = _maquinasElegidas[w.id] ?? const <String>{};
                            final conOrdenes = {for (final (a, _) in maquinas) a.id};
                            return ElegirMaquinas(
                              w,
                              [
                                ...maquinas,
                                for (final id in previas)
                                  if (!conOrdenes.contains(id))
                                    if (store.activo(id) case final a?) (a, 0),
                              ],
                              inicial: previas.intersection(conOrdenes),
                              onListo: (sel) => setState(() {
                                _maquinasElegidas[w.id] = sel;
                                _guardarMaquinas(w.id, sel);
                                eligiendo = false;
                              }),
                            );
                          },
                        )
                      : industrial
                      ? _PanelTecnico(
                          w,
                          _abrir,
                          vista: vista,
                          onVista: (n) => setState(() => vista = n),
                          pestanas: !escritorio,
                          maquinas: maquinas.length > 1 ? (_maquinasElegidas[w.id] ?? const {}) : const {},
                          onMaquinas: maquinas.length > 1 ? () => setState(() => eligiendo = true) : null,
                        )
                      : switch (pestana) {
                          0 => _Hoy(w, _abrir),
                          1 => _Semana(w, semana, _abrir, (d) => setState(() => semana = d)),
                          _ => _MisTrabajos(w, _abrir),
                        },
                ),
              ),
              ),
            ),
          ],
        );
        contenido = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // En escritorio, todo el ancho y el mismo margen que las páginas del administrador ([margenPagina]).
            constraints: BoxConstraints(maxWidth: escritorio ? double.infinity : 760),
            child: Padding(padding: margenPagina, child: contenido),
          ),
        );
      }
      return Scaffold(
        backgroundColor: escritorio ? P.barra : P.fondo,
        // Pultec: sus notificaciones abajo a la derecha, como la oficina (lo que le responde la oficina).
        floatingActionButton: industrial && w != null
            ? Notificaciones(
                fuente: () => avisosTecnico(w),
                clave: 'avisos_tecnico_${w.id}',
                conHistorial: false,
                textoVacio: 'Todo al día. Aquí verás lo que te responda la oficina.',
                onTarea: (id) => setState(() {
                  tareaId = id;
                  eligiendo = false;
                }),
                onActivo: (_) {},
                onSinTecnico: () {},
              )
            : null,
        bottomNavigationBar: !industrial && movil && w != null && tarea == null
            ? _BarraInferior(pestana, (i) => setState(() => pestana = i))
            : null,
        body: w == null
            ? Vacio(
                icono: Icons.person_outline_rounded,
                titulo: m('Sin trabajadores'),
                texto: m('Crea un trabajador desde la vista de administrador.'),
              )
            : escritorio
            // Escritorio: la misma estructura que la del administrador (barra lateral y el contenido en un panel).
            ? Row(
                children: [
                  _BarraTecnico(
                    w: w,
                    vista: elegir ? -1 : vista,
                    cuentas: _cuentas(w),
                    onVista: (n) => setState(() {
                      vista = n;
                      tareaId = null;
                      eligiendo = false;
                    }),
                    onIncidencia: () => abrirPanel(context, AvisoIncidenciaForm(tecnicoId: w.id)),
                    onPerfil: () => abrirPerfilTecnico(context, w),
                    onAdmin: _puedeAdmin ? () => rolTrabajador.value = null : null,
                    onSalir: _salir,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(P.radio),
                          border: Border.all(color: P.bordeBarra),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(P.radio),
                          child: ColoredBox(color: P.fondo, child: contenido!),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : contenido!,
      );
    },
  );

  /// Cuántas hay en cada apartado de la barra: órdenes pendientes (en sus máquinas) e incidencias.
  List<int> _cuentas(Trabajador w) {
    final sel = _maquinasElegidas[w.id] ?? const {};
    final pendientes = _misTrabajos(w)
        .where((t) => t.estado.abierta && !t.hechaEl(hoy()) && _enMaquinas(t.activoId, sel))
        .length;
    final avisos = store.incidencias
        .where((i) => i.tecnicoId == w.id || (i.tecnicoId == null && (store.nube?.esTrabajador ?? false)))
        .length;
    return [pendientes, avisos];
  }
}

/// Máquinas elegidas por cada técnico al entrar (vacío = todas). Van con su cuenta (`activos_elegidos`); sin
/// sesión (demo), en el dispositivo.
final _maquinasElegidas = <String, Set<String>>{};

/// Técnicos cuya selección ya se ha pedido y ya se ha leído.
final _maquinasCargadas = <String>{}, _maquinasLeidas = <String>{};

String _claveMaquinas(String tecnico) => 'maquinas_demo_$tecnico';

Future<void> _cargarMaquinas(String tecnico) async {
  try {
    final l = store.nube != null
        ? store.trabajador(tecnico)?.activosElegidos
        : (await SharedPreferences.getInstance()).getStringList(_claveMaquinas(tecnico));
    if (l != null && l.isNotEmpty) {
      _maquinasElegidas[tecnico] ??= {for (final id in l) if (store.activo(id) != null) id};
    }
  } catch (_) {
    /* Sin acceso al almacenamiento: se elige de cero. */
  }
  _maquinasLeidas.add(tecnico);
}

Future<void> _guardarMaquinas(String tecnico, Set<String> sel) async {
  try {
    final n = store.nube;
    if (n != null) {
      store.trabajador(tecnico)?.activosElegidos = sel.toList();
      await n.guardarActivosElegidos(tecnico, sel.toList());
    } else {
      await (await SharedPreferences.getInstance()).setStringList(_claveMaquinas(tecnico), sel.toList());
    }
  } catch (e) {
    debugPrint('Pultec: no se pudieron guardar los activos elegidos: $e');
  }
}

/// La «máquina» de un activo: él mismo si es raíz o cuelga de una raíz; si es un componente más abajo,
/// su antepasado que cuelga de la raíz (p. ej. el cilindro → el equipo hidráulico).
String _maquinaDe(String id) {
  var a = store.activo(id);
  if (a == null) return id;
  while (a!.padreId != null) {
    final p = store.activo(a.padreId!);
    if (p == null || p.padreId == null) break;
    a = p;
  }
  return a.id;
}

/// La orden o incidencia entra con las máquinas elegidas (sin activo o sin elegir nada, siempre).
/// Las máquinas elegidas que ya no existen (borradas) no cuentan: si no queda ninguna, se ven todas.
bool _enMaquinas(String? activoId, Set<String> sel) =>
    !sel.any((id) => store.activo(id) != null) || activoId == null || sel.contains(_maquinaDe(activoId));

/// Máquinas con órdenes pendientes del técnico y cuántas tiene en cada una (las de más órdenes primero).
List<(Activo, int)> _maquinasDe(Trabajador w) {
  final n = <String, int>{};
  for (final t in _misTrabajos(w)) {
    if (t.activoId == null || t.estado == EstadoTrabajo.realizado || t.hechaEl(hoy())) continue;
    final id = _maquinaDe(t.activoId!);
    n[id] = (n[id] ?? 0) + 1;
  }
  return [
    for (final e in n.entries)
      if (store.activo(e.key) case final a?) (a, e.value),
  ]..sort((a, b) => b.$2 != a.$2 ? b.$2 - a.$2 : a.$1.nombre.compareTo(b.$1.nombre));
}

/// Foto del técnico en un círculo o, si no tiene, sus iniciales en su color.
class FotoTecnico extends StatelessWidget {
  final Trabajador w;
  final double size;
  const FotoTecnico(this.w, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => w.foto.isEmpty
      ? Avatar(inicialesDe(w.nombreCompleto), w.color == 0 ? Marca.color : Color(w.color), size: size)
      : ClipOval(child: FotoGuardada(w.foto, width: size, height: size));
}

/// Barra lateral del técnico en escritorio: igual que la del administrador, pero con solo sus apartados.
class _BarraTecnico extends StatelessWidget {
  final Trabajador w;
  final int vista;
  final List<int> cuentas;
  final ValueChanged<int> onVista;
  final VoidCallback onIncidencia, onPerfil, onSalir;
  final VoidCallback? onAdmin;
  const _BarraTecnico({
    required this.w,
    required this.vista,
    required this.cuentas,
    required this.onVista,
    required this.onIncidencia,
    required this.onPerfil,
    required this.onSalir,
    this.onAdmin,
  });

  /// Fila de abajo (vista de administrador, cerrar sesión); plegada, solo el icono con su nombre al pasar.
  Widget _fila(IconData icono, String texto, VoidCallback onTap, bool iconos) => Tooltip(
    message: iconos ? texto : '',
    child: InkWell(
      borderRadius: BorderRadius.circular(P.radioControl),
      hoverColor: P.hoverBarra,
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: iconos ? 0 : 12, vertical: 10),
        child: Row(
          mainAxisAlignment: iconos ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icono, size: 19, color: P.textoBarraSuave),
            if (!iconos) ...[
              const SizedBox(width: 12),
              Expanded(child: Text(texto, maxLines: 1, overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 14.5, color: P.textoBarra))),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _plegar(bool iconos) => Tooltip(
    message: iconos ? 'Expandir' : 'Contraer',
    child: InkWell(
      borderRadius: BorderRadius.circular(P.radioControl),
      hoverColor: P.hoverBarra,
      mouseCursor: SystemMouseCursors.click,
      onTap: ajustes.alternarContraida,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          iconos ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded,
          size: 18,
          color: P.textoBarraSuave,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.assignment_outlined, 'Mis órdenes', cuentas[0]),
      (Icons.report_gmailerrorred_rounded, 'Incidencias', cuentas[1]),
      (Icons.history_rounded, 'Histórico', 0),
    ];
    // Plegada o no, con el mismo ajuste que la barra del administrador; el contenido sale del ancho real de cada
    // fotograma, así cambia a solo iconos durante la animación y no de golpe.
    return _AnchoBarraTecnico(
      child: ColoredBox(
        color: P.barra,
        child: ClipRect(
          child: LayoutBuilder(builder: (context, box) {
            // Como en la del administrador: por debajo de 120 px, solo iconos.
            final iconos = box.maxWidth < 120;
            return Padding(
              padding: EdgeInsets.fromLTRB(iconos ? 10 : 14, 18, iconos ? 10 : 14, 14),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (iconos) ...[
                      const Center(child: LogoBarra(size: 32)),
                      const SizedBox(height: 4),
                      Center(child: _plegar(true)),
                    ] else
                      Row(
                        children: [
                          const SizedBox(width: 2),
                          const LogoBarra(size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              Marca.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontFamily: P.titulos,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.6,
                                color: P.textoBarra,
                              ),
                            ),
                          ),
                          _plegar(false),
                        ],
                      ),
                    const SizedBox(height: 18),
                    Tooltip(
                      message: iconos ? 'Crear incidencia' : '',
                      child: SizedBox(
                        height: 42,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: P.rojo,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
                          ),
                          onPressed: onIncidencia,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.report_outlined, size: 19),
                            if (!iconos) ...[
                              const SizedBox(width: 8),
                              const Flexible(child: Text('Crear incidencia', maxLines: 1, overflow: TextOverflow.clip,
                                style: TextStyle(fontWeight: FontWeight.w600))),
                            ],
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Como la barra del administrador: un único fondo blanco que se desliza a la elegida. Sin ninguna
                    // elegida (eligiendo activos) no se pinta: así no se va volando hacia arriba ni vuelve de allí.
                    Stack(
                      children: [
                        if (vista >= 0)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            top: vista * 44.0,
                            left: 0,
                            right: 0,
                            height: 40,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: P.seleccionBarra,
                                borderRadius: BorderRadius.circular(P.radioControl),
                                boxShadow: P.sombraSeleccionBarra,
                              ),
                            ),
                          ),
                        Column(
                          children: [
                            for (final (i, (icono, texto, n)) in items.indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Tooltip(
                                  message: iconos ? texto : '',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(P.radioControl),
                                    splashFactory: NoSplash.splashFactory,
                                    highlightColor: Colors.transparent,
                                    hoverColor: P.hoverBarra,
                                    mouseCursor: SystemMouseCursors.click,
                                    onTap: () => onVista(i),
                                    child: SizedBox(
                                      height: 40,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: iconos ? 0 : 12),
                                        child: Row(
                                          mainAxisAlignment: iconos ? MainAxisAlignment.center : MainAxisAlignment.start,
                                          children: [
                                            TweenAnimationBuilder<Color?>(
                                              tween: ColorTween(end: vista == i ? P.iconoBarraElegido : P.textoBarraSuave),
                                              duration: const Duration(milliseconds: 200),
                                              builder: (_, c, _) => Icon(icono, size: 20, color: c),
                                            ),
                                            if (!iconos) ...[
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: AnimatedDefaultTextStyle(
                                                  duration: const Duration(milliseconds: 200),
                                                  style: TextStyle(
                                                    fontFamily: P.titulos,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: vista == i ? P.textoBarraElegido : P.textoBarra,
                                                  ),
                                                  child: Text(texto, maxLines: 1, overflow: TextOverflow.clip),
                                                ),
                                              ),
                                              if (n > 0) Text('$n', style: TextStyle(fontSize: 13, color: P.textoBarraSuave)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (onAdmin != null) _fila(Icons.swap_horiz_rounded, 'Vista de administrador', onAdmin!, iconos),
                    _fila(Icons.logout_rounded, 'Cerrar sesión', onSalir, iconos),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: P.bordeBarra),
                    const SizedBox(height: 8),
                    // Su perfil: foto, nombre y, al pulsar, la ventana para cambiar su foto y sus ajustes.
                    Tooltip(
                      message: 'Mi perfil',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(P.radioControl),
                        hoverColor: P.hoverBarra,
                        mouseCursor: SystemMouseCursors.click,
                        onTap: onPerfil,
                        child: Padding(
                          padding: EdgeInsets.all(iconos ? 4 : 8),
                          child: Row(
                            mainAxisAlignment: iconos ? MainAxisAlignment.center : MainAxisAlignment.start,
                            children: [
                              FotoTecnico(w, size: 34),
                              if (!iconos) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        w.nombreCompleto,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: P.textoBarra),
                                      ),
                                      Text('Mi perfil', maxLines: 1, overflow: TextOverflow.clip,
                                        style: TextStyle(fontSize: 12, color: P.textoBarraSuave)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Ventana previa al entrar: el técnico marca en qué máquinas va a trabajar y solo ve sus órdenes.
class ElegirMaquinas extends StatefulWidget {
  final Trabajador w;
  final List<(Activo, int)> maquinas;
  final Set<String> inicial;
  final ValueChanged<Set<String>> onListo;
  const ElegirMaquinas(this.w, this.maquinas, {super.key, required this.inicial, required this.onListo});

  @override
  State<ElegirMaquinas> createState() => _ElegirMaquinasState();
}

class _ElegirMaquinasState extends State<ElegirMaquinas> {
  late final sel = {...widget.inicial};

  @override
  Widget build(BuildContext context) {
    final todas = sel.length == widget.maquinas.length;
    final ordenes = sel.isEmpty
        ? widget.maquinas.fold(0, (n, m) => n + m.$2)
        : widget.maquinas.where((m) => sel.contains(m.$1.id)).fold(0, (n, m) => n + m.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_diaLargo(hoy()), style: TextStyle(color: P.morado, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Hola, ${widget.w.nombre}',
          style: TextStyle(fontFamily: P.titulos, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.8),
        ),
        const SizedBox(height: 6),
        Text(
          '¿En qué activos vas a trabajar?',
          style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w600, color: P.texto),
        ),
        const SizedBox(height: 4),
        Text(
          'Solo verás las órdenes de los que marques. Puedes cambiarlo cuando quieras.',
          style: TextStyle(fontSize: 14, color: P.textoSuave),
        ),
        const SizedBox(height: 18),
        // Los botones van justo debajo de las máquinas; con muchas, la rejilla se desplaza.
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisExtent: 118,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: widget.maquinas.length,
            itemBuilder: (_, i) {
              final (a, n) = widget.maquinas[i];
              final marcada = sel.contains(a.id);
              return _TarjetaMaquina(
                a,
                n,
                marcada: marcada,
                onTap: () => setState(() => marcada ? sel.remove(a.id) : sel.add(a.id)),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            BotonAccion(
              todas ? 'Quitar todos' : 'Marcar todos',
              icono: todas ? Icons.remove_done_rounded : Icons.done_all_rounded,
              onPressed: () => setState(() {
                if (todas) {
                  sel.clear();
                } else {
                  sel.addAll(widget.maquinas.map((m) => m.$1.id));
                }
              }),
            ),
            const Spacer(),
            // Sin activos marcados no hay botón: primero se elige en qué se trabaja.
            if (sel.isNotEmpty) SizedBox(
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: P.morado,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
                ),
                onPressed: () => widget.onListo({...sel}),
                child: Text(
                  // Lo mismo que la última vez: «Seguir»; si ha cambiado algo, «Empezar».
                  '${widget.inicial.isNotEmpty && sel.length == widget.inicial.length && sel.containsAll(widget.inicial) ? 'Seguir' : 'Empezar'} '
                  'con $ordenes ${ordenes == 1 ? 'orden' : 'órdenes'}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Máquina en la ventana previa: icono, nombre, etiqueta y cuántas órdenes tiene el técnico en ella.
/// Marcada: borde y fondo morado suave y el check arriba a la derecha.
class _TarjetaMaquina extends StatefulWidget {
  final Activo a;
  final int n;
  final bool marcada;
  final VoidCallback onTap;
  const _TarjetaMaquina(this.a, this.n, {required this.marcada, required this.onTap});

  @override
  State<_TarjetaMaquina> createState() => _TarjetaMaquinaState();
}

class _TarjetaMaquinaState extends State<_TarjetaMaquina> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.marcada;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: Semantics(
        button: true,
        selected: m,
        label: '${widget.a.nombre}, ${widget.n == 0 ? 'sin órdenes pendientes' : '${widget.n} órdenes'}',
        child: GestureDetector(
          onTap: widget.onTap,
          // Sin órdenes (ya hecho todo): más apagada, al final de la cuadrícula.
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: widget.n == 0 && !m ? .6 : 1,
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: m ? P.moradoSuave : P.superficie,
              borderRadius: BorderRadius.circular(P.radio),
              border: Border.all(
                color: m ? P.morado : (hover ? P.morado.withValues(alpha: .4) : P.borde),
                width: m ? 1.5 : 1,
              ),
              boxShadow: P.sombra,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconoActivo(widget.a.icono, size: 26, color: m ? P.morado : P.textoSuave),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        m ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        key: ValueKey(m),
                        size: 22,
                        color: m ? P.morado : P.borde,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.a.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.n == 0 ? 'Sin órdenes pendientes' : '${widget.n} ${widget.n == 1 ? 'orden' : 'órdenes'}',
                  style: TextStyle(fontSize: 13, color: P.textoSuave),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

/// Perfil del propio técnico: su foto, su teléfono y cómo ve la app (tema y letra).
Future<void> abrirPerfilTecnico(BuildContext context, Trabajador w) => abrirPanel(context, _PerfilTecnico(w));

class _PerfilTecnico extends StatefulWidget {
  final Trabajador w;
  const _PerfilTecnico(this.w);

  @override
  State<_PerfilTecnico> createState() => _PerfilTecnicoState();
}

class _PerfilTecnicoState extends State<_PerfilTecnico> {
  late String foto = widget.w.foto;
  late final telefono = TextEditingController(text: widget.w.telefono);
  String? error;

  /// Ha entrado con su propia cuenta de técnico.
  bool get _conCuenta => store.nube?.esTrabajador ?? false;

  @override
  void dispose() {
    telefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final w = Trabajador.fromJson(widget.w.toJson())
      ..foto = foto
      ..telefono = telefono.text.trim();
    try {
      // Una cuenta de técnico no puede tocar el resto de su ficha: solo su foto y su teléfono, en el servidor.
      if (store.nube?.esTrabajador ?? false) await store.nube!.guardarMiPerfil(w.foto, w.telefono);
      store.guardarTrabajador(w);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Pultec: no se pudo guardar el perfil: $e');
      setState(() => error = 'No se ha podido guardar. Inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'Mi perfil',
    titulo: widget.w.nombreCompleto,
    lider: FotoFormulario(foto: foto, onCambio: (f) => setState(() => foto = f)),
    onGuardar: _guardar,
    campos: [
      Bloque('Datos', primero: true, descripcion: 'Pulsa el círculo de arriba para poner tu foto. La ven el equipo y la oficina.', [
        campo('Teléfono', telefono, teclado: TextInputType.phone, error: error),
        // Con su cuenta, el correo va abajo, donde se puede cambiar.
        if (widget.w.email.isNotEmpty && !_conCuenta) ...[
          etiqueta('Correo'),
          Text(widget.w.email, style: TextStyle(color: P.textoSuave)),
        ],
      ]),
      Bloque('Apariencia', descripcion: 'Solo cambia cómo ves la app en este dispositivo.', [
        etiqueta('Tema'),
        Pestanas(
          opciones: const ['Claro', 'Oscuro'],
          seleccion: ajustes.oscuro ? 1 : 0,
          onChanged: (i) => setState(() => ajustes.ponerTema(i == 1 ? ThemeMode.dark : ThemeMode.light)),
        ),
        const SizedBox(height: 16),
        etiqueta('Tamaño de letra'),
        Pestanas(
          opciones: const ['Normal', 'Grande', 'Más grande', 'Máxima'],
          seleccion: ajustes.tamanoLetra,
          onChanged: (i) => setState(() => ajustes.ponerTamanoLetra(i)),
        ),
      ]),
      if (_conCuenta)
        // ignore: prefer_const_constructors
        BloquesAcceso()
      // El administrador mirando como un técnico: su propia cuenta no se toca desde aquí.
      else if (store.nube != null)
        Bloque('Cuenta', descripcion: 'Correo y contraseña.', [
          Text(
            'Estás viendo la app como ${widget.w.nombre} desde la cuenta de administrador. Cuando entre con su propia '
            'cuenta, aquí podrá cambiar su correo y su contraseña.',
            style: TextStyle(fontSize: 13.5, height: 1.4, color: P.textoSuave),
          ),
        ]),
    ],
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
      if (nube != null && !nube.esAdmin) {
        await nube.empezarOt(widget.t.id);
      } else {
        // La vista de prueba conserva la sesión del administrador; no puede tomar la OT como técnico.
        final t = store.tarea(widget.t.id);
        if (t == null ||
            !t.activa ||
            t.esPlantilla ||
            (t.estado != EstadoTrabajo.pendiente && t.estado != EstadoTrabajo.enCurso) ||
            (t.trabajadorIds.isNotEmpty && !t.trabajadorIds.contains(widget.w.id))) {
          throw StateError('La OT ya no está disponible para este técnico');
        }
        if (t.trabajadorIds.isEmpty) t.trabajadorIds = [widget.w.id];
        t.iniciadaEn ??= DateTime.now();
        store.cambiarEstado([t], EstadoTrabajo.enCurso);
        if (nube != null) await nube.guardado;
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

  Future<void> _pausar(bool pausar) async {
    if (ocupada) return;
    setState(() => ocupada = true);
    try {
      await store.pausarOt(widget.t, pausar);
    } catch (_) {
      if (mounted) avisoAbajo(context, 'No se pudo ${pausar ? 'pausar' : 'reanudar'}. Comprueba la conexión.');
    } finally {
      if (mounted) setState(() => ocupada = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    if (t.estado == EstadoTrabajo.realizado || t.hechaEl(hoy())) return const SizedBox.shrink();
    final enCurso = t.estado == EstadoTrabajo.enCurso && t.trabajadorIds.contains(widget.w.id);
    // Con una incidencia suya de esta orden aún sin respuesta: sin botones (el aviso va arriba, en el detalle).
    if (esperandoIncidencia(t)) return const SizedBox.shrink();
    // El inicio lo guarda la base; el del dispositivo queda para las OT empezadas antes de guardarlo.
    final desde = t.iniciadaEn ?? inicio;
    // Pausada: solo reanudar, con el tiempo parado al lado.
    if (enCurso && t.pausada) {
      return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        BotonAccion(ocupada ? 'Reanudando…' : 'Reanudar', icono: Icons.play_arrow_rounded, color: P.morado,
          onPressed: () => _pausar(false)),
        if (desde != null) _CronometroOt(t, desde),
      ]);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // El mismo icono de incidencia que en el resto de la app, en rojo.
        BotonAccion('Crear incidencia', icono: Icons.report_outlined, color: P.rojo,
          onPressed: () => abrirPanel(context, AvisoIncidenciaForm(tecnicoId: widget.w.id, origenTrabajoId: t.id))),
        if (!enCurso)
          BotonAccion(
            ocupada ? 'Empezando…' : 'Empezar OT',
            icono: Icons.play_arrow_rounded,
            color: P.morado,
            onPressed: _empezar,
          )
        else ...[
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
                minutosIniciales: desde == null ? null : (t.trabajado(desde).inSeconds / 60).ceil().clamp(1, 10080),
              ),
            ),
          ),
          BotonAccion(ocupada ? 'Pausando…' : 'Pausar', icono: Icons.pause_rounded, onPressed: () => _pausar(true)),
          // A la derecha de los botones: aparece y avanza sin moverlos de sitio.
          if (desde != null) _CronometroOt(t, desde),
        ],
      ],
    );
  }
}

/// El tiempo que lleva la OT en curso, en neutro y sin punto y las cifras de ancho fijo, para que no bailen.
class _CronometroOt extends StatefulWidget {
  final Tarea t;
  final DateTime inicio;
  const _CronometroOt(this.t, this.inicio);

  @override
  State<_CronometroOt> createState() => _CronometroOtState();
}

class _CronometroOtState extends State<_CronometroOt> {
  late final Timer _reloj = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _reloj; // Arranca al montarse.
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sin las pausas: pausada, el tiempo se queda parado.
    final total = widget.t.trabajado(widget.inicio).inSeconds.clamp(0, 604800);
    String dos(int n) => n.toString().padLeft(2, '0');
    final horas = total ~/ 3600, minutos = total % 3600 ~/ 60;
    final texto = '${horas > 0 ? '$horas:' : ''}${dos(minutos)}:${dos(total % 60)}';
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(P.radioControl),
        border: Border.all(color: P.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            semanticsLabel: '${total ~/ 60} minutos en esta OT',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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

  /// Dentro de una tarjeta que ya se abre entera al pulsarla (sin hover propio de la fila).
  final bool dentroDeTarjeta;
  const _FilaTrabajo(this.t, this.abrir, {this.mostrarDia = false, this.dentroDeTarjeta = false});

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
        lider: industrial
            ? _IconoActivo(t.activoId, color: (t.tipoMantenimiento ?? TipoMantenimiento.preventivo).color)
            : TipoIcono(t.tipo, size: 36),
        titulo: t.nombre,
        subtitulo: [
          if (industrial) dondeEs(t.activoId) else if (cliente != null) cliente.nombre,
          // Pultec: el día va en su insignia de la derecha.
          if (mostrarDia && !industrial && t.proximo != null) relativo(t.proximo!).toLowerCase(),
        ].where((x) => x.isNotEmpty).join(', '),
        derecha: industrial && esMovil(context)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillDia(t),
                  const SizedBox(height: 4),
                  Text(t.horario ?? 'Sin hora', style: TextStyle(fontSize: 13, color: P.textoSuave)),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (industrial) ...[_PillDia(t), const SizedBox(width: 12)],
                  Text(t.horario ?? 'Sin hora', style: TextStyle(fontSize: 13, color: P.textoSuave)),
                  if (marcable && !industrial) ...[const SizedBox(width: 6), _MarcaHecho(t)],
                ],
              ),
        onTap: dentroDeTarjeta ? null : () => abrir(t),
      ),
    );
  }
}

/// Pultec: cuándo toca la orden, claro de un vistazo y sin el rojo de «Pendiente»: atrasada (aviso rojo con
/// los días), hoy (morado), en curso (azul) o el día en gris.
class _PillDia extends StatelessWidget {
  final Tarea t;
  const _PillDia(this.t);

  @override
  Widget build(BuildContext context) {
    if (t.hechaEl(hoy()) || t.estado == EstadoTrabajo.realizado) return Pill('Hecha', P.verde, punto: true);
    if (t.estado == EstadoTrabajo.interrumpida) return Pill('Interrumpida', P.gris, icono: Icons.block_rounded);
    if (industrial && (t.pausada || esperandoIncidencia(t))) return Pill('Pausada', P.gris, icono: Icons.pause_rounded);
    if (t.estado == EstadoTrabajo.enCurso) return Pill('En curso', P.azul, punto: true);
    final p = t.proximo;
    if (p == null) return Pill('Sin fecha', P.textoSuave);
    final d = diasHasta(p);
    if (d < 0) return Pill('Atrasada ${-d} ${d == -1 ? 'día' : 'días'}', P.rojo, icono: Icons.warning_amber_rounded);
    if (d == 0) return Pill('Hoy', P.morado, punto: true);
    if (d == 1) return Pill('Mañana', P.textoSuave);
    final dia = _dias[p.weekday - 1];
    return Pill('${dia[0].toUpperCase()}${dia.substring(1, 3)} ${p.day}/${p.month}', P.textoSuave);
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
    final pendientes = _misTrabajos(w)
      .where((t) => t.proximo != null && t.estado.abierta && !t.hechaEl(hoy())).toList()
      ..sort((a, b) {
        final c = a.proximo!.compareTo(b.proximo!);
        return c != 0 ? c : _porHora(a, b);
      });
    if (pendientes.isEmpty) {
      return Vacio(icono: Icons.task_alt_rounded, titulo: 'Todo al día', texto: m('No tienes trabajos pendientes.'));
    }
    final grupos = <String, List<Tarea>>{};
    for (final t in pendientes) {
      final clave = diasHasta(t.proximo!) < 0 ? 'Atrasados' : '${relativo(t.proximo!)} · ${_diaLargo(t.proximo!)}';
      (grupos[clave] ??= []).add(t);
    }
    return ListView(children: [
      for (final clave in grupos.keys) ...[
        SeccionTarjeta(titulo: clave, subtitulo: '${grupos[clave]!.length}',
          children: [for (final t in grupos[clave]!) _FilaTrabajo(t, abrir, mostrarDia: clave == 'Atrasados')]),
        const SizedBox(height: huecoVista),
      ],
    ]);
  }
}

/// Pendientes, avisos enviados y partes del técnico, con filtros independientes de la navegación.
class _PanelTecnico extends StatefulWidget {
  final Trabajador w;
  final ValueChanged<Tarea> abrir;

  /// 0 órdenes, 1 incidencias, 2 histórico. En escritorio se elige en la barra lateral; en el móvil, con
  /// las pestañas de arriba ([pestanas]).
  final int vista;
  final ValueChanged<int> onVista;
  final bool pestanas;

  /// Máquinas elegidas al entrar (vacío = todas) y cómo volver a elegirlas (null = no hay entre qué elegir).
  final Set<String> maquinas;
  final VoidCallback? onMaquinas;
  const _PanelTecnico(
    this.w,
    this.abrir, {
    required this.vista,
    required this.onVista,
    required this.pestanas,
    required this.maquinas,
    this.onMaquinas,
  });
  @override
  State<_PanelTecnico> createState() => _PanelTecnicoState();
}

class _PanelTecnicoState extends State<_PanelTecnico> {
  int fecha = 0;
  int get vista => widget.vista;
  /// Otros días (atrasadas y próximas) plegados bajo lo de hoy.
  bool otrosDias = false;
  int? estado, resultado;
  TipoMantenimiento? tipo;
  String busqueda = '';
  Future<List<Informe>>? historial;
  static const fechas = ['Todas las fechas', 'Para hoy', 'Atrasadas', 'Próximos 7 días', 'Próximas'];

  bool _coincide(String texto, String? activo, TipoMantenimiento? clase, DateTime? dia) {
    if (tipo != null && tipo != clase) return false;
    if (!'$texto ${dondeEs(activo)}'.toLowerCase().contains(busqueda.toLowerCase().trim())) return false;
    final d = dia == null ? null : diasHasta(dia);
    return switch (fecha) {
      1 => d == 0, 2 => d != null && d < 0,
      3 => d != null && d >= 0 && d <= 7, 4 => d != null && d > 0, _ => true,
    };
  }

  void _vista(int n) => widget.onVista(n);

  @override
  void initState() {
    super.initState();
    if (vista == 2) historial = informes.delTecnico(widget.w.id);
  }

  @override
  void didUpdateWidget(_PanelTecnico old) {
    super.didUpdateWidget(old);
    if (old.vista != vista) {
      // Las fechas de planificación no deben ocultar el historial al cambiar de vista.
      fecha = 0;
      estado = null;
      if (vista == 2) historial = informes.delTecnico(widget.w.id);
    }
  }

  Widget _filtros() {
    final n = [tipo, if (fecha != 0) fecha, if (vista != 2) estado, if (vista == 2) resultado]
      .where((x) => x != null).length;
    MenuItemButton opcion(String nombre, bool marcado, VoidCallback elegir, {Color? color, IconData? icono}) => MenuItemButton(
      leadingIcon: icono != null
          ? Icon(icono, size: 18, color: P.textoSuave)
          : color == null ? null : Icon(Icons.circle, size: 8, color: color),
      trailingIcon: marcado ? Icon(Icons.check_rounded, size: 18, color: P.morado) : null,
      onPressed: () => setState(elegir), child: Text(nombre),
    );
    return MenuAnchor(
      menuChildren: [
        SubmenuButton(menuChildren: [
          opcion('Todos los tipos', tipo == null, () => tipo = null),
          for (final t in TipoMantenimiento.values)
            opcion(t.etiqueta, tipo == t, () => tipo = t, color: t.color),
        ], child: const Text('Tipo de intervención')),
        if (vista == 0) ...[
          SubmenuButton(menuChildren: [
            for (final (i, nombre) in fechas.indexed) opcion(nombre, fecha == i, () => fecha = i),
          ], child: const Text('Fecha prevista')),
          SubmenuButton(menuChildren: [
            opcion('Todos los estados', estado == null, () => estado = null),
            opcion('Pendiente', estado == 0, () => estado = 0),
            opcion('En curso', estado == 1, () => estado = 1),
          ], child: const Text('Estado de la orden')),
        ],
        if (vista == 1) SubmenuButton(menuChildren: [
          opcion('Todos los estados', estado == null, () => estado = null),
          for (final e in EstadoIncidencia.values) opcion(e.etiqueta, estado == e.index, () => estado = e.index, icono: e.icono),
        ], child: const Text('Estado de la incidencia')),
        if (vista == 2) SubmenuButton(menuChildren: [
          opcion('Todos los resultados', resultado == null, () => resultado = null),
          for (final (i, nombre) in ['Completadas', 'Con incidencias', 'No se pudo hacer'].indexed)
            opcion(nombre, resultado == i, () => resultado = i, icono: iconosResultado[i]),
        ], child: const Text('Resultado del parte')),
        const Divider(),
        MenuItemButton(onPressed: () => setState(() {
          tipo = null; fecha = 0; estado = null; resultado = null;
        }), child: const Text('Quitar filtros')),
      ],
      builder: (context, menu, _) => BotonAccion(n == 0 ? 'Filtros' : 'Filtros ($n)',
        icono: Icons.filter_list_rounded, onPressed: () => menu.isOpen ? menu.close() : menu.open()),
    );
  }

  Widget _vacio(String texto) => Vacio(icono: Icons.filter_alt_off_outlined,
    titulo: texto, texto: 'Prueba a cambiar los filtros o la búsqueda.');

  String _cuando(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Abierta (nadie la ha revisado aún): se corrige entera. Con OT o cerrada: solo se ve.
  void _verIncidencia(Incidencia i) => store.estadoIncidencia(i) == EstadoIncidencia.abierta
      ? abrirPanel(context, AvisoIncidenciaForm(tecnicoId: widget.w.id, original: i))
      : _verIncidenciaCerrada(i);

  void _verIncidenciaCerrada(Incidencia i) => abrirPanel(context, VentanaFormulario(
    etiqueta: 'Mis incidencias', titulo: 'Incidencia enviada', soloLectura: true, onGuardar: () {},
    campos: [
      Bloque('Aviso', primero: true, [
        Text(i.descripcion), const SizedBox(height: 12),
        Text('Enviada el ${_cuando(i.creada)}'),
        const SizedBox(height: 8), Pill(store.estadoIncidencia(i).etiqueta, store.estadoIncidencia(i).color),
      ]),
      Bloque('Activo', [Row(children: [
        _IconoActivo(i.activoId), const SizedBox(width: 8), Expanded(child: Text(dondeEs(i.activoId))),
      ])]),
      // Cada orden, con su estado y para abrirla: en la que la avisó y en la que se resuelve (la misma si la
      // oficina dijo «Seguir en la misma OT»).
      Bloque('Órdenes', [
        for (final (id, etiqueta) in [
          (i.origenTrabajoId, i.trabajoId != null && i.trabajoId == i.origenTrabajoId
              ? 'Avisada aquí; se resuelve en esta misma orden'
              : 'Orden en la que la avisaste'),
          if (i.trabajoId != null && i.trabajoId != i.origenTrabajoId) (i.trabajoId, 'Orden para resolverla'),
        ])
          if (store.tarea(id ?? '') case final t?)
            FilaLista(
              lider: puntoTipo(t.tipoMantenimiento?.color ?? P.gris),
              titulo: t.nombre,
              subtitulo: etiqueta,
              derecha: pillEstadoTecnico(t),
              onTap: t.trabajadorIds.contains(widget.w.id)
                  ? () {
                      Navigator.of(context).pop();
                      widget.abrir(t);
                    }
                  : null,
            )
          else
            Text('$etiqueta: sin orden asociada', style: TextStyle(color: P.textoSuave)),
      ]),
      if (i.fotos.isNotEmpty) Bloque('Fotos', [Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in i.fotos) FotoGuardada(f, width: 100, height: 100),
      ])]),
    ],
  ));

  @override
  Widget build(BuildContext context) {
    final sel = widget.maquinas;
    final pendientes = _misTrabajos(widget.w)
        .where((t) => t.estado.abierta && !t.hechaEl(hoy()) && _enMaquinas(t.activoId, sel))
        .toList()
      ..sort((a, b) => (a.proximo ?? DateTime(2100)).compareTo(b.proximo ?? DateTime(2100)));
    final avisos = store.incidencias.where((i) => (i.tecnicoId == widget.w.id ||
      (i.tecnicoId == null && (store.nube?.esTrabajador ?? false))) && _enMaquinas(i.activoId, sel)).toList()
      ..sort((a, b) => b.creada.compareTo(a.creada));
    final titulos = ['Mis órdenes', 'Incidencias', 'Histórico'];
    if (industrial) _mandarPartesInterrumpidas(widget.w);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // En el histórico no hacen falta las cifras de lo pendiente (para hoy, atrasadas, esta semana).
      if (vista != 2)
      _CifrasTecnico(widget.w, pendientes, filtro: vista == 0 ? fecha : 0,
        // Las máquinas elegidas al entrar, a la derecha del saludo; al pulsar se vuelven a elegir.
        accion: widget.onMaquinas == null ? null : BotonAccion(
          sel.isEmpty ? 'Todos los activos' : '${sel.length} ${sel.length == 1 ? 'activo' : 'activos'}',
          icono: Icons.precision_manufacturing_outlined, tooltip: 'Cambiar los activos en los que trabajas',
          onPressed: widget.onMaquinas!),
        onFiltro: (f) => setState(() {
          if (vista != 0) _vista(0);
          fecha = fecha == f ? 0 : f;
        })),
      if (vista != 2) const SizedBox(height: 18),
      if (vista == 0) _RespuestasOficina(widget.w, widget.abrir),
      // Una sola fila: el apartado (o las pestañas en el móvil), y a la derecha buscar y filtrar.
      BarraVista(
        izquierda: [
          if (widget.pestanas)
            Pestanas(opciones: ['Órdenes', 'Incidencias', 'Histórico'], seleccion: vista,
              onChanged: (n) { estado = null; _vista(n); })
          else
            // Abajo en la fila (a ras de buscar y filtros), pegado a la tabla.
            SizedBox(height: 40, child: Align(alignment: Alignment.bottomLeft, widthFactor: 1,
              child: Text(titulos[vista], style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700,
                letterSpacing: -.4, height: 1)))),
        ],
        derecha: [
          Buscador(hint: 'Buscar…', width: 220, onChanged: (s) => setState(() => busqueda = s)),
          _filtros(),
        ],
      ),
      const SizedBox(height: 12),
      Expanded(child: switch (vista) {
        1 => _listaIncidencias(avisos),
        2 => _historial(),
        _ => _listaPendientes(pendientes),
      }),
    ]);
  }

  Widget _listaPendientes(List<Tarea> pendientes) {
    final lista = pendientes.where((t) => _coincide(t.nombre, t.activoId, t.tipoMantenimiento, t.proximo)
      && (estado == null || (estado == 0 ? t.estado == EstadoTrabajo.pendiente : t.estado == EstadoTrabajo.enCurso))).toList();
    if (lista.isEmpty) return _vacio('No tienes órdenes pendientes con estos filtros');
    // En escritorio, en tablas con columnas como Órdenes de trabajo del administrador, por secciones (atrasadas,
    // hoy y el resto de días plegado); con un filtro de fecha, una sola. En el móvil, tarjetas.
    if (industrial && !widget.pestanas) {
      if (fecha != 0) return _TablaOrdenesTecnico(lista, widget.abrir);
      final atrasadas = lista.where((t) => t.proximo != null && diasHasta(t.proximo!) < 0).toList();
      final deHoy = lista.where((t) => t.proximo != null && diasHasta(t.proximo!) == 0).toList();
      final otros = lista.where((t) => !atrasadas.contains(t) && !deHoy.contains(t)).toList();
      Widget tabla(List<Tarea> ts) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        // Con muchas filas la tabla ocupa el alto que se le da y se desplaza por dentro.
        child: ts.length > 15
            ? SizedBox(height: 640, child: _TablaOrdenesTecnico(ts, widget.abrir))
            : _TablaOrdenesTecnico(ts, widget.abrir),
      );
      return ListView(children: [
        if (atrasadas.isNotEmpty) ...[_TituloSeccion('Atrasadas', atrasadas.length, P.rojo), tabla(atrasadas)],
        _TituloSeccion('Hoy', deHoy.length, P.morado),
        if (deHoy.isEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Tarjeta(child: Text('Hoy no tienes órdenes.',
            style: TextStyle(color: P.textoSuave, fontSize: 15))))
        else
          tabla(deHoy),
        if (otros.isNotEmpty) ...[
          _Plegable('Otros días', otros.length, abierto: otrosDias, onTap: () => setState(() => otrosDias = !otrosDias)),
          if (otrosDias) tabla(otros),
        ],
      ]);
    }
    // Con un filtro de fecha (o al pulsar una cifra) se ve la lista tal cual. Sin él: primero lo atrasado,
    // luego lo de hoy y el resto de días plegado debajo («Otros días»).
    final filas = <Object>[...lista];
    if (fecha == 0) {
      final atrasadas = lista.where((t) => t.proximo != null && diasHasta(t.proximo!) < 0).toList();
      final deHoy = lista.where((t) => t.proximo != null && diasHasta(t.proximo!) == 0).toList();
      final otros = lista.where((t) => !atrasadas.contains(t) && !deHoy.contains(t)).toList();
      filas
        ..clear()
        ..addAll([
          if (atrasadas.isNotEmpty) ...[('Atrasadas', atrasadas.length, P.rojo), ...atrasadas],
          ('Hoy', deHoy.length, P.morado),
          ...(deHoy.isEmpty ? ['vacio'] : deHoy),
          if (otros.isNotEmpty) ...[otros.length, if (otrosDias) ...otros],
        ]);
    }
    return ListView.builder(itemCount: filas.length, itemBuilder: (_, n) => switch (filas[n]) {
      final Tarea t => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        // Toda la tarjeta se abre y se marca al pasar el ratón (borde morado, como en el administrador).
        child: HoverCard(padding: EdgeInsets.zero, onTap: () => widget.abrir(t),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _FilaTrabajo(t, widget.abrir, mostrarDia: true, dentroDeTarjeta: true),
          Padding(padding: const EdgeInsets.fromLTRB(58, 0, 12, 10), child: Wrap(spacing: 8, runSpacing: 6, children: [
            PillTipo(t.tipoMantenimiento ?? TipoMantenimiento.preventivo, neutra: true),
            if (esperandoIncidencia(t)) Pill('Esperando respuesta a tu incidencia', P.gris, icono: Icons.schedule_rounded),
          ])),
        ])),
      ),
      (final String titulo, final int total, final Color color) => _TituloSeccion(titulo, total, color),
      final int total => _Plegable('Otros días', total, abierto: otrosDias,
        onTap: () => setState(() => otrosDias = !otrosDias)),
      _ => Padding(padding: const EdgeInsets.only(bottom: 8), child: Tarjeta(child: Text('Hoy no tienes órdenes.',
        style: TextStyle(color: P.textoSuave, fontSize: 15)))),
    });
  }

  Widget _listaIncidencias(List<Incidencia> avisos) {
    final lista = avisos.where((i) => _coincide(i.descripcion, i.activoId, i.gravedad.tipo, i.creada)
      && (estado == null || store.estadoIncidencia(i).index == estado)).toList();
    if (lista.isEmpty) return _vacio('No tienes incidencias enviadas con estos filtros');
    // Con alguna abierta, arriba el consejo de que aún se puede corregir.
    final consejo = lista.any((i) => store.estadoIncidencia(i) == EstadoIncidencia.abierta);
    if (industrial && !widget.pestanas) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (consejo)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Consejo('¿Se te ha olvidado algo? Toca una incidencia abierta para cambiarla. Cuando le asignen una OT ya no se podrá editar.'),
          ),
        Expanded(child: _tablaIncidencias(lista)),
      ]);
    }
    return ListView.builder(itemCount: lista.length + (consejo ? 1 : 0), itemBuilder: (_, n) {
      if (consejo && n == 0) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Consejo('¿Se te ha olvidado algo? Toca una incidencia abierta para cambiarla. Cuando le asignen una OT ya no se podrá editar.'),
        );
      }
      final i = lista[n - (consejo ? 1 : 0)];
      // Igual que las órdenes: la tarjeta entera se pulsa y se marca al pasar el ratón.
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: HoverCard(padding: EdgeInsets.zero,
        onTap: () => _verIncidencia(i),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Del color de su gravedad (no crítico ámbar, crítico rojo), no del de la orden de origen.
          FilaLista(lider: _IconoActivo(i.activoId, color: i.gravedad.color), titulo: i.descripcion,
            subtitulo: '${_cuando(i.creada)}\n${dondeEs(i.activoId)}',
            derecha: Pill(store.estadoIncidencia(i).etiqueta, store.estadoIncidencia(i).color, icono: store.estadoIncidencia(i).icono)),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(
            'Orden de origen: ${store.tarea(i.origenTrabajoId ?? '')?.nombre ?? 'Sin orden asociada'}'
            '${i.trabajoId == null ? '' : '\nOrden para resolverla: ${store.tarea(i.trabajoId!)?.nombre ?? 'Orden no disponible'}'}',
            style: TextStyle(color: P.textoSuave, fontSize: 12))),
        ]),
      ));
    });
  }

  /// Incidencias del técnico en escritorio, en tabla como la de Incidencias de la oficina.
  Widget _tablaIncidencias(List<Incidencia> lista) => SegunTamano(
    clave: (box) => (box.maxWidth > 1000, box.maxWidth > 760),
    builder: (context, box) {
      final ancho = box.maxWidth > 1000, medio = box.maxWidth > 760;
      return Align(
        alignment: Alignment.topCenter,
        child: _sinHueco(Tabla(
          id: 'incidencias-tecnico',
          menuColumnas: medio,
          columnas: [
            const Col('Incidencia', flex: 4, fija: true),
            if (medio) const Col('Activo', flex: 3),
            const Col('Gravedad', ancho: 170),
            if (ancho) const Col('Orden', flex: 3),
            const Col('Comunicada', ancho: 150),
            const Col('Estado', ancho: 120, derecha: true),
          ],
          filas: lista.length,
          onTap: (n) => _verIncidencia(lista[n]),
          pie: pieTabla(lista.length, lista.length == 1 ? 'incidencia' : 'incidencias'),
          celdas: (n) {
            final i = lista[n];
            final est = store.estadoIncidencia(i);
            final origen = store.tarea(i.origenTrabajoId ?? ''), resuelve = store.tarea(i.trabajoId ?? '');
            return [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: i.gravedad.color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Flexible(child: conNuevo(i.id, celdaTexto(i.descripcion, negrita: true))),
              ]),
              if (medio) celdaTexto(dondeEs(i.activoId), suave: true),
              Align(alignment: Alignment.centerLeft, child: PillTipo(i.gravedad.tipo)),
              if (ancho)
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  celdaTexto(resuelve != null && resuelve.id != origen?.id ? resuelve.nombre : origen?.nombre ?? '—'),
                  Text(
                    resuelve == null ? (origen == null ? 'Sin orden' : 'Avisada en esta orden')
                        : resuelve.id == origen?.id ? 'Se resuelve en esta orden' : 'Orden para resolverla',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                ]),
              celdaTexto(_cuando(i.creada), suave: true),
              Align(
                alignment: Alignment.centerRight,
                child: resuelve != null && resuelve.estado == EstadoTrabajo.enCurso && !resuelve.pausada
                    ? EstadoEnVivo(resuelve)
                    : Pill(est.etiqueta, est.color, icono: est.icono),
              ),
            ];
          },
        )),
      );
    },
  );

  /// Partes del técnico en escritorio, en tabla: lo último primero.
  Widget _tablaHistorial(List<Informe> lista) => SegunTamano(
    clave: (box) => (box.maxWidth > 1000, box.maxWidth > 760),
    builder: (context, box) {
      final ancho = box.maxWidth > 1000, medio = box.maxWidth > 760;
      return Align(
        alignment: Alignment.topCenter,
        child: _sinHueco(Tabla(
          id: 'historial-tecnico',
          menuColumnas: medio,
          columnas: [
            const Col('Orden de trabajo', flex: 4, fija: true),
            if (medio) const Col('Activo', flex: 3),
            if (ancho) const Col('Gravedad', ancho: 170),
            const Col('Resultado', ancho: 160),
            if (medio) const Col('Tiempo', ancho: 90),
            const Col('Fecha', ancho: 150, derecha: true),
          ],
          filas: lista.length,
          onTap: (n) {
            final t = store.tarea(lista[n].trabajoId);
            if (t != null) verInforme(context, lista[n], t);
          },
          pie: pieTabla(lista.length, lista.length == 1 ? 'parte' : 'partes'),
          celdas: (n) {
            final i = lista[n], t = store.tarea(i.trabajoId);
            return [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                celdaTexto(t?.nombre ?? 'Orden no disponible', negrita: true),
                if (i.notas.isNotEmpty || i.fotos.isNotEmpty)
                  Text(
                    [
                      if (i.notas.isNotEmpty) i.notas.split('\n').first,
                      if (i.fotos.isNotEmpty) '${i.fotos.length} ${i.fotos.length == 1 ? 'foto' : 'fotos'}',
                    ].join(', '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: P.textoSuave)),
              ]),
              if (medio) celdaTexto(dondeEs(t?.activoId), suave: true),
              if (ancho)
                Align(alignment: Alignment.centerLeft,
                  child: t?.tipoMantenimiento == null ? celdaTexto('—', suave: true) : PillTipo(t!.tipoMantenimiento!)),
              Align(alignment: Alignment.centerLeft,
                child: Pill(resultadosInforme[i.resultado], coloresResultado[i.resultado], icono: iconosResultado[i.resultado])),
              if (medio) celdaTexto(i.minutos == null ? '—' : duracionTexto(i.minutos!), suave: i.minutos == null),
              celdaTexto(_cuando(i.cuando), suave: true),
            ];
          },
        )),
      );
    },
  );

  Widget _historial() => FutureBuilder<List<Informe>>(future: historial, builder: (context, snap) {
    if (snap.hasError) {
      return Column(children: [const Text('No se pudo cargar el histórico.'),
        TextButton(onPressed: () => setState(() => historial = informes.delTecnico(widget.w.id)), child: const Text('Reintentar'))]);
    }
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final lista = snap.data!.where((i) {
      final t = store.tarea(i.trabajoId);
      return _coincide(t?.nombre ?? '', t?.activoId, t?.tipoMantenimiento, i.cuando)
        && (resultado == null || i.resultado == resultado);
    }).toList();
    if (lista.isEmpty) return _vacio('No tienes partes registrados con estos filtros');
    // Por días, de lo último a lo primero: una cabecera por día y debajo lo que se hizo.
    lista.sort((a, b) => b.cuando.compareTo(a.cuando));
    if (industrial && !widget.pestanas) return _tablaHistorial(lista);
    final filas = <Object>[];
    DateTime? dia;
    for (final i in lista) {
      final d = DateUtils.dateOnly(i.cuando);
      if (dia != d) {
        dia = d;
        filas.add(d);
      }
      filas.add(i);
    }
    const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
      'noviembre', 'diciembre'];
    return ListView.builder(itemCount: filas.length, itemBuilder: (_, n) {
      final f = filas[n];
      if (f is DateTime) {
        final cuantos = lista.where((i) => DateUtils.isSameDay(i.cuando, f)).length;
        final nombre = diasHasta(f) == 0 ? 'Hoy' : diasHasta(f) == -1 ? 'Ayer'
          : '${dias[f.weekday - 1][0].toUpperCase()}${dias[f.weekday - 1].substring(1)} ${f.day} de ${meses[f.month - 1]}'
            '${f.year == hoy().year ? '' : ' de ${f.year}'}';
        return Padding(
          padding: EdgeInsets.fromLTRB(4, n == 0 ? 0 : 14, 0, 8),
          child: Row(children: [
            Text(nombre, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('$cuantos', style: TextStyle(color: P.textoSuave)),
          ]),
        );
      }
      final i = f as Informe, t = store.tarea(i.trabajoId);
      final tipo = t?.tipoMantenimiento;
      final x = t == null ? null : store.incidenciaDeOt(t.id);
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: HoverCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        onTap: t == null ? null : () => verInforme(context, i, t),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _IconoActivo(t?.activoId, color: tipo?.color ?? P.textoSuave),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t?.nombre ?? 'Orden no disponible', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(dondeEs(t?.activoId), style: TextStyle(color: P.textoSuave, fontSize: 13)),
            if (i.notas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(i.notas, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (tipo != null) Pill(tipo.etiqueta, tipo.color, punto: true),
              if (x != null) Pill('De incidencia', P.rojo, icono: Icons.report_outlined),
              if (i.resultado != 0) Pill(resultadosInforme[i.resultado], coloresResultado[i.resultado], icono: iconosResultado[i.resultado]),
              if (i.minutos != null)
                Text(duracionTexto(i.minutos!), style: TextStyle(color: P.textoSuave, fontSize: 13)),
              if (i.fotos.isNotEmpty)
                Text('${i.fotos.length} ${i.fotos.length == 1 ? 'foto' : 'fotos'}',
                  style: TextStyle(color: P.textoSuave, fontSize: 13)),
            ]),
          ])),
          const SizedBox(width: 12),
          Text(hhmm(i.cuando.hour * 60 + i.cuando.minute), style: TextStyle(color: P.textoSuave, fontSize: 13)),
        ]),
      ));
    });
  });
}

/// Icono del activo en un círculo: del color pedido (el tipo de la OT, igual que su píldora)
/// o, si no se pide, del estado de mantenimiento del activo.
class _IconoActivo extends StatelessWidget {
  final String? activoId;
  final double size;
  final Color? color;
  const _IconoActivo(this.activoId, {this.size = 36, this.color});

  @override
  Widget build(BuildContext context) {
    final a = store.activo(activoId);
    final color = this.color ?? (a == null ? P.textoSuave : colorEstado(gravedadDe(a.id)));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle),
      child: a == null
          ? Icon(Icons.assignment_outlined, size: size * .53, color: color)
          : IconoActivo(a.icono, size: size * .53, color: color),
    );
  }
}

/// Saludo y tres cifras del técnico (hoy, atrasadas, esta semana), con el icono en su color.
/// Cada cifra filtra la lista por su fecha; pulsarla otra vez quita el filtro.
class _CifrasTecnico extends StatelessWidget {
  final Trabajador w;
  final List<Tarea> pendientes;
  final int filtro;
  final ValueChanged<int> onFiltro;

  /// Botón a la derecha del saludo (las máquinas elegidas).
  final Widget? accion;
  const _CifrasTecnico(this.w, this.pendientes, {required this.filtro, required this.onFiltro, this.accion});

  @override
  Widget build(BuildContext context) {
    int cuenta(bool Function(int) f) => pendientes.where((t) => t.proximo != null && f(diasHasta(t.proximo!))).length;
    final cifras = [
      (Icons.today_rounded, 'Para hoy', cuenta((d) => d == 0), P.morado, 1),
      (Icons.warning_amber_rounded, 'Atrasadas', cuenta((d) => d < 0), P.rojo, 2),
      (Icons.date_range_rounded, 'Esta semana', cuenta((d) => d >= 0 && d <= 7), P.teal, 3),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _diaLargo(hoy()),
          style: TextStyle(color: P.morado, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Hola, ${w.nombre}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: P.titulos, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.7),
              ),
            ),
            ?accion,
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final (i, (icono, texto, n, color, f)) in cifras.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: HoverCard(
                  marcado: filtro == f,
                  onTap: () => onFiltro(f),
                  child: Row(
                    children: [
                      // Mejorada: icono en cuadro redondeado, como las cifras de Inicio. En el móvil, sin icono
                      // (si no, no cabe la palabra).
                      if (!esMovil(context)) ...[Container(
                        width: P.mejorada ? 44 : 36,
                        height: P.mejorada ? 44 : 36,
                        decoration: P.mejorada
                            ? BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12))
                            : BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle),
                        child: Icon(icono, size: P.mejorada ? 23 : 18, color: color),
                      ),
                      const SizedBox(width: 12)],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.1)),
                            Text(
                              texto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: P.textoSuave),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Título de un grupo de la lista (Atrasadas, Hoy): punto de su color, nombre y cuántas en gris.
class _TituloSeccion extends StatelessWidget {
  final String titulo;
  final int total;
  final Color color;
  const _TituloSeccion(this.titulo, this.total, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(titulo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: P.texto)),
      const SizedBox(width: 8),
      Text('$total', style: TextStyle(fontSize: 14, color: P.textoSuave)),
    ]),
  );
}

/// Cabecera plegable de la lista: título, cuántas hay en gris y flecha que gira al abrir.
class _Plegable extends StatelessWidget {
  final String titulo;
  final int total;
  final bool abierto;
  final VoidCallback onTap;
  const _Plegable(this.titulo, this.total, {required this.abierto, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(P.radio),
        hoverColor: P.hoverFila,
        child: SizedBox(height: 40, child: Row(children: [
          const SizedBox(width: 8),
          AnimatedRotation(turns: abierto ? .25 : 0, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
            child: Icon(Icons.chevron_right_rounded, size: 20, color: P.textoSuave)),
          const SizedBox(width: 6),
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('$total', style: TextStyle(fontSize: 14, color: P.textoSuave)),
        ])),
      ),
    ),
  );
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

/// Apuntes del técnico mientras hace una OT. La tarjeta de la ficha y «Qué has hecho» del parte comparten el
/// mismo texto, así lo escrito en un sitio está en el otro. Se guardan en el dispositivo hasta cerrar la OT.
final _apuntes = <String, TextEditingController>{};

String _claveApuntes(Tarea t, Trabajador w) => 'ot_apuntes_${store.nube?.empresaId ?? 'demo'}_${w.id}_${t.id}';

TextEditingController _apuntesDe(Tarea t, Trabajador w) {
  final clave = _claveApuntes(t, w);
  return _apuntes.putIfAbsent(clave, () {
    final texto = TextEditingController();
    SharedPreferences.getInstance().then((prefs) {
      // Si ya se ha empezado a escribir antes de leerlos, manda lo escrito.
      if (texto.text.isEmpty) texto.text = prefs.getString(clave) ?? '';
      texto.addListener(() {
        // Con la OT ya cerrada, no se vuelve a guardar nada.
        if (_apuntes[clave] == texto) prefs.setString(clave, texto.text);
      });
    });
    return texto;
  });
}

Future<void> _borrarApuntes(Tarea t, Trabajador w) async {
  final clave = _claveApuntes(t, w);
  // Sin cerrar el texto: el parte que se está cerrando todavía lo está enseñando.
  _apuntes.remove(clave);
  await (await SharedPreferences.getInstance()).remove(clave);
}

/// El cuadro grande para tomar apuntes con la OT en curso.
class _ApuntesOt extends StatelessWidget {
  final Tarea t;
  final Trabajador w;
  const _ApuntesOt(this.t, this.w, {super.key});

  @override
  Widget build(BuildContext context) => SeccionTarjeta(
    titulo: 'Tus apuntes',
    sinFilas: true,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _apuntesDe(t, w),
              minLines: 7,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15, height: 1.45),
              decoration: const InputDecoration(
                hintText: 'Apunta lo que vas viendo y haciendo: qué has cambiado, qué queda pendiente…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se guardan solos en este dispositivo. Al cerrar la OT pasan a «Qué has hecho» del parte, donde puedes cambiarlos.',
              style: TextStyle(fontSize: 12.5, color: P.textoSuave),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Una foto tomada durante la OT, con su descripción.
class _FotoOt {
  /// Cambian al volver a hacer la foto (la descripción se queda).
  Uint8List _bytes;
  Uint8List get bytes => _bytes;
  set bytes(Uint8List b) {
    _bytes = b;
    _texto = null;
  }

  /// Como se guarda en el dispositivo; se calcula una vez, no en cada guardado.
  String? _texto;
  String get enTexto => _texto ??= base64Encode(_bytes);

  final descripcion = TextEditingController();
  _FotoOt(this._bytes);
}

/// Las fotos de una OT en curso. Como los apuntes: las comparten la ficha y el parte de cierre, y se guardan en el
/// dispositivo hasta cerrar la OT (las imágenes y, aparte, sus textos, para no reescribirlas a cada letra).
class _FotosDeOt extends ChangeNotifier {
  final String clave;
  final fotos = <_FotoOt>[];
  bool leyendo = false;

  /// Ya no se puede guardar en el dispositivo (sin sitio): siguen aquí hasta recargar.
  bool sinSitio = false;
  late final Future<void> listas = _leer();
  _FotosDeOt(this.clave) {
    listas;
  }

  bool get _vigente => _fotos[clave] == this;

  Future<void> _leer() async {
    final prefs = await SharedPreferences.getInstance();
    final imagenes = prefs.getStringList(clave) ?? const <String>[];
    final textos = prefs.getStringList('${clave}_textos') ?? const <String>[];
    for (final (n, imagen) in imagenes.indexed) {
      fotos.add(_nueva(base64Decode(imagen), n < textos.length ? textos[n] : ''));
    }
    notifyListeners();
  }

  /// Qué fotos tienen descripción («1» o «0» por cada una): para el punto de las miniaturas.
  String _marcas = '';

  _FotoOt _nueva(Uint8List bytes, [String texto = '']) {
    final foto = _FotoOt(bytes)..descripcion.text = texto;
    foto.descripcion.addListener(_guardarTextos);
    return foto;
  }

  Future<void> _guardarTextos() async {
    // El punto de las miniaturas aparece (o se va) al escribir.
    final marcas = [for (final f in fotos) f.descripcion.text.trim().isEmpty ? '0' : '1'].join();
    if (marcas != _marcas) {
      _marcas = marcas;
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    if (!_vigente) return;
    try {
      await prefs.setStringList('${clave}_textos', [for (final f in fotos) f.descripcion.text]);
    } catch (e) {
      debugPrint('Pultec: no se pudieron guardar las descripciones: $e');
    }
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_vigente) return;
    try {
      sinSitio = !await prefs.setStringList(clave, [for (final f in fotos) f.enTexto]);
    } catch (e) {
      debugPrint('Pultec: no se pudieron guardar las fotos: $e');
      sinSitio = true;
    }
    await _guardarTextos();
    notifyListeners();
  }

  /// Cámara o galería (en el móvil el navegador deja elegir).
  Future<void> anadir() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (r == null) return;
    leyendo = true;
    notifyListeners();
    await listas;
    for (final f in r.files.take(maxFotosInforme - fotos.length)) {
      try {
        fotos.add(_nueva(await comprimirFoto(f.bytes!)));
        notifyListeners();
      } catch (e) {
        debugPrint('Pultec: no se pudo leer la foto ${f.name}: $e');
      }
    }
    leyendo = false;
    await _guardar();
  }

  /// Cambia una foto por otra nueva, en el mismo sitio y con su descripción.
  Future<void> repetir(_FotoOt foto) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r == null) return;
    leyendo = true;
    notifyListeners();
    try {
      foto.bytes = await comprimirFoto(r.files.first.bytes!);
    } catch (e) {
      debugPrint('Pultec: no se pudo leer la foto ${r.files.first.name}: $e');
    }
    leyendo = false;
    await _guardar();
  }

  /// Pone [foto] en el sitio [destino]; las demás se corren. Se guarda al soltarla ([guardarOrden]).
  void mover(_FotoOt foto, int destino) {
    final de = fotos.indexOf(foto), a = destino.clamp(0, fotos.length - 1);
    if (de < 0 || de == a) return;
    fotos
      ..removeAt(de)
      ..insert(a, foto);
    notifyListeners();
  }

  Future<void> guardarOrden() => _guardar();

  Future<void> quitar(_FotoOt foto) async {
    fotos.remove(foto);
    notifyListeners();
    await _guardar();
  }

  /// «Fotos:» y la descripción de cada una con su número, para el parte ('' si ninguna tiene).
  String get resumen {
    final lineas = [
      for (final (n, f) in fotos.indexed)
        if (f.descripcion.text.trim().isNotEmpty) '${n + 1}. ${f.descripcion.text.trim()}',
    ];
    return lineas.isEmpty ? '' : 'Fotos:\n${lineas.join('\n')}';
  }
}

final _fotos = <String, _FotosDeOt>{};

String _claveFotos(Tarea t, Trabajador w) => 'ot_fotos_${store.nube?.empresaId ?? 'demo'}_${w.id}_${t.id}';

_FotosDeOt _fotosDe(Tarea t, Trabajador w) {
  final clave = _claveFotos(t, w);
  return _fotos.putIfAbsent(clave, () => _FotosDeOt(clave));
}

Future<void> _borrarFotos(Tarea t, Trabajador w) async {
  final clave = _claveFotos(t, w);
  _fotos.remove(clave);
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(clave);
  await prefs.remove('${clave}_textos');
}

/// Miniatura cuadrada de una foto de la OT, con su número; un punto morado si ya tiene descripción.
class _MiniaturaOt extends StatelessWidget {
  final _FotoOt foto;
  final int numero;
  final double lado;
  final bool elegida;
  final VoidCallback onTap;
  const _MiniaturaOt(this.foto, this.numero, {super.key, required this.onTap, this.lado = 104, this.elegida = false});

  @override
  Widget build(BuildContext context) {
    final descripcion = foto.descripcion.text.trim();
    return Semantics(
      button: true,
      label: 'Foto $numero${descripcion.isEmpty ? '' : ': $descripcion'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(P.radio),
        onTap: onTap,
        child: Container(
          width: lado,
          height: lado,
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(P.radio),
            border: Border.all(color: elegida ? P.morado : P.borde, width: elegida ? 3 : 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(P.radio),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Decodificada pequeña: con varias a la vista, el móvil va suelto.
                Image.memory(foto.bytes, fit: BoxFit.cover, cacheWidth: 320, gaplessPlayback: true),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$numero',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (descripcion.isNotEmpty)
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: P.morado,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Las miniaturas según se van haciendo y el cuadro para hacer otra. Al tocar una, se abre en grande; arrastrándola
/// (en el móvil, manteniéndola pulsada) se cambia de orden y las demás se apartan al momento.
class _ListaFotosOt extends StatefulWidget {
  final _FotosDeOt datos;
  const _ListaFotosOt(this.datos);

  @override
  State<_ListaFotosOt> createState() => _ListaFotosOtState();
}

class _ListaFotosOtState extends State<_ListaFotosOt> {
  static const _lado = 104.0, _hueco = 10.0;
  static const _paso = Duration(milliseconds: 260);

  _FotoOt? _arrastrada;

  _FotosDeOt get datos => widget.datos;

  Future<void> _ver(int n) => showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(backgroundColor: P.fondo, child: _VisorFotosOt(datos, n)),
  );

  void _soltar() {
    if (mounted) setState(() => _arrastrada = null);
    datos.guardarOrden();
  }

  Widget _foto(_FotoOt f, int n) {
    final miniatura = _MiniaturaOt(f, n + 1, onTap: () => _ver(n));
    // La que va en la mano: algo más grande y con sombra. En su sitio queda su sombra, atenuada.
    final enLaMano = Material(
      color: Colors.transparent,
      elevation: 10,
      borderRadius: BorderRadius.circular(P.radio),
      child: Transform.scale(scale: 1.08, child: _MiniaturaOt(f, n + 1, onTap: () {}, elegida: true)),
    );
    final hueco = Opacity(opacity: .25, child: miniatura);
    void empezar() => setState(() => _arrastrada = f);
    final tactil = switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    // Con el dedo hay que mantenerla pulsada, para poder desplazar la pantalla pasando por encima.
    return tactil
        ? LongPressDraggable<_FotoOt>(
            data: f,
            delay: const Duration(milliseconds: 250),
            feedback: enLaMano,
            childWhenDragging: hueco,
            onDragStarted: empezar,
            onDragEnd: (_) => _soltar(),
            child: miniatura,
          )
        : Draggable<_FotoOt>(
            data: f,
            feedback: enLaMano,
            childWhenDragging: hueco,
            onDragStarted: empezar,
            onDragEnd: (_) => _soltar(),
            child: MouseRegion(cursor: SystemMouseCursors.grab, child: miniatura),
          );
  }

  Widget _hacer() => InkWell(
    borderRadius: BorderRadius.circular(P.radio),
    onTap: () {
      if (!datos.leyendo) datos.anadir();
    },
    child: CustomPaint(
      painter: BordeDiscontinuo(P.morado.withValues(alpha: .7), BorderRadius.circular(P.radio)),
      child: datos.leyendo
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera_outlined, size: 28, color: P.morado),
                const SizedBox(height: 6),
                Text('Hacer foto', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: P.morado)),
              ],
            ),
    ),
  );

  /// La rejilla, con cada cosa en su sitio calculado: así, al cambiar el orden, se desliza hasta el nuevo.
  Widget _rejilla() => LayoutBuilder(
    builder: (context, box) {
      final columnas = max(1, ((box.maxWidth + _hueco) / (_lado + _hueco)).floor());
      final total = datos.fotos.length + (datos.fotos.length < maxFotosInforme ? 1 : 0);
      final filas = (total / columnas).ceil();
      double x(int n) => (n % columnas) * (_lado + _hueco);
      double y(int n) => (n ~/ columnas) * (_lado + _hueco);
      return AnimatedContainer(
        duration: _paso,
        curve: Curves.easeOutCubic,
        height: filas * _lado + (filas - 1) * _hueco,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (n, f) in datos.fotos.indexed)
              AnimatedPositioned(
                key: ObjectKey(f),
                duration: _paso,
                curve: Curves.easeOutCubic,
                left: x(n),
                top: y(n),
                width: _lado,
                height: _lado,
                child: _foto(f, n),
              ),
            if (datos.fotos.length < maxFotosInforme)
              AnimatedPositioned(
                key: const ValueKey('hacer'),
                duration: _paso,
                curve: Curves.easeOutCubic,
                left: x(datos.fotos.length),
                top: y(datos.fotos.length),
                width: _lado,
                height: _lado,
                child: _hacer(),
              ),
            // Encima, un destino quieto por sitio (las fotos se mueven; ellos no, y así no hay vaivén). Dejan pasar
            // los toques a la foto de debajo.
            for (var n = 0; n < datos.fotos.length; n++)
              Positioned(
                key: ValueKey('sitio-$n'),
                left: x(n),
                top: y(n),
                width: _lado,
                height: _lado,
                child: DragTarget<_FotoOt>(
                  onWillAcceptWithDetails: (d) {
                    if (!datos.fotos.contains(d.data)) return false;
                    datos.mover(d.data, n);
                    return true;
                  },
                  builder: (_, _, _) => const SizedBox.expand(),
                ),
              ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: datos,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rejilla(),
        const SizedBox(height: 10),
        Text(
          datos.fotos.isEmpty
              ? 'Hasta $maxFotosInforme fotos.'
              : _arrastrada != null
              ? 'Suéltala donde quieras.'
              : '${datos.fotos.length} de $maxFotosInforme. Toca una para abrirla'
                    '${datos.fotos.length > 1 ? '; arrástrala (en el móvil, mantén pulsada) para cambiar el orden' : ''}.',
          style: TextStyle(fontSize: 12.5, color: P.textoSuave),
        ),
        if (datos.sinSitio)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No caben en este dispositivo: no cierres ni recargues la página hasta enviar el parte.',
              style: TextStyle(fontSize: 13, color: P.ambar, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );
}

/// Las fotos de la OT a pantalla completa: se pasa de una a otra deslizando, con las flechas o con la tira de abajo,
/// y de cada una se escribe qué se ve, se vuelve a hacer o se borra.
class _VisorFotosOt extends StatefulWidget {
  final _FotosDeOt datos;
  final int inicio;
  const _VisorFotosOt(this.datos, this.inicio);

  @override
  State<_VisorFotosOt> createState() => _VisorFotosOtState();
}

class _VisorFotosOtState extends State<_VisorFotosOt> {
  late int n = widget.inicio;
  late final _paginas = PageController(initialPage: widget.inicio);

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _ir(int i) => _paginas.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);

  Future<void> _borrar(_FotoOt foto) async {
    if (!await confirmar(context, '¿Eliminar la foto ${n + 1}?', nota: 'Se borra también su descripción.')) return;
    await widget.datos.quitar(foto);
    if (!mounted) return;
    if (widget.datos.fotos.isEmpty) return Navigator.pop(context);
    setState(() => n = n.clamp(0, widget.datos.fotos.length - 1));
    _paginas.jumpToPage(n);
  }

  Widget _flecha(IconData icono, String texto, int destino) => IconButton.filled(
    tooltip: texto,
    style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: .5), foregroundColor: Colors.white),
    onPressed: () => _ir(destino),
    icon: Icon(icono, size: 28),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.datos,
    builder: (context, _) {
      final fotos = widget.datos.fotos;
      if (fotos.isEmpty) return const SizedBox.shrink();
      final i = n.clamp(0, fotos.length - 1);
      final foto = fotos[i];
      return Scaffold(
        backgroundColor: P.fondo,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Foto ${i + 1} de ${fotos.length}',
                            style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ),
                        BotonAccion('Listo', color: P.morado, onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(P.radio),
                        child: ColoredBox(
                          color: Colors.black,
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: _paginas,
                                itemCount: fotos.length,
                                onPageChanged: (p) => setState(() => n = p),
                                itemBuilder: (_, p) =>
                                    Image.memory(fotos[p].bytes, fit: BoxFit.contain, gaplessPlayback: true),
                              ),
                              if (i > 0)
                                Positioned(
                                  left: 8,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(child: _flecha(Icons.chevron_left_rounded, 'Anterior', i - 1)),
                                ),
                              if (i < fotos.length - 1)
                                Positioned(
                                  right: 8,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(child: _flecha(Icons.chevron_right_rounded, 'Siguiente', i + 1)),
                                ),
                              if (widget.datos.leyendo) const Center(child: CircularProgressIndicator()),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      // Cada foto, su campo: al pasar de una a otra no se arrastra el texto.
                      key: ObjectKey(foto),
                      controller: foto.descripcion,
                      minLines: 2,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                      decoration: const InputDecoration(hintText: 'Descripción: qué se ve en esta foto'),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fotos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, p) => _MiniaturaOt(
                          fotos[p],
                          p + 1,
                          key: ObjectKey(fotos[p]),
                          lado: 64,
                          elegida: p == i,
                          onTap: () => _ir(p),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (!widget.datos.leyendo) widget.datos.repetir(foto);
                              },
                              icon: const Icon(Icons.photo_camera_outlined, size: 20),
                              label: const Text('Volver a hacer'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: P.rojo),
                              onPressed: () => _borrar(foto),
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              label: const Text('Eliminar'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// La misma separación entre todos los bloques de la orden (cabecera, botones y tarjetas).
const _huecoOt = huecoVista + 4;

class _DetalleTrabajo extends StatelessWidget {
  final Tarea t;
  final Trabajador w;
  final VoidCallback onVolver;
  const _DetalleTrabajo(this.t, this.w, {required this.onVolver});

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
    final plan = industrial ? store.planes.where((p) => p.id == t.planId).firstOrNull : null;
    final procedimiento = t.procedimiento.isNotEmpty ? t.procedimiento : plan?.procedimiento ?? '';
    final repuestos = t.repuestos.isNotEmpty ? t.repuestos : plan?.repuestos ?? '';
    final incidencia = industrial ? store.incidenciaDeOt(t.id) : null;
    // Su incidencia de esta orden aún sin respuesta: la OT queda pausada; arriba el aviso y lo demás, atenuado.
    final esperando = industrial && !hecha && esperandoIncidencia(t);
    final pausada = industrial && !hecha && (t.pausada || esperando);
    // Su incidencia de esta orden: la que espera respuesta o, ya respondida, la de esta pausa (para explicar qué
    // ha dicho la oficina).
    final deEstaOt = store.incidencias.where((i) => i.origenTrabajoId == t.id).toList()
      ..sort((a, b) => a.creada.compareTo(b.creada));
    final propia = esperando
        ? deEstaOt.where((i) => store.estadoIncidencia(i) == EstadoIncidencia.abierta).lastOrNull
        : t.pausadaDesde == null
        ? null
        : deEstaOt.where((i) => !i.creada.isBefore(t.pausadaDesde!.subtract(const Duration(minutes: 2)))).lastOrNull;
    // Pausada por su aviso y la oficina lo unió a la incidencia que ya resolvía esta orden: esa, actualizada.
    final unida = !esperando && propia == null && t.pausada && deEstaOt.isEmpty ? store.incidenciaDeOt(t.id) : null;
    final suya = propia ?? unida;
    final respuesta = esperando || suya == null
        ? null
        : unida != null
        ? 'La oficina ha unido tu aviso a la incidencia de esta orden, que sube de nivel: se resuelve aquí. Reanúdala para continuar.'
        : switch (store.estadoIncidencia(suya)) {
            EstadoIncidencia.desestimada => 'La oficina ha desestimado tu incidencia: sigue con esta orden. Reanúdala para continuar.',
            _ when suya.trabajoId == t.id => 'La oficina ha respondido a tu incidencia: se resuelve en esta misma orden. Reanúdala para continuar.',
            _ => 'La oficina ha respondido a tu incidencia. Reanúdala para continuar.',
          };
    // Interrumpida: el trabajo sigue en la OT correctiva que creó la oficina.
    final sigueEn = t.estado == EstadoTrabajo.interrumpida
        ? store.tarea(store.incidencias.where((i) => i.origenTrabajoId == t.id && i.trabajoId != t.id).lastOrNull?.trabajoId)
        : null;
    // Sale de una incidencia avisada en otra OT, que se interrumpió.
    final vieneDe = incidencia?.origenTrabajoId == null || incidencia!.origenTrabajoId == t.id
        ? null
        : store.tarea(incidencia.origenTrabajoId);
    Widget atenuar(Widget w) => pausada ? IgnorePointer(child: Opacity(opacity: .4, child: w)) : w;
    return ListView(
      padding: const EdgeInsets.only(top: _huecoOt, bottom: _huecoOt),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Volver',
              onPressed: onVolver,
              icon: Icon(CupertinoIcons.chevron_left, size: 22, color: P.texto),
            ),
            const SizedBox(width: 4),
            // Pultec: el icono, del color del tipo de la orden (como su píldora), no del estado del activo.
            industrial
                ? _IconoActivo(t.activoId, size: 44, color: t.tipoMantenimiento?.color)
                : TipoIcono(t.tipo, size: 44),
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
                      if (pausada)
                        Pill('Pausada', P.gris, icono: Icons.pause_rounded)
                      else if (industrial && !hecha && t.estado == EstadoTrabajo.enCurso)
                        Pill('En curso', P.morado, punto: true)
                      // Pultec: pendiente, neutra con el círculo abierto (como en Órdenes de trabajo).
                      else if (industrial && !hecha && t.estado.abierta)
                        Pill(t.estado.etiqueta, P.gris, icono: Icons.radio_button_unchecked_rounded)
                      else
                        Pill(hecha ? 'Hecho' : t.estado.etiqueta, hecha ? P.verde : t.estado.color, punto: true),
                      // Pultec: su tipo (preventivo, correctivo…); la criticidad «Rutinaria» no se usa.
                      if (!industrial)
                        Pill(t.criticidad.etiqueta, t.criticidad.color)
                      else if (t.tipoMantenimiento != null)
                        PillTipo(t.tipoMantenimiento!, neutra: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: _huecoOt),
        if (t.estado == EstadoTrabajo.interrumpida) ...[
          Tarjeta(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.block_rounded, size: 22, color: P.textoSuave),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('OT interrumpida', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    sigueEn == null
                        ? 'La oficina la ha cerrado por una incidencia.'
                        : 'La oficina la ha cerrado por una incidencia; el trabajo sigue en «${sigueEn.nombre}».',
                    style: TextStyle(fontSize: 14, color: P.textoSuave),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: _huecoOt),
        ],
        if (pausada) ...[
          Tarjeta(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.pause_circle_outline_rounded, size: 22, color: P.textoSuave),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('OT pausada', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    esperando
                        ? 'Esperando la respuesta de la oficina a tu incidencia. Cuando responda, podrás reanudarla.'
                        : respuesta ?? 'El tiempo no cuenta mientras está pausada. Reanúdala cuando vuelvas.',
                    style: TextStyle(fontSize: 14, color: P.textoSuave),
                  ),
                  if (suya != null && suya.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('«${suya.descripcion}»', style: TextStyle(fontSize: 14, color: P.texto)),
                  ],
                ]),
              ),
            ]),
          ),
          const SizedBox(height: _huecoOt),
        ],
        if (!esperando) ...[
          _AccionesTrabajo(t, w),
          const SizedBox(height: _huecoOt),
        ],
        atenuar(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (industrial && !hecha && t.estado == EstadoTrabajo.enCurso && t.trabajadorIds.contains(w.id)) ...[
          _ApuntesOt(t, w, key: ValueKey(t.id)),
          const SizedBox(height: _huecoOt),
          SeccionTarjeta(
            titulo: 'Fotos',
            sinFilas: true,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: _ListaFotosOt(_fotosDe(t, w))),
            ],
          ),
          const SizedBox(height: _huecoOt),
        ],
        SeccionTarjeta(
          titulo: 'Información',
          children: [
            _dato(m('Cliente'), industrial ? dondeEs(t.activoId) : cliente?.nombre ?? '—'),
            _dato('Dirección', t.ubicacion.isNotEmpty ? t.ubicacion : (cliente?.direccionCompleta ?? '—')),
            // Hecha: el día en que se hizo (ya no tiene próxima).
            _dato('Cuándo', [
              if (t.proximo != null) relativo(t.proximo!) else if (t.ultimo != null) fecha(t.ultimo!),
              t.horario ?? 'Sin hora',
            ].join(', ')),
            if (maquina.isNotEmpty) _dato('Máquina', maquina),
            if (t.descripcion.isNotEmpty) _dato('Descripción', t.descripcion),
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
        // Pultec: cómo se hace y qué hace falta (los de la OT o, si no tiene, los de su mantenimiento).
        if (procedimiento.isNotEmpty || repuestos.isNotEmpty) ...[
          const SizedBox(height: _huecoOt),
          SeccionTarjeta(
            titulo: 'Procedimiento y repuestos',
            children: [
              if (procedimiento.isNotEmpty) _dato('Procedimiento', procedimiento),
              if (repuestos.isNotEmpty) _dato('Repuestos', repuestos),
            ],
          ),
        ],
        // Pultec: la checklist de la orden, que el técnico marca en el momento.
        if (industrial && checklistDe(t).isNotEmpty) ...[
          const SizedBox(height: _huecoOt),
          ChecklistOt(t, puedeMarcar: !hecha && t.estado.abierta, por: w.id),
        ],
        // Sale de una incidencia: lo que se comunicó, quién, cuándo y sus fotos.
        if (incidencia != null) ...[
          const SizedBox(height: _huecoOt),
          SeccionTarjeta(
            titulo: 'Incidencia original',
            children: [
              _dato('Qué pasa', incidencia.descripcion),
              if (vieneDe != null) _dato('Viene de', '«${vieneDe.nombre}», interrumpida'),
              _dato('Comunicada', [
                (incidencia.tecnicoId == null ? null : store.trabajador(incidencia.tecnicoId!))?.nombre ?? 'Oficina',
                fecha(incidencia.creada),
              ].join(', ')),
              if (incidencia.fotos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in incidencia.fotos)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(P.radio),
                          child: FotoGuardada(f, width: 140, height: 105),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: _huecoOt),
        SeccionTarjeta(
          titulo: lista == null || lista.length < 2 ? 'Informes' : 'Informes (${lista.length})',
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
        ])),
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
  /// Al cerrar la OT, «Qué has hecho» son los apuntes tomados mientras se hacía (se pueden cambiar aquí).
  late final bool _conApuntes = industrial && widget.cerrarOt;
  late final notas = _conApuntes ? _apuntesDe(widget.t, widget.w) : TextEditingController();
  final material = TextEditingController(), minutos = TextEditingController();
  final firmante = TextEditingController();
  final fotos = <Uint8List>[];

  /// Al cerrar la OT, las fotos tomadas mientras se hacía.
  late final _FotosDeOt? deOt = _conApuntes ? _fotosDe(widget.t, widget.w) : null;
  final firma = Firma();
  int resultado = 0;
  bool intentado = false, guardando = false, leyendoFotos = false;

  /// Pultec: activo principal de la OT, cuyo contador apunta el técnico al cerrar (en vez de los minutos).
  late final raiz = industrial ? raizActivo(widget.t.activoId) : null;
  final contador = TextEditingController();

  /// Pultec: el mantenimiento pide una medición (verificación con dato).
  late final plan = industrial ? store.planes.where((p) => p.id == widget.t.planId && p.conMedicion).firstOrNull : null;
  final medida = TextEditingController();

  /// Valor medido (null = vacío; NaN = no válido). Obligatorio si se pide medición y se ha hecho el trabajo.
  double? get _medida {
    final c = medida.text.trim().replaceAll(',', '.');
    if (c.isEmpty) return null;
    return double.tryParse(c) ?? double.nan;
  }

  bool get _faltaMedida => plan != null && resultado != 2 && (_medida == null || _medida!.isNaN);

  @override
  void initState() {
    super.initState();
    notas; // Se toma al abrir: los apuntes guardados se leen ya.
    deOt; // Y las fotos.
    if (widget.minutosIniciales != null) minutos.text = '${widget.minutosIniciales}';
    if (raiz != null) contador.text = horasHoy(raiz!).toStringAsFixed(0);
  }

  /// Horas del contador escritas (null = vacío; -1 = no válidas).
  double? get _contador {
    final c = contador.text.trim().replaceAll(',', '.');
    if (c.isEmpty) return null;
    final n = double.tryParse(c);
    return n == null || n < 0 ? -1 : n;
  }

  @override
  void dispose() {
    // Los apuntes son compartidos: no se cierran con el parte.
    for (final c in [if (!_conApuntes) notas, material, minutos, firmante, contador, medida]) {
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
        debugPrint('Pultec: no se pudo leer la foto ${f.name}: $e');
      }
    }
    if (mounted) setState(() => leyendoFotos = false);
  }

  /// Por dónde va el guardado: qué se está haciendo y cuánto lleva (null = sin saber cuánto queda).
  final _progreso = ValueNotifier<(String, double?)>(('Preparando el parte…', null));

  /// El parte ya está guardado y la ventana se está cerrando.
  bool _enviado = false;

  Future<void> _guardar() async {
    if (guardando || _enviado || leyendoFotos || (deOt?.leyendo ?? false)) return;
    if (notas.text.trim().isEmpty || _minutos == -1 || _contador == -1 || _faltaMedida) {
      setState(() => intentado = true);
      return;
    }
    // Desde el primer toque: sin dobles envíos y con el progreso a la vista.
    _progreso.value = ('Preparando el parte…', null);
    setState(() => guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    // Abajo y centrado, como el de «Incidencia enviada»; lo que sale bien, con su check verde.
    void aviso(String texto, {bool bien = false}) =>
        avisoAbajoEn(messenger, texto, icono: bien ? Icons.check_circle_rounded : null);
    try {
      await _enviar(aviso);
    } catch (e) {
      debugPrint('Pultec: no se pudo guardar el informe: $e');
      aviso('No se pudo guardar el informe. Inténtalo de nuevo.');
    } finally {
      // Pase lo que pase, la ventana no se queda bloqueada.
      if (mounted && !_enviado) setState(() => guardando = false);
    }
  }

  /// Deja pintar el progreso antes de un trabajo que ocupa la pantalla.
  Future<void> _anunciar(String texto, [double? avance]) {
    _progreso.value = (texto, avance);
    return Future<void>.delayed(const Duration(milliseconds: 40));
  }

  Future<void> _enviar(void Function(String, {bool bien}) aviso) async {
    await _anunciar('Preparando el parte…');
    await deOt?.listas;
    // Sin minutos escritos: el tiempo desde que pulsó «Empezar OT» hasta ahora.
    var minutosOt = raiz != null ? null : _minutos;
    if (minutosOt == null && raiz == null) {
      final empezo = DateTime.tryParse(
        (await SharedPreferences.getInstance()).getString('ot_inicio_${store.nube?.empresaId ?? 'demo'}_${widget.t.id}') ?? '',
      );
      if (empezo != null) minutosOt = DateTime.now().difference(empezo).inMinutes.clamp(1, 10080);
    }
    final subido = await informes.crear(
        Informe(
          trabajoId: widget.t.id,
          trabajadorId: widget.w.id,
          resultado: resultado,
          // Las descripciones de las fotos van al final del texto, numeradas como las fotos.
          notas: [notas.text.trim(), if (deOt?.resumen case final r? when r.isNotEmpty) r].join('\n\n'),
          material: material.text.trim(),
          minutos: minutosOt,
          valor: plan == null || _medida == null || _medida!.isNaN ? null : _medida,
          firmante: firma.vacia || industrial ? '' : firmante.text.trim(),
        ),
        fotos: deOt == null ? fotos : [for (final f in deOt!.fotos) f.bytes],
        firma: await firma.png(),
        paso: (hechos, total) => _progreso.value = (
          hechos < total - 1 ? 'Subiendo fotos… ${hechos + 1} de ${total - 1}' : 'Guardando el parte…',
          hechos / total,
        ),
      );
    await _anunciar(widget.cerrarOt && resultado != 2 ? 'Cerrando la orden…' : 'Terminando…', 1);
    // Pultec: el resultado queda en la OT (con incidencia o sin hacer, sale como aviso) y la lectura del
    // contador, en su activo principal.
    if (industrial) {
      // La checklist sin tocar también queda en la OT (todos los pasos «sin hacer»), para el parte y el histórico.
      if (widget.t.checklist.isEmpty && checklistDe(widget.t).isNotEmpty) {
        // Sin esperar a la red: ya queda puesta aquí y sube por detrás.
        unawaited(store.marcarChecklist(widget.t, checklistDe(widget.t)).catchError((Object e) {
          debugPrint('Pultec: no se pudo guardar la checklist: $e');
        }));
      }
      widget.t
        ..resultado = resultado
        ..resultadoResuelto = false;
      final h = _contador;
      if (raiz != null && h != null && h >= 0) {
        // Cuánto se aleja la lectura de lo que suman sus turnos (la base lo calcula igual al apuntarla).
        if (raiz!.usoPlanificado) raiz!.desvio = h - horasHoy(raiz!);
        raiz!
          ..horas = h
          ..fechaLectura = hoy();
        store.guardarActivo(raiz!);
        // Una cuenta de técnico no sube activos con la sincronización: la lectura va por su función.
        if (store.nube?.esTrabajador ?? false) {
          unawaited(store.nube!.apuntarContador(raiz!.id, h).catchError((Object e) {
            debugPrint('Pultec: no se pudo apuntar el contador: $e');
            aviso('No se pudo guardar la lectura del contador.');
          }));
        }
      }
      if (resultado == 2) store.guardarTarea(widget.t);
      // Con incidencia o sin hacer queda una incidencia abierta. Con sesión la crea la base al recibir el parte.
      if (resultado > 0 && store.nube == null && widget.t.activoId != null) {
        store.guardarIncidencia(Incidencia(
          id: store.nuevoId(),
          activoId: widget.t.activoId!,
          tecnicoId: widget.w.id,
          origenTrabajoId: widget.t.id,
          descripcion: [
            resultado == 1 ? 'Con incidencias en «${widget.t.nombre}»' : 'No se pudo hacer «${widget.t.nombre}»',
            if (notas.text.trim().isNotEmpty) notas.text.trim(),
          ].join(': '),
        ));
      }
    }
    if (widget.cerrarOt && resultado != 2) {
      store.marcarHecha(widget.t);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ot_inicio_${store.nube?.empresaId ?? 'demo'}_${widget.t.id}');
      await _borrarApuntes(widget.t, widget.w);
      await _borrarFotos(widget.t, widget.w);
    }
    _enviado = true;
    if (mounted) Navigator.pop(context);
    aviso(
      !subido
          ? 'Sin conexión: el informe se ha guardado aquí y se subirá al volver'
          : widget.cerrarOt && resultado != 2
          ? 'Orden cerrada y parte enviado'
          : 'Informe guardado',
      bien: subido,
    );
  }

  static String? _n(double? v) => v == null ? null : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

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

  /// Mientras se guarda: la ventana atenuada, qué se está haciendo y la barra. No se puede cerrar ni tocar.
  Widget _guardando() => Stack(
    children: [
      const ModalBarrier(dismissible: false, color: Color(0x99000000)),
      Center(
        child: Material(
          color: P.superficie,
          borderRadius: BorderRadius.circular(P.radio),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SizedBox(
              width: 280,
              child: ValueListenableBuilder(
                valueListenable: _progreso,
                builder: (_, valor, _) {
                  final (texto, avance) = valor;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: avance == null
                            ? LinearProgressIndicator(minHeight: 8, color: P.morado)
                            // De un paso al siguiente, la barra avanza suave.
                            : TweenAnimationBuilder<double>(
                                tween: Tween(end: avance),
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: P.morado),
                              ),
                      ),
                      const SizedBox(height: 10),
                      Text('No cierres la página.', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !guardando,
    child: Stack(
      fit: StackFit.expand,
      children: [_ventana(context), if (guardando) _guardando()],
    ),
  );

  Widget _ventana(BuildContext context) => VentanaFormulario(
    etiqueta: 'Informe',
    titulo: widget.t.nombre,
    onGuardar: _guardar,
    avisos: [
      if (intentado && notas.text.trim().isEmpty) ('Cuenta qué has hecho', () {}),
      if (intentado && _minutos == -1) ('El tiempo va en minutos', () {}),
      if (intentado && _contador == -1) ('El contador va en horas, con números', () {}),
      if (intentado && _faltaMedida) ('Falta ${plan!.medicionNombre.toLowerCase()}', () {}),
    ],
    campos: [
      Bloque('Resultado', primero: true, descripcion: m('Cómo ha ido el trabajo.'), [
        Pestanas(opciones: resultadosInforme, seleccion: resultado, onChanged: (i) => setState(() => resultado = i)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Pill(resultadosInforme[resultado], coloresResultado[resultado], icono: iconosResultado[resultado]),
        ),
      ]),
      if (plan != null)
        Bloque(
          'Medición',
          descripcion: [
            if (plan!.medicionMin != null || plan!.medicionMax != null)
              'Admitido de ${_n(plan!.medicionMin) ?? '…'} a ${_n(plan!.medicionMax) ?? '…'} ${plan!.medicionUnidad}'.trim(),
            'Si se sale, la oficina recibe una incidencia.',
          ].join('. '),
          [
            campo(
              plan!.medicionUnidad.isEmpty ? plan!.medicionNombre : '${plan!.medicionNombre} (${plan!.medicionUnidad})',
              medida,
              obligatorio: resultado != 2,
              teclado: const TextInputType.numberWithOptions(decimal: true, signed: true),
              error: intentado && _faltaMedida ? 'Escribe el valor medido, con números' : null,
            ),
          ],
        ),
      Bloque('Qué has hecho', descripcion: 'Lo que ha pasado, lo que has cambiado y lo que queda pendiente.', [
        campo(
          industrial ? 'Trabajo realizado y mediciones' : 'Notas',
          notas,
          lineas: 6,
          hint: 'Ej.: revisado el motor, cambiada la correa. Falta pedir una pieza.',
          error: intentado && notas.text.trim().isEmpty ? 'Escribe qué has hecho' : null,
        ),
      ]),
      Bloque(
        raiz != null ? 'Repuestos y contador' : 'Material y tiempo',
        descripcion: raiz != null
            ? 'Lo que has usado y las horas que marca ahora el contador de ${raiz!.titulo}.'
            : 'Lo que has usado y cuánto has tardado.',
        [
          campo(industrial ? 'Repuestos' : 'Material', material, lineas: 2, hint: 'Ej.: 1 correa, 2 l de aceite'),
          if (raiz != null)
            campo(
              'Contador (h)',
              contador,
              hint: 'Ej.: 6240',
              error: intentado && _contador == -1 ? 'Escribe las horas del contador, con números' : null,
            )
          else
            campo(
              'Minutos',
              minutos,
              hint: 'Ej.: 90',
              error: intentado && _minutos == -1 ? 'Escribe solo los minutos, con números' : null,
            ),
        ],
      ),
      Bloque('Fotos', descripcion: m('Del equipo, de la avería o del trabajo terminado. Hasta $maxFotosInforme.'), [
        if (deOt case final d?)
          _ListaFotosOt(d)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 0; n < fotos.length; n++) _miniatura(n),
              if (fotos.length < maxFotosInforme) _anadir(),
            ],
          ),
      ]),
      Bloque(
        industrial ? 'Firma del responsable' : m('Firma del cliente'),
        descripcion: 'Que firme con el dedo en el recuadro. Si no está, déjalo en blanco.',
        [
          PanelFirma(firma),
          // Pultec: quien hace el parte ya ha entrado con su usuario; no hace falta su nombre.
          if (!industrial) campo('Nombre de quien firma', firmante, hint: 'Ej.: Ana López, presidenta'),
        ],
      ),
    ],
  );
}


// ── Respuestas de la oficina y parte de las OT interrumpidas ─────────

/// OT interrumpidas cuyo aviso ya ha visto el técnico (en el dispositivo).
final _interrumpidasVistas = <String>{};
bool _vistasLeidas = false;
String _claveVistas(Trabajador w) => 'ot_interrumpidas_vistas_${store.nube?.empresaId ?? 'demo'}_${w.id}';

/// Donde sigue el trabajo de una OT interrumpida: la OT de la incidencia que se avisó desde ella.
Tarea? sigueEnOt(Tarea t) => store.tarea(
  store.incidencias.where((i) => i.origenTrabajoId == t.id && i.trabajoId != null && i.trabajoId != t.id).lastOrNull?.trabajoId,
);

/// Arriba de «Mis órdenes»: lo que ha respondido la oficina a sus incidencias. Pausada con la incidencia ya
/// respondida → puede reanudar; interrumpida → dónde sigue el trabajo (hasta que la abre o lo cierra).
class _RespuestasOficina extends StatefulWidget {
  final Trabajador w;
  final void Function(Tarea) abrir;
  const _RespuestasOficina(this.w, this.abrir);
  @override
  State<_RespuestasOficina> createState() => _RespuestasOficinaState();
}

class _RespuestasOficinaState extends State<_RespuestasOficina> {
  @override
  void initState() {
    super.initState();
    if (!_vistasLeidas) {
      SharedPreferences.getInstance().then((prefs) {
        _interrumpidasVistas.addAll(prefs.getStringList(_claveVistas(widget.w)) ?? const []);
        _vistasLeidas = true;
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _visto(String clave) async {
    setState(() => _interrumpidasVistas.add(clave));
    await (await SharedPreferences.getInstance()).setStringList(_claveVistas(widget.w), _interrumpidasVistas.toList());
  }

  @override
  Widget build(BuildContext context) {
    if (!industrial || !_vistasLeidas) return const SizedBox.shrink();
    final mias = store.tareas.where((t) => !t.esPlantilla && t.trabajadorIds.contains(widget.w.id));
    // (clave para quitarlo, o null si se va solo; la orden que abre; el texto).
    final avisos = <(String?, Tarea, String)>[
      for (final t in mias)
        // Respondida: su incidencia (o, si la oficina la unió a la de esta orden, esa). Se va al reanudar.
        if (t.pausada && !esperandoIncidencia(t) && store.incidencias.any((i) => i.origenTrabajoId == t.id || i.trabajoId == t.id))
          (null, t, 'La oficina ha respondido a tu incidencia: ya puedes reanudar «${t.nombre}».')
        else if (t.estado == EstadoTrabajo.noRealizado && t.iniciadaEn != null && !_interrumpidasVistas.contains(t.id))
          (t.id, t, 'La oficina ha cancelado «${t.nombre}», que estabas haciendo. Tu parte con lo hecho se ha enviado.')
        else if (t.estado == EstadoTrabajo.interrumpida && !_interrumpidasVistas.contains(t.id))
          (t.id, sigueEnOt(t) ?? t, sigueEnOt(t) == null
              ? 'La oficina ha interrumpido «${t.nombre}» por tu incidencia.'
              : 'La oficina ha interrumpido «${t.nombre}»: el trabajo sigue en «${sigueEnOt(t)!.nombre}».'),
      // Su incidencia ya tiene OT y es para él: ya puede hacerla. Se va al abrirla, al quitarla o al empezarla.
      for (final (i, ot) in otsDeMisIncidencias(widget.w))
        if (!_interrumpidasVistas.contains('inc-${i.id}'))
          ('inc-${i.id}', ot, 'La oficina ha respondido a tu incidencia «${i.descripcion}»: ya puedes hacer «${ot.nombre}».'),
    ];
    if (avisos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (clave, abrir, texto) in avisos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: HoverCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              onTap: () {
                if (clave != null) _visto(clave);
                widget.abrir(abrir);
              },
              child: Row(children: [
                Pill('Nuevo', P.morado),
                const SizedBox(width: 12),
                Expanded(child: Text(texto, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (clave != null)
                  IconButton(
                    tooltip: 'Quitar',
                    onPressed: () => _visto(clave),
                    icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                  )
                else
                  const SizedBox(width: 8),
              ]),
            ),
          ),
      ]),
    );
  }
}

final _partesMandando = <String>{};

/// Al interrumpirse una OT suya, su dispositivo (donde están sus apuntes y fotos) manda solo el parte con lo hecho
/// hasta entonces: apuntes, fotos y el tiempo trabajado sin pausas. Una vez por OT.
void _mandarPartesInterrumpidas(Trabajador w) {
  for (final t in store.tareas) {
    // Interrumpida por una incidencia o cancelada por la oficina mientras la hacía (lo que no llegó a empezar no
    // tiene nada que mandar: lo descarta [_mandarParteInterrumpida]).
    final cortada = t.estado == EstadoTrabajo.interrumpida || t.estado == EstadoTrabajo.noRealizado;
    if (!cortada || !t.trabajadorIds.contains(w.id) || !_partesMandando.add(t.id)) continue;
    unawaited(_mandarParteInterrumpida(t, w).catchError((Object e) {
      debugPrint('Pultec: no se pudo mandar el parte de la OT interrumpida: $e');
      _partesMandando.remove(t.id);
    }));
  }
}

Future<void> _mandarParteInterrumpida(Tarea t, Trabajador w) async {
  final prefs = await SharedPreferences.getInstance();
  final empresa = store.nube?.empresaId ?? 'demo';
  final hecho = 'ot_parte_interrumpida_${empresa}_${t.id}';
  if (prefs.getBool(hecho) ?? false) return;
  final claveInicio = 'ot_inicio_${empresa}_${t.id}';
  final inicio = t.iniciadaEn ?? DateTime.tryParse(prefs.getString(claveInicio) ?? '');
  final apuntes = (prefs.getString(_claveApuntes(t, w)) ?? '').trim();
  final deOt = _fotosDe(t, w);
  await deOt.listas;
  // Nunca empezada y sin nada apuntado: no hay parte que mandar.
  if (inicio == null && apuntes.isEmpty && deOt.fotos.isEmpty) {
    await prefs.setBool(hecho, true);
    return;
  }
  final sigue = sigueEnOt(t);
  await informes.crear(
    Informe(
      trabajoId: t.id,
      trabajadorId: w.id,
      resultado: 1,
      notas: [
        t.estado == EstadoTrabajo.noRealizado
            ? 'OT cancelada por la oficina mientras estaba en curso.'
            : 'OT interrumpida por una incidencia${sigue == null ? '' : '; el trabajo sigue en «${sigue.nombre}»'}.',
        if (apuntes.isNotEmpty) apuntes,
        if (deOt.resumen.isNotEmpty) deOt.resumen,
      ].join('\n\n'),
      // Hasta la pausa de la incidencia (la pausa no cuenta).
      minutos: inicio == null ? null : (t.trabajado(inicio).inSeconds / 60).ceil().clamp(1, 10080),
    ),
    fotos: [for (final f in deOt.fotos) f.bytes],
  );
  await prefs.setBool(hecho, true);
  await prefs.remove(claveInicio);
  await _borrarApuntes(t, w);
  await _borrarFotos(t, w);
}


/// Estado de una OT en las tablas del técnico, como en las de la oficina: en texto, y en curso con el punto que
/// late y lo que lleva.
Widget pillEstadoTecnico(Tarea t) => t.estado == EstadoTrabajo.enCurso && !t.pausada && !esperandoIncidencia(t)
    ? EstadoEnVivo(t)
    : Text(t.pausada || esperandoIncidencia(t) ? 'Pausada' : t.estado.etiqueta, maxLines: 1,
        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

/// «Mis órdenes» del técnico en escritorio: las columnas de Órdenes de trabajo del administrador, sin lo que se
/// edita (técnico, estado). A la izquierda, el anillo de cuánto le queda; en «Cuándo», la fecha y lo que falta.
class _TablaOrdenesTecnico extends StatelessWidget {
  final List<Tarea> ts;
  final void Function(Tarea) abrir;
  const _TablaOrdenesTecnico(this.ts, this.abrir);

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => (box.maxWidth > 1000, box.maxWidth > 760),
    builder: (context, box) {
      final ancho = box.maxWidth > 1000, medio = box.maxWidth > 760;
      return Align(
        alignment: Alignment.topCenter,
        child: _sinHueco(Tabla(
          id: 'ordenes-tecnico',
          menuColumnas: medio,
          columnas: [
            // El anillo, en su columna sin título (como las casillas del administrador): así «Orden de trabajo»
            // queda encima de los nombres.
            const Col('', ancho: 30, cabecera: SizedBox()),
            const Col('Orden de trabajo', flex: 4, fija: true),
            if (medio) const Col('Activo', flex: 3),
            if (ancho) const Col('Origen', ancho: 150),
            const Col('Gravedad', ancho: 170),
            const Col('Cuándo', ancho: 170),
            const Col('Estado', ancho: 130, derecha: true),
          ],
          filas: ts.length,
          onTap: (i) {
            store.verNuevo(ts[i].id);
            abrir(ts[i]);
          },
          pie: pieTabla(ts.length, ts.length == 1 ? 'orden de trabajo' : 'órdenes de trabajo'),
          celdas: (i) {
            final t = ts[i];
            final ciclo = cicloOt(t);
            final vencida = t.proximo != null && diasHasta(t.proximo!) < 0;
            final (origen, colorOrigen) = origenOt(t);
            return [
              Align(alignment: Alignment.centerLeft, child: AnilloCiclo(ciclo)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                conNuevo(t.id, celdaTexto(t.nombre, negrita: true)),
                if (descripcionOt(t).isNotEmpty)
                  Text(descripcionOt(t), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: P.textoSuave)),
              ]),
              if (medio)
                Row(children: [
                  if (store.activo(t.activoId) case final a?) ...[
                    IconoActivo(a.icono, size: 22, color: P.textoSuave),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: celdaTexto(store.activo(t.activoId)?.titulo ?? 'Sin activo', suave: true)),
                ]),
              if (ancho)
                Row(children: [
                  Icon(
                    origen == 'Mantenimiento' ? Icons.content_paste_rounded
                        : origen == 'Incidencia' ? Icons.report_outlined : Icons.back_hand_outlined,
                    size: 18,
                    color: origen == 'Incidencia' ? colorOrigen : origen == 'Manual' ? P.azul : P.textoSuave,
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: celdaTexto(origen, suave: true)),
                ]),
              Align(
                alignment: Alignment.centerLeft,
                child: PillTipo(t.tipoMantenimiento ?? TipoMantenimiento.preventivo),
              ),
              t.proximo == null
                  ? celdaTexto('Sin fecha', suave: true)
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text([fecha(t.proximo), ?t.horario].join(', '), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                      // Lo que le queda (o cuánto lleva vencida), como en el anillo.
                      Text(ciclo == null ? relativo(t.proximo!) : ciclo.$2.split(',').first,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: vencida ? P.rojo : P.textoSuave,
                          fontWeight: vencida ? FontWeight.w600 : FontWeight.w400)),
                    ]),
              Align(alignment: Alignment.centerRight, child: pillEstadoTecnico(t)),
            ];
          },
        )),
      );
    },
  );
}

/// Las tablas del técnico, sin el hueco de la barra de la página (el fondo de la fila llega al borde).
Widget _sinHueco(Widget tabla) => ScrollConfiguration(behavior: const _BarraAparte(conHueco: false), child: tabla);

/// Ancho de la barra del técnico: el mismo que la del administrador (se guarda en [ajustes]), con su borde
/// arrastrable (raya morada al pasar el ratón). Más estrecha que el mínimo con textos, se pliega a solo iconos.
class _AnchoBarraTecnico extends StatefulWidget {
  final Widget child;
  const _AnchoBarraTecnico({required this.child});
  @override
  State<_AnchoBarraTecnico> createState() => _AnchoBarraTecnicoState();
}

class _AnchoBarraTecnicoState extends State<_AnchoBarraTecnico> {
  final _arrastre = ValueNotifier<double?>(null);
  double _inicioX = 0, _inicioAncho = 0;

  @override
  void dispose() {
    _arrastre.dispose();
    super.dispose();
  }

  /// Como mucho, un 25 % de la ventana (como la del administrador).
  double get maximo => (MediaQuery.sizeOf(context).width * .25).clamp(Ajustes.anchoTextos + 40, 2000);

  double _ancho(double? arrastrando) {
    if (arrastrando != null) return arrastrando;
    final a = ajustes.anchoBarra;
    return a <= Ajustes.anchoIconos ? Ajustes.anchoIconos : a.clamp(Ajustes.anchoTextos, maximo);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: ajustes.cambioBarra,
    builder: (context, _, _) => ValueListenableBuilder<double?>(
      valueListenable: _arrastre,
      builder: (context, arrastrando, child) => AnimatedContainer(
        duration: arrastrando == null ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutQuart,
        width: _ancho(arrastrando),
        child: child,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 10,
            child: AsaBarra(
              derecha: false,
              onInicio: (x) {
                _inicioX = x;
                _inicioAncho = _ancho(null);
                _arrastre.value = _inicioAncho;
              },
              onMover: (x) => _arrastre.value = (_inicioAncho + x - _inicioX).clamp(Ajustes.anchoIconos, maximo),
              onFin: () {
                if (_arrastre.value != null) ajustes.ponerAnchoBarra(_arrastre.value!, max: maximo);
                _arrastre.value = null;
              },
            ),
          ),
        ],
      ),
    ),
  );
}


/// Incidencias suyas a las que la oficina ha sacado una OT nueva para él que aún no ha empezado (las de una orden
/// interrumpida ya tienen su propio aviso).
List<(Incidencia, Tarea)> otsDeMisIncidencias(Trabajador w) => [
  for (final i in store.incidencias)
    if (i.tecnicoId == w.id && i.trabajoId != null && i.trabajoId != i.origenTrabajoId)
      if (store.tarea(i.trabajoId!) case final ot?
          when ot.trabajadorIds.contains(w.id) &&
              ot.estado == EstadoTrabajo.pendiente &&
              store.tarea(i.origenTrabajoId ?? '')?.estado != EstadoTrabajo.interrumpida)
        (i, ot),
];

/// Notificaciones del técnico: lo que la oficina ha hecho con sus órdenes e incidencias (las mismas frases que
/// salen arriba de «Mis órdenes»). Se abren en la orden.
List<Aviso> avisosTecnico(Trabajador w) {
  final lista = <Aviso>[];
  final desde = masDias(hoy(), -14);
  for (final t in store.tareas.where((t) => !t.esPlantilla && t.trabajadorIds.contains(w.id))) {
    final suyas = store.incidencias.where((i) => i.origenTrabajoId == t.id).toList()
      ..sort((a, b) => a.creada.compareTo(b.creada));
    // Si la oficina unió su aviso a la incidencia que ya resolvía esta orden, la suya ya no está: cuenta esa.
    final unida = suyas.isEmpty ? store.incidenciaDeOt(t.id) : null;
    final ultima = suyas.lastOrNull ?? unida;
    if (t.pausada && ultima != null && !esperandoIncidencia(t)) {
      lista.add(Aviso(
        id: 'reanudar-${t.id}-${t.pausadaDesde!.millisecondsSinceEpoch}',
        titulo: unida != null
            ? 'La oficina ha unido tu aviso a la incidencia de esta orden'
            : store.estadoIncidencia(ultima) == EstadoIncidencia.desestimada
            ? 'La oficina ha desestimado tu incidencia'
            : 'La oficina ha respondido a tu incidencia',
        detalle: 'Ya puedes reanudar «${t.nombre}»',
        color: P.morado,
        cuando: unida != null ? t.pausadaDesde! : ultima.creada,
        tareaId: t.id,
        activoId: t.activoId,
      ));
    } else if (t.estado == EstadoTrabajo.interrumpida && (ultima?.creada.isAfter(desde) ?? false)) {
      final sigue = sigueEnOt(t);
      lista.add(Aviso(
        id: 'interrumpida-${t.id}',
        titulo: 'La oficina ha interrumpido «${t.nombre}»',
        detalle: sigue == null ? 'Por tu incidencia' : 'El trabajo sigue en «${sigue.nombre}»',
        color: P.ambar,
        cuando: ultima!.creada,
        tareaId: (sigue ?? t).id,
        activoId: t.activoId,
      ));
    } else if (t.estado == EstadoTrabajo.noRealizado && t.iniciadaEn != null && t.iniciadaEn!.isAfter(desde)) {
      lista.add(Aviso(
        id: 'cancelada-${t.id}',
        titulo: 'La oficina ha cancelado «${t.nombre}»',
        detalle: 'Tu parte con lo hecho se ha enviado',
        color: P.rojo,
        urgente: true,
        cuando: t.iniciadaEn!,
        tareaId: t.id,
        activoId: t.activoId,
      ));
    }
  }
  for (final (i, ot) in otsDeMisIncidencias(w)) {
    lista.add(Aviso(
      id: 'ot-incidencia-${i.id}',
      titulo: 'La oficina ha respondido a tu incidencia',
      detalle: 'Ya puedes hacer «${ot.nombre}»',
      color: P.morado,
      cuando: i.creada,
      tareaId: ot.id,
      activoId: ot.activoId,
    ));
  }
  return lista..sort((a, b) => b.cuando.compareTo(a.cuando));
}
