import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../forms.dart';
import '../industrial/activo.dart';
import '../informes.dart';
import '../marca.dart';
import '../industrial/activos.dart' show colorEstado, gravedadDe;
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
      final elegir = industrial && eligiendo && tarea == null && maquinas.length > 1;
      final escritorio = industrial && !movil && w != null;
      Widget? contenido;
      if (w != null) {
        contenido = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tarea != null || !escritorio) ...[
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(tarea?.id ?? (elegir ? 'maquinas' : pestana)),
                  child: tarea != null
                      ? _DetalleTrabajo(tarea, w)
                      : elegir
                      ? ElegirMaquinas(
                          w,
                          maquinas,
                          inicial: _maquinasElegidas[w.id] ?? const {},
                          onListo: (sel) => setState(() {
                            _maquinasElegidas[w.id] = sel;
                            eligiendo = false;
                          }),
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
          ],
        );
        contenido = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: escritorio ? 980 : 760),
            child: Padding(padding: escritorio ? const EdgeInsets.fromLTRB(28, 22, 28, 12) : margenPagina, child: contenido),
          ),
        );
      }
      return Scaffold(
        backgroundColor: escritorio ? P.barra : P.fondo,
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
        .where((t) => t.estado != EstadoTrabajo.realizado && !t.hechaEl(hoy()) && _enMaquinas(t.activoId, sel))
        .length;
    final avisos = store.incidencias
        .where((i) => i.tecnicoId == w.id || (i.tecnicoId == null && (store.nube?.esTrabajador ?? false)))
        .length;
    return [pendientes, avisos];
  }
}

/// Máquinas elegidas por cada técnico al entrar (vacío = todas). Se recuerdan mientras la app está abierta.
final _maquinasElegidas = <String, Set<String>>{};

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
bool _enMaquinas(String? activoId, Set<String> sel) =>
    sel.isEmpty || activoId == null || sel.contains(_maquinaDe(activoId));

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

  Widget _fila(IconData icono, String texto, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(P.radioControl),
    hoverColor: P.hoverBarra,
    mouseCursor: SystemMouseCursors.click,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icono, size: 19, color: P.textoBarraSuave),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 14.5, color: P.textoBarra))),
        ],
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
    return Container(
      width: 248,
      color: P.barra,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 2),
                const LogoPulpo(size: 32),
                const SizedBox(width: 10),
                Text(
                  Marca.nombre,
                  style: TextStyle(
                    fontFamily: P.titulos,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                    color: P.textoBarra,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: P.rojo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
                ),
                onPressed: onIncidencia,
                icon: const Icon(Icons.report_outlined, size: 19),
                label: const Text('Crear incidencia', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 14),
            for (final (i, (icono, texto, n)) in items.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(P.radioControl),
                  splashFactory: NoSplash.splashFactory,
                  hoverColor: P.hoverBarra,
                  mouseCursor: SystemMouseCursors.click,
                  onTap: () => onVista(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: vista == i ? P.seleccionBarra : Colors.transparent,
                      borderRadius: BorderRadius.circular(P.radioControl),
                      boxShadow: vista == i ? P.sombraSeleccionBarra : null,
                    ),
                    child: Row(
                      children: [
                        Icon(icono, size: 20, color: vista == i ? P.iconoBarraElegido : P.textoBarraSuave),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            texto,
                            style: TextStyle(
                              fontFamily: P.titulos,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: vista == i ? P.textoBarraElegido : P.textoBarra,
                            ),
                          ),
                        ),
                        if (n > 0) Text('$n', style: TextStyle(fontSize: 13, color: P.textoBarraSuave)),
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            if (onAdmin != null) _fila(Icons.swap_horiz_rounded, 'Vista de administrador', onAdmin!),
            _fila(Icons.logout_rounded, 'Cerrar sesión', onSalir),
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
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      FotoTecnico(w, size: 34),
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
                            Text('Mi perfil', style: TextStyle(fontSize: 12, color: P.textoBarraSuave)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
                  'Empezar con $ordenes órdenes',
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
        label: '${widget.a.nombre}, ${widget.n} órdenes',
        child: GestureDetector(
          onTap: widget.onTap,
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
                  '${widget.n} ${widget.n == 1 ? 'orden' : 'órdenes'}',
                  style: TextStyle(fontSize: 13, color: P.textoSuave),
                ),
              ],
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
        if (widget.w.email.isNotEmpty) ...[
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
        BotonAccion('Comunicar incidencia', icono: Icons.report_problem_outlined,
          onPressed: () => abrirPanel(context, AvisoIncidenciaForm(tecnicoId: widget.w.id, origenTrabajoId: t.id))),
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
      .where((t) => t.proximo != null && t.estado != EstadoTrabajo.realizado && !t.hechaEl(hoy())).toList()
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
    MenuItemButton opcion(String nombre, bool marcado, VoidCallback elegir, {Color? color}) => MenuItemButton(
      leadingIcon: color == null ? null : Icon(Icons.circle, size: 8, color: color),
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
          for (final e in EstadoIncidencia.values) opcion(e.etiqueta, estado == e.index, () => estado = e.index),
        ], child: const Text('Estado de la incidencia')),
        if (vista == 2) SubmenuButton(menuChildren: [
          opcion('Todos los resultados', resultado == null, () => resultado = null),
          for (final (i, nombre) in ['Completadas', 'Con incidencias', 'No se pudo hacer'].indexed)
            opcion(nombre, resultado == i, () => resultado = i, color: coloresResultado[i]),
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

  void _verIncidencia(Incidencia i) => abrirPanel(context, VentanaFormulario(
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
      Bloque('Órdenes relacionadas', [
        for (final (id, etiqueta) in [(i.origenTrabajoId, 'Orden de origen'), (i.trabajoId, 'Orden para resolverla')])
          if (store.tarea(id ?? '') case final t?)
Text('$etiqueta: ${t.nombre}')
          else Text('$etiqueta: sin orden asociada'),
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
        .where((t) => t.estado != EstadoTrabajo.realizado && !t.hechaEl(hoy()) && _enMaquinas(t.activoId, sel))
        .toList()
      ..sort((a, b) => (a.proximo ?? DateTime(2100)).compareTo(b.proximo ?? DateTime(2100)));
    final avisos = store.incidencias.where((i) => (i.tecnicoId == widget.w.id ||
      (i.tecnicoId == null && (store.nube?.esTrabajador ?? false))) && _enMaquinas(i.activoId, sel)).toList()
      ..sort((a, b) => b.creada.compareTo(a.creada));
    final titulos = ['Mis órdenes', 'Incidencias', 'Histórico'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
      const SizedBox(height: 18),
      // Una sola fila: el apartado (o las pestañas en el móvil), y a la derecha buscar y filtrar.
      BarraVista(
        izquierda: [
          if (widget.pestanas)
            Pestanas(opciones: ['Órdenes', 'Incidencias', 'Histórico'], seleccion: vista,
              onChanged: (n) { estado = null; _vista(n); })
          else
            Text(titulos[vista], style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700,
              letterSpacing: -.4)),
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
          Padding(padding: const EdgeInsets.fromLTRB(58, 0, 12, 10), child: PillTipo(t.tipoMantenimiento ?? TipoMantenimiento.preventivo)),
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
    return ListView.builder(itemCount: lista.length, itemBuilder: (_, n) {
      final i = lista[n];
      // Igual que las órdenes: la tarjeta entera se pulsa y se marca al pasar el ratón.
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: HoverCard(padding: EdgeInsets.zero,
        onTap: () => _verIncidencia(i),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FilaLista(lider: _IconoActivo(i.activoId), titulo: i.descripcion,
            subtitulo: '${_cuando(i.creada)}\n${dondeEs(i.activoId)}',
            derecha: Pill(store.estadoIncidencia(i).etiqueta, store.estadoIncidencia(i).color)),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(
            'Orden de origen: ${store.tarea(i.origenTrabajoId ?? '')?.nombre ?? 'Sin orden asociada'}'
            '${i.trabajoId == null ? '' : '\nOrden para resolverla: ${store.tarea(i.trabajoId!)?.nombre ?? 'Orden no disponible'}'}',
            style: TextStyle(color: P.textoSuave, fontSize: 12))),
        ]),
      ));
    });
  }

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
    return ListView.builder(itemCount: lista.length, itemBuilder: (_, n) {
      final i = lista[n], t = store.tarea(i.trabajoId);
      final texto = ['Completada', 'Con incidencias', 'No se pudo hacer'][i.resultado];
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: HoverCard(padding: EdgeInsets.zero,
        onTap: t == null ? null : () => verInforme(context, i, t),
        child: FilaLista(lider: Icon(i.resultado == 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
          color: coloresResultado[i.resultado]), titulo: t?.nombre ?? 'Orden no disponible',
          subtitulo: '${_cuando(i.cuando)}   $texto\n${dondeEs(t?.activoId)}'),
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
    final plan = industrial ? store.planes.where((p) => p.id == t.planId).firstOrNull : null;
    final procedimiento = t.procedimiento.isNotEmpty ? t.procedimiento : plan?.procedimiento ?? '';
    final repuestos = t.repuestos.isNotEmpty ? t.repuestos : plan?.repuestos ?? '';
    final incidencia = industrial ? store.incidenciaDeOt(t.id) : null;
    return ListView(
      children: [
        Row(
          children: [
            industrial ? _IconoActivo(t.activoId, size: 44) : TipoIcono(t.tipo, size: 44),
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
          const SizedBox(height: huecoVista),
          SeccionTarjeta(
            titulo: 'Procedimiento y repuestos',
            children: [
              if (procedimiento.isNotEmpty) _dato('Procedimiento', procedimiento),
              if (repuestos.isNotEmpty) _dato('Repuestos', repuestos),
            ],
          ),
        ],
        // Sale de una incidencia: lo que se comunicó, quién, cuándo y sus fotos.
        if (incidencia != null) ...[
          const SizedBox(height: huecoVista),
          SeccionTarjeta(
            titulo: 'Incidencia original',
            children: [
              _dato('Qué pasa', incidencia.descripcion),
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

  /// Pultec: activo principal de la OT, cuyo contador apunta el técnico al cerrar (en vez de los minutos).
  late final raiz = industrial ? raizActivo(widget.t.activoId) : null;
  final contador = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    for (final c in [notas, material, minutos, firmante, contador]) {
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
    if (notas.text.trim().isEmpty || _minutos == -1 || _contador == -1) {
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
          minutos: raiz != null ? null : _minutos,
          firmante: firma.vacia || industrial ? '' : firmante.text.trim(),
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
    // Pultec: el resultado queda en la OT (con incidencia o sin hacer, sale como aviso) y la lectura del
    // contador, en su activo principal.
    if (industrial) {
      widget.t
        ..resultado = resultado
        ..resultadoResuelto = false;
      final h = _contador;
      if (raiz != null && h != null && h >= 0) {
        raiz!
          ..horas = h
          ..fechaLectura = hoy();
        store.guardarActivo(raiz!);
        // Una cuenta de técnico no sube activos con la sincronización: la lectura va por su función.
        if (store.nube?.esTrabajador ?? false) {
          try {
            await store.nube!.apuntarContador(raiz!.id, h);
          } catch (e) {
            debugPrint('Pultec: no se pudo apuntar el contador: $e');
            aviso('No se pudo guardar la lectura del contador.');
          }
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
      if (intentado && _contador == -1) ('El contador va en horas, con números', () {}),
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
