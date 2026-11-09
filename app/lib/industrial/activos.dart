import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../marca.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'filtro_flujo.dart';
import 'iconos.dart';
import 'uso_maquinas.dart';
import 'gravedad.dart';
import 'historicos.dart';
import 'plan.dart';
import 'planes.dart';
import '../screens/tabla_trabajos.dart';
import '../screens/tarea_detalle.dart';

/// Color del estado de un activo: el de su mantenimiento pendiente más grave (él y sus componentes).
/// Sin nada pendiente, verde: puede funcionar.
/// El estado de mantenimiento lo marca cada activo en su ficha (no sus OT).
/// La criticidad es de los mantenimientos, no del activo: el activo toma la de su OT pendiente más grave.
TipoMantenimiento? gravedadDe(String activoId) =>
    masGrave(store.otsDe(activoId));
Color colorEstado(TipoMantenimiento? g) => g?.color ?? P.verde;
String textoEstado(TipoMantenimiento? g) => g?.etiqueta ?? 'Al día';

/// Avisa a Activos de que vuelva a la lista (aunque el filtro no cambie), al llegar desde Inicio.
final _aLaLista = ValueNotifier(0);

/// Lo que hace la N en Activos: dentro de un activo, lo mismo que su botón (mantenimiento o componente);
/// en la lista, null y el atajo abre el alta de activo.
Future<void> Function(BuildContext)? nuevoEnActivo;

/// Activo abierto y lo que se miraba dentro; sobreviven a que la vista se vuelva a crear al redimensionar.
final _abierto = ValueNotifier<String?>(null);
var _pestana = 0, _vista = 0, _criticidad = 0;

/// Desde Inicio, al abrir un activo por uno de sus mantenimientos: Resumen, Mantenimientos, sin filtro,
/// y ese mantenimiento destacado.
void destacarMantenimiento(String planId) {
  _pestana = _vista = _criticidad = 0;
  planDestacado.value = planId;
}

/// Vuelve a la lista con la ficha como recién abierta (tests).
@visibleForTesting
void reiniciarVistaActivos() {
  _abierto.value = null;
  _pestana = _vista = _criticidad = 0;
}

/// Desde Inicio: Activos en la lista (nunca dentro de un activo abierto antes).
void abrirListaActivos() => _aLaLista.value++;

/// Filtro de criticidad de la pestaña Mantenimientos de un activo: 0 = todos; 1.. = tipo.
// Futuro: const _filtrosCriticidad = ['Todos', 'Normal', 'Alta', 'Muy alta'];

Widget _flechaActivo(bool adelante, VoidCallback? pulsar) => IconButton(
  tooltip: adelante ? 'Adelante' : 'Atrás',
  constraints: const BoxConstraints.tightFor(width: 28, height: 32),
  padding: EdgeInsets.zero,
  visualDensity: VisualDensity.standard,
  style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
  onPressed: pulsar,
  icon: Icon(adelante ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, size: 20),
);

Widget _raizActivos() => Row(mainAxisSize: MainAxisSize.min, children: [
  Icon(Marca.iconoCliente, size: 24, color: P.textoSuave),
  const SizedBox(width: 4),
  const Text('Activos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
]);

/// Sección «Activos» de Pultec: las máquinas con el color de su estado; al abrir una, su árbol de componentes.
class Activos extends StatefulWidget {
  final ValueChanged<String>? onAbrir;
  final Widget? navegacion;
  const Activos({super.key, this.onAbrir, this.navegacion});

  @override
  State<Activos> createState() => _ActivosState();
}

class _ActivosState extends State<Activos> {
  String q = '';

  /// Fuera del estado: al estrechar la ventana el diseño cambia y Activos se vuelve a crear.
  String? get abierto => _abierto.value;
  set abierto(String? v) => _abierto.value = v;

  @override
  void initState() {
    super.initState();
    _aLaLista.addListener(_cambio);
  }

  @override
  void dispose() {
    _aLaLista.removeListener(_cambio);
    super.dispose();
  }

  void _cambio() => setState(() => abierto = null);

  @override
  Widget build(BuildContext context) {
    if (abierto != null && widget.onAbrir == null)
      return ActivoDetalle(
        activoId: abierto!,
        onVolver: () => setState(() => abierto = null),
      );
    final activos = store.hijosDe(null).where((a) {
      final t = '${a.tag} ${a.nombre} ${a.fabricante} ${a.modelo} ${a.division}'
          .toLowerCase();
      return t.contains(q.toLowerCase());
    }).toList();
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarraVista(
            // Icono de Activos en grande delante del título.
            izquierda: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                widget.navegacion ?? SizedBox(height: 40, child: Row(mainAxisSize: MainAxisSize.min, children: [
                _flechaActivo(false, null), _flechaActivo(true, null),
                const SizedBox(width: 4), _raizActivos(),
              ])),
                Padding(padding: const EdgeInsets.only(left: 60),
                  child: Text('Todos los activos de tu empresa', style: TextStyle(fontSize: 13.5, color: P.textoSuave))),
              ]),
            ],
            derecha: const [],
            principal: BotonPrimario(
              'Nuevo activo',
              conIcono: true,
              icono: Icons.add_rounded,
              tecla: 'N',
              onPressed: () => abrirActivoForm(context),
            ),
          ),
          const SizedBox(height: 8),
          BarraVista(
            // Sin filtro de criticidad: un activo no es crítico; lo son sus mantenimientos (dentro del activo).
            // Buscador y, a su derecha, el calendario de turnos; los dos a la izquierda.
            izquierda: [
              Buscador(
                hint: 'Buscar activo…',
                onChanged: (v) => setState(() => q = v),
              ),
              BotonAccion(
                'Uso de activos',
                icono: Icons.event_note_outlined,
                onPressed: () => abrirUsoMaquinas(context),
              ),
            ],
            derecha: const [],
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            child: activos.isEmpty
                ? Vacio(
                    icono: Icons.precision_manufacturing_outlined,
                    titulo: q.isEmpty ? 'Aún no tienes activos' : null,
                    texto: q.isEmpty
                        ? 'Da de alta tus máquinas (camiones, compresores, prensas…) y sus componentes.'
                        : 'Ningún activo coincide con la búsqueda',
                    accion: q.isEmpty
                        ? FilledButton(
                            onPressed: () => abrirActivoForm(context),
                            child: const Text('Añadir el primero'),
                          )
                        : null,
                  )
                : _TablaActivos(activos, (id) {
                    // Al cambiar de vista con el ratón encima de un tipo, su aviso se quedaba pegado.
                    Tooltip.dismissAllToolTips();
                    if (widget.onAbrir != null) {
                      widget.onAbrir!(id);
                    } else {
                      setState(() => abierto = id);
                    }
                  }),
          ),
        ],
      ),
    );
  }
}

/// Todos los activos en orden de árbol, con su nivel (0 = activo, 1 = componente…).
List<(Activo, int)> arbolActivos() {
  final r = <(Activo, int)>[];
  void anadir(Activo a, int nivel) {
    r.add((a, nivel));
    for (final h in store.hijosDe(a.id)) {
      anadir(h, nivel + 1);
    }
  }

  for (final a in store.hijosDe(null)) {
    anadir(a, 0);
  }
  return r;
}

class _TablaActivos extends StatelessWidget {
  final List<Activo> activos;
  final ValueChanged<String> onAbrir;
  final bool componentes;
  const _TablaActivos(this.activos, this.onAbrir, {this.componentes = false});

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => (box.maxWidth > 980, box.maxWidth > 600),
    builder: (context, box) {
      final ancho = box.maxWidth > 980;
      // Móvil: el activo y el punto de su estado.
      final medio = box.maxWidth > 600;
      return Align(
        alignment: Alignment.topCenter,
        child: Tabla(
          columnas: [
            Col(componentes ? 'Componente' : 'Activo', flex: componentes ? 3 : 6),
            if (componentes) const Col('Tag', flex: 2),
            if (ancho) const Col('Fabricante y modelo', flex: 2),
            if (ancho) const Col('División', ancho: 80),
            if (ancho) const Col('Horas totales', ancho: 120, derecha: true),
            if (medio) const Col('Mantenimientos', ancho: 130, derecha: true),
            if (medio) const Col('Próximo mantenimiento', ancho: 160),
            if (medio)
              Col(
                'Componentes',
                ancho: 32,
                derecha: true,
                cabecera: Tooltip(
                  message: 'Componentes',
                  child: Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: P.textoSuave,
                  ),
                ),
              ),
          ],
          filas: activos.length,
          celdas: (i) {
            final a = activos[i];
            return [
              Row(
                children: [
                  // Sin color: la criticidad es de los mantenimientos, no del activo.
                  IconoActivo(a.icono, color: P.textoSuave, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    // Subcomponentes: el nombre aquí y el tag en su propia columna.
                    child: a.descripcion.isEmpty
                        ? celdaTexto(
                            componentes && a.nombre.isNotEmpty
                                ? a.nombre
                                : a.titulo,
                            negrita: true,
                          )
                        // Con descripción: debajo del nombre, como en los mantenimientos.
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                celdaTexto(
                                  componentes && a.nombre.isNotEmpty
                                      ? a.nombre
                                      : a.titulo,
                                  negrita: true,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a.descripcion,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: P.textoSuave,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
              if (componentes)
                celdaTexto(a.tag.isEmpty ? '—' : a.tag, suave: true),
              if (ancho)
                celdaTexto(
                  [a.fabricante, a.modelo].where((x) => x.isNotEmpty).join(' '),
                  suave: true,
                ),
              if (ancho) celdaTexto(a.division, suave: true),
              if (ancho)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: celdaTexto(horas(horasHoy(a)), suave: true),
                ),
              if (medio)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: celdaTexto('${planesRama(a.id).length}', suave: true),
                ),
              if (medio)
                Tooltip(
                  message: 'El más cercano de sus mantenimientos y los de sus componentes.',
                  child: celdaTexto(proximaFecha(a), suave: true),
                ),
              if (medio)
                celdaTexto('${store.ramaDe(a.id).length - 1}', suave: true),
            ];
          },
          onTap: (i) => onAbrir(activos[i].id),
          pie: pieTabla(
            activos.length,
            componentes
                ? (activos.length == 1 ? 'componente' : 'componentes')
                : (activos.length == 1 ? 'activo' : 'activos'),
          ),
        ),
      );
    },
  );
}

/// Mantenimientos del activo y de todos sus componentes.
List<PlanMantenimiento> planesRama(String id) {
  final rama = store.ramaDe(id);
  return store.planes.where((p) => rama.contains(p.activoId)).toList();
}

/// El mantenimiento activo que antes toca en el activo o sus componentes.
DateTime? proximoDe(String id) {
  DateTime? r;
  for (final p in planesRama(id).where((p) => p.activa)) {
    final d = proximoPlan(p);
    if (d != null && (r == null || d.isBefore(r))) r = d;
  }
  return r;
}

String proximaFecha(Activo a) {
  final d = proximoDe(a.id);
  return d == null ? '—' : fecha(d);
}

String horas(double h) => h == 0 ? '—' : '${h % 1 == 0 ? h.toInt() : h} h';

/// Ficha del activo y de cada componente: resumen, datos editables, OT e histórico propio.
class ActivoDetalle extends StatefulWidget {
  final String activoId;
  final VoidCallback onVolver;
  const ActivoDetalle({
    super.key,
    required this.activoId,
    required this.onVolver,
  });

  @override
  State<ActivoDetalle> createState() => _ActivoDetalleState();
}

class _ActivoDetalleState extends State<ActivoDetalle> {
  late String elegido = widget.activoId;
  final _rutaScroll = ScrollController();
  String? _rutaVisible;

  late final List<String?> _historial = [null, widget.activoId];
  int _posicion = 1;

  void _recorrer(int paso) {
    setState(() {
      _posicion += paso;
      final id = _historial[_posicion];
      if (id != null) elegido = _abierto.value = id;
      pestana = vista = 0;
    });
  }

  Widget _cabeceraRuta(Activo a) {
    final ruta = <Activo>[];
    final vistos = <String>{};
    Activo? nodo = a;
    while (nodo != null && vistos.add(nodo.id)) {
      ruta.insert(0, nodo);
      nodo = store.activo(nodo.padreId);
    }
    if (_rutaVisible != a.id) {
      _rutaVisible = a.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _rutaScroll.hasClients) {
          _rutaScroll.jumpTo(_rutaScroll.position.maxScrollExtent);
        }
      });
    }
    final principal = ruta.first;
    final descripcion = a.descripcion.trim().isNotEmpty
        ? a.descripcion.trim()
        : principal.descripcion.trim().isNotEmpty
        ? principal.descripcion.trim()
        : [principal.fabricante, principal.modelo]
            .where((x) => x.trim().isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 40, child: Row(
          children: [
            _flechaActivo(false, _posicion > 0 ? () => _recorrer(-1) : null),
            _flechaActivo(true, _posicion + 1 < _historial.length ? () => _recorrer(1) : null),
            const SizedBox(width: 4),
            Expanded(
              child: SingleChildScrollView(
                controller: _rutaScroll,
                scrollDirection: Axis.horizontal,
                reverse: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _posicion = 0;
                      }),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32),
                        foregroundColor: P.textoSuave, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: _raizActivos(),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('/', style: TextStyle(color: P.textoSuave))),
                    for (var i = 0; i < ruta.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '/',
                            style: TextStyle(color: P.textoSuave),
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final activo = ruta[i];
                          final actual = i == ruta.length - 1;
                          final nombre =
                              (ruta.length == 1 || activo.nombre.trim().isEmpty
                                  ? activo.titulo : activo.nombre)
                                  .trim();
                          final letras = nombre.characters;
                          final texto = ruta.length > 1 && letras.length > 25
                              ? '${letras.take(24)}…'
                              : nombre;
                          return Tooltip(
                            message: activo.titulo,
                            child: TextButton(
                              onPressed: actual
                                  ? null
                                  : () => _abrir(activo.id),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: P.textoSuave,
                                disabledForegroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconoActivo(activo.icono, size: 24, color: P.textoSuave),
                                  const SizedBox(width: 4),
                                  Text(
                                texto.isEmpty ? 'Activo' : texto,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: actual
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        )),
        Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Text(
              descripcion.isEmpty ? ' ' : descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: P.textoSuave),
            ),
          ),
      ],
    );
  }

  int _estadoOrden = 0;
  int _asignacionOt = 0;

  /// Órdenes de trabajo del activo: pendientes o, aparte, el histórico (como en Órdenes de trabajo).
  bool _historicoOt = false;

  int get pestana => _pestana;
  set pestana(int v) => _pestana = v;

  /// Sube al guardar o cancelar en Datos: el formulario vuelve a leer el activo.
  int vuelta = 0;
  String? tareaId;

  /// Qué enseña Resumen: 0 = mantenimientos (por defecto), 1 = subcomponentes.
  int get vista => _vista;
  set vista(int v) => _vista = v;
  int get criticidad => _criticidad;
  set criticidad(int v) => _criticidad = v;

  void _abrir(String id) => setState(() {
    Tooltip.dismissAllToolTips();
    if (_historial[_posicion] != id) {
      _historial.removeRange(_posicion + 1, _historial.length);
      _historial.add(id);
      _posicion++;
    }
    elegido = _abierto.value = id;
    pestana = 0;
    vista = 0;
  });

  /// Mantenimientos del activo y de sus componentes; la columna Código dice de cuál es cada uno.
  Widget _mantenimientos(Activo a, List<PlanMantenimiento> planes) {
    if (planes.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Tarjeta(
          child: SizedBox(
            width: double.infinity,
            child: Text(
              'Aún no hay mantenimientos. Crea lo que hay que hacerle a este ${a.padreId == null ? 'activo' : 'componente'}: cada cuánto, quién y cómo.',
              style: TextStyle(fontSize: 13.5, color: P.textoSuave),
            ),
          ),
        ),
      );
    }
    if (_estadoOrden != 0) {
      final ots = ordenesPendientesDePlanes(planes);
      planes = planes.where((p) {
        final ot = ots[p.id] ?? ots['${p.activoId}|${p.nombre}'];
        return switch (_estadoOrden) {
          // Todo mantenimiento tiene su OT (se crea sola): solo sin asignar / asignados.
          1 => ot == null || ot.trabajadorIds.isEmpty,
          2 => ot != null && ot.trabajadorIds.isNotEmpty,
          _ => true,
        };
      }).toList();
    }
    // Prioridad aparcada para el futuro.
    // if (criticidad != 0) planes = planes.where((p) => p.prioridad.index == criticidad - 1).toList();
    if (planes.isEmpty) {
      return Vacio(
        icono: Icons.filter_alt_off_outlined,
        texto: switch (_estadoOrden) {
          1 => 'No tienes mantenimientos con una orden de trabajo pendiente sin técnico asignado.',
          2 => 'No tienes mantenimientos con una orden de trabajo pendiente asignada a un técnico.',
          _ => 'No tienes mantenimientos con estos filtros.',
        },
      );
    }
    final proximos = {
      for (final p in planes) p.id: proximoPlan(p) ?? DateTime(9999),
    };
    final lista = [...planes]
      ..sort((x, y) => proximos[x.id]!.compareTo(proximos[y.id]!));
    return TablaPlanes(lista, activoId: a.id);
  }

  /// Dato corto de la línea de resumen: etiqueta gris y valor en negrita.
  Widget _dato(String etiqueta, String valor) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$etiqueta  ',
          style: TextStyle(color: P.textoSuave),
        ),
        TextSpan(
          text: valor,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 13.5),
  );

  void _nuevaOt(Activo a) => abrirTareaForm(
    context,
    null,
    borrador: Tarea(
      id: store.nuevoId(),
      activoId: a.id,
      plantilla: false,
      tipoMantenimiento: TipoMantenimiento.preventivo,
      proximo: proximoDe(a.id) ?? hoy(),
      periodicidad: Periodicidad.unica,
      criticidad: Criticidad.rutinaria,
    ),
  );

  @override
  @override
  void dispose() {
    _rutaScroll.dispose();
    nuevoEnActivo = null;
    planDestacado.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = store.activo(elegido) ?? store.activo(widget.activoId);
    nuevoEnActivo = a == null
        ? null
        : vista == 0
        ? (c) => abrirPlanForm(c, activoId: a.id)
        : (c) => abrirActivoForm(c, padreId: a.id);
    if (a == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVolver());
      return const SizedBox();
    }
    if (tareaId != null) {
      return TareaDetalle(
        tareaId: tareaId!,
        onVolver: () => setState(() => tareaId = null),
        onAbrir: (id) => setState(() => tareaId = id),
      );
    }
    if (_historial[_posicion] == null) {
      nuevoEnActivo = (c) => abrirActivoForm(c);
      return Activos(onAbrir: _abrir, navegacion: SizedBox(height: 40, child: Row(mainAxisSize: MainAxisSize.min, children: [
        _flechaActivo(false, null),
        _flechaActivo(true, _posicion + 1 < _historial.length ? () => _recorrer(1) : null),
        const SizedBox(width: 4), _raizActivos(),
      ])));
    }
    elegido = a.id;

    final ots = store
        .otsDe(a.id)
        .where((t) => !t.esPlantilla && t.activa)
        .toList();
    final componentes = store.hijosDe(a.id);
    final planes = planesRama(a.id);
    PlanMantenimiento? siguiente;
    DateTime? proximo;
    for (final plan in planes.where((p) => p.activa)) {
      final fechaPlan = proximoPlan(plan);
      if (fechaPlan != null && (proximo == null || fechaPlan.isBefore(proximo))) {
        siguiente = plan;
        proximo = fechaPlan;
      }
    }
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cabecera(
            titulo: '',
            lider: null,
            contenido: _cabeceraRuta(a),
            // Arriba a la derecha, como en el resto de vistas; no junto al selector.
            acciones: [
              if (pestana == 0)
                vista == 0
                    ? BotonPrimario(
                        'Nuevo mantenimiento',
                        conIcono: true,
                        icono: Icons.add_rounded,
                        tecla: 'N',
                        onPressed: () => abrirPlanForm(context, activoId: a.id),
                      )
                    : BotonPrimario(
                        a.padreId == null
                            ? 'Nuevo componente'
                            : 'Nuevo subcomponente',
                        conIcono: true,
                        icono: Icons.add_rounded,
                        tecla: 'N',
                        onPressed: () =>
                            abrirActivoForm(context, padreId: a.id),
                      ),
              if (pestana == 2)
                BotonPrimario(
                  'Nueva orden de trabajo',
                  conIcono: true,
                  icono: Icons.add_rounded,
                  onPressed: () => _nuevaOt(a),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12, runSpacing: 8,
              children: [
                Pestanas(
            // El histórico va dentro de Órdenes de trabajo (Pendientes / Histórico), no en otra pestaña.
            opciones: const [
              'Resumen',
              'Datos',
              'Órdenes de trabajo',
            ],
            seleccion: pestana,
            onChanged: (i) => setState(() {
              pestana = i;
            }),
          ),
                if (pestana == 2)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    // Pendientes / Histórico siempre el último (a la derecha del todo): no se mueve al cambiar;
                    // el filtro de asignación, solo en Pendientes, va a su izquierda.
                    children: [
                      if (!_historicoOt)
                        FiltroFlujoMantenimiento(
                          incluirSinOrden: false,
                          seleccion: _asignacionOt,
                          onChanged: (i) => setState(() => _asignacionOt = i),
                        ),
                      Pestanas(
                        opciones: const ['Pendientes', 'Histórico'],
                        iconos: const [Icons.radio_button_unchecked_rounded, Icons.task_alt_rounded],
                        seleccion: _historicoOt ? 1 : 0,
                        onChanged: (i) => setState(() => _historicoOt = i == 1),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (actual, anteriores) => Stack(
                fit: StackFit.expand,
                children: [...anteriores, ?actual],
              ),
              child: KeyedSubtree(
                key: ValueKey('$elegido-$pestana-$_historicoOt'),
                child: switch (pestana) {
                  0 => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: proximo == null
                                  ? 'Próximo sin estimar'
                                  : 'Próximo ${relativo(proximo).toLowerCase()}: '),
                              if (siguiente != null) ...[
                                WidgetSpan(alignment: PlaceholderAlignment.middle,
                                  child: Padding(padding: const EdgeInsets.only(right: 5),
                                    child: Builder(builder: (_) {
                                      final ordenes = ordenesPendientesDePlanes([siguiente!]);
                                      return iconoAsignacion(ordenes[siguiente.id] ?? ordenes['${siguiente.activoId}|${siguiente.nombre}']);
                                    }))),
                                TextSpan(text: '${siguiente.nombre} · ${fecha(proximo!)}',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                              ],
                            ]),
                            style: TextStyle(fontSize: 13.5, color: P.textoSuave),
                          ),
                          _dato('Contador', horas(horasHoy(a))),
                          _dato(
                            'Órdenes pendientes',
                            '${ots.where(otPendiente).length}',
                          ),
                          // Partes con incidencia o sin hacer que aún nadie ha solucionado.
                          if (ots.where(incidenciaAbierta).length case final n
                              when n > 0)
                            Pill(
                              n == 1
                                  ? '1 incidencia abierta'
                                  : '$n incidencias abiertas',
                              P.rojo,
                              punto: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: huecoVista),
                      // Selector a la izquierda y filtro a la derecha; si no caben juntos, el filtro baja a otra línea.
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Pestanas(
                              opciones: [
                                'Mantenimientos · ${planes.length}',
                                // Dentro de un activo, sus componentes; dentro de un componente, sus subcomponentes.
                                '${a.padreId == null ? 'Componentes' : 'Subcomponentes'} · ${componentes.length}',
                              ],
                              iconos: const [
                                Icons.content_paste_rounded,
                                Icons.account_tree_outlined,
                              ],
                              seleccion: vista,
                              onChanged: (i) => setState(() => vista = i),
                            ),
                            if (vista == 0)
                              FiltroFlujoMantenimiento(
                                incluirSinOrden: false,
                                seleccion: _estadoOrden,
                                onChanged: (i) => setState(() => _estadoOrden = i),
                              ),
                            // Futuro: filtro de prioridad Normal / Alta / Muy alta.
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: vista == 0
                            ? _mantenimientos(a, planes)
                            : componentes.isEmpty
                            ? Vacio(
                                icono: Icons.account_tree_outlined,
                                titulo: 'Sin componentes',
                                texto:
                                    'Añade las piezas y los componentes de este ${a.padreId == null ? 'activo' : 'componente'}.',
                              )
                            : _TablaActivos(
                                componentes,
                                _abrir,
                                componentes: true,
                              ),
                      ),
                    ],
                  ),
                  // Con las esquinas y el borde de las demás tarjetas y tablas.
                  1 => Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(P.radio),
                    ),
                    // El borde encima del formulario: si no, su fondo blanco lo tapa en las esquinas.
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(P.radio),
                      border: Border.all(color: P.borde),
                    ),
                    child: ActivoForm(
                      key: ValueKey(
                        '${a.id}-$vuelta-${jsonEncode(a.toJson())}',
                      ),
                      original: a,
                      incrustada: true,
                      onTerminar: () => setState(() => vuelta++),
                    ),
                  ),
                  // Pendientes; con «Histórico», las hechas (abajo).
                  2 when !_historicoOt => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: Builder(builder: (context) {
                        final filtradas = ots.where(otPendiente).where((ot) => switch (_asignacionOt) {
                          1 => ot.trabajadorIds.isEmpty,
                          2 => ot.trabajadorIds.isNotEmpty,
                          _ => true,
                        }).toList()..sort((a, b) {
                          if (a.proximo == null) return b.proximo == null ? 0 : 1;
                          if (b.proximo == null) return -1;
                          return a.proximo!.compareTo(b.proximo!);
                        });
                        return filtradas.isEmpty
                            ? Vacio(
                                icono: Icons.assignment_outlined,
                                titulo: _asignacionOt == 0 ? 'Sin órdenes pendientes' : 'Sin órdenes con este filtro',
                                texto: 'Las órdenes por hacer de este activo y sus componentes aparecerán aquí; las hechas, en Histórico.',
                              )
                            : TablaTrabajos(
                                filtradas,
                                conCliente: false,
                                nombre: 'orden de trabajo',
                                onAbrir: (id) => setState(() => tareaId = id),
                              );
                      })),
                    ],
                  ),
                  _ => Historicos(activoId: a.id, incrustada: true),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> abrirActivoForm(
  BuildContext context, {
  Activo? original,
  String? padreId,
}) => abrirPanel(context, ActivoForm(original: original, padreId: padreId));

/// Alta y edición de un activo o de un componente (con [padreId], dentro de un activo o de otro componente).
class ActivoForm extends StatefulWidget {
  final Activo? original;
  final String? padreId;
  final bool incrustada, soloLectura;
  final VoidCallback? onTerminar;
  const ActivoForm({
    super.key,
    this.original,
    this.padreId,
    this.incrustada = false,
    this.soloLectura = false,
    this.onTerminar,
  });

  @override
  State<ActivoForm> createState() => _ActivoFormState();
}

class _ActivoFormState extends State<ActivoForm> {
  late final Activo a =
      widget.original?.copia() ??
      Activo(id: store.nuevoId(), padreId: widget.padreId);
  late final tag = TextEditingController(text: a.tag)
    ..addListener(() => setState(() {}));
  late final nombre = TextEditingController(text: a.nombre)
    ..addListener(() => setState(() {}));
  late final fabricante = TextEditingController(text: a.fabricante);
  late final modelo = TextEditingController(text: a.modelo);
  late final serie = TextEditingController(text: a.numeroSerie);
  late final division = TextEditingController(text: a.division);
  late final descripcion = TextEditingController(text: a.descripcion);
  late final horasC = TextEditingController(
    text: a.horas == 0 ? '' : '${a.horas}',
  )..addListener(() => setState(() => a.fechaLectura = hoy()));
  late final ultimoContador = TextEditingController(
    text: '${a.horasUltimoMantenimiento}',
  )..addListener(_actualizar);
  late final ritmo = TextEditingController(
    text: a.horasUso == 0 ? '' : '${a.horasUso}',
  )..addListener(_actualizar);
  final _claveIdentificacion = GlobalKey(), _claveMantenimiento = GlobalKey();
  late final repuestos = TextEditingController(text: a.repuestos);
  late final turnoC = TextEditingController(
    text: a.horasTurno.toStringAsFixed(a.horasTurno % 1 == 0 ? 0 : 1),
  );
  late final notas = TextEditingController(text: a.notas);
  bool intentoGuardar = false;

  @override
  void dispose() {
    for (final c in [
      tag,
      nombre,
      fabricante,
      modelo,
      serie,
      division,
      horasC,
      repuestos,
      notas,
      ultimoContador,
      ritmo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _actualizar() => setState(() {});

  double? _valor(TextEditingController c, {double? vacio}) {
    var texto = c.text.trim().replaceAll(' ', '');
    if (texto.isEmpty) return vacio;
    if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(texto))
      texto = texto.replaceAll('.', '');
    final n = double.tryParse(texto.replaceAll(',', '.'));
    return n != null && n.isFinite ? n : null;
  }

  Map<String, String> get _erroresMantenimiento {
    final errores = <String, String>{};
    final actual = _valor(horasC, vacio: 0);
    final uso = _valor(ritmo, vacio: 0);
    if (actual == null || actual < 0)
      errores['actual'] = 'Escribe un contador válido, desde 0';
    if (uso == null || uso < 0 || uso > (a.usoSemanal ? 168 : 24)) {
      errores['uso'] = a.usoSemanal
          ? 'Entre 0 y 168 horas semanales'
          : 'Entre 0 y 24 horas al día';
    }
    return errores;
  }

  void _irA(GlobalKey clave) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = clave.currentContext;
        if (c != null)
          Scrollable.ensureVisible(
            c,
            duration: const Duration(milliseconds: 300),
            alignment: .1,
          );
      });

  /// Desplegable con aspecto de campo (etiqueta encima y chevron), alineado con los campos de texto.
  Widget _menu<T>(
    String label, {
    required String tooltip,
    required T valor,
    required Map<T, String> opciones,
    required ValueChanged<T> onSelected,
  }) => conMargen(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        etiqueta(label),
        BotonMenu<T>(
          relleno: EdgeInsets.zero,
          tooltip: tooltip,
          seleccionado: valor,
          opciones: [for (final e in opciones.entries) (e.key, Text(e.value))],
          onSelected: onSelected,
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: P.textoSuave,
              ),
            ),
            child: Text(opciones[valor]!),
          ),
        ),
      ],
    ),
  );

  /// Lectura del contador y ritmo de uso: datos del activo con los que se estiman sus mantenimientos por horas.
  /// Los mantenimientos van aparte (Resumen → Mantenimientos).
  Widget _mantenimiento() {
    final errores = intentoGuardar ? _erroresMantenimiento : <String, String>{};
    // Un componente cuenta las horas de su activo principal.
    if (componente) {
      final r = raizActivo(a.padreId);
      return Bloque(
        'Contador y uso',
        descripcion: 'Las horas son las de su activo principal.',
        [
          Text(
            r == null
                ? 'Usa el contador del activo del que cuelga.'
                : 'Usa el contador de ${r.titulo}: ${horas(horasHoy(r))} hoy.',
            style: TextStyle(fontSize: 13.5, color: P.textoSuave),
          ),
        ],
      );
    }
    return KeyedSubtree(
      key: _claveMantenimiento,
      child: Bloque(
        'Contador y uso',
        descripcion: 'Con ellos se estiman los mantenimientos por horas de este activo o componente.',
        [
          dos(
            CampoFecha(
              'Fecha de la lectura',
              a.fechaLectura,
              (d) => setState(() => a.fechaLectura = d),
              hasta: hoy(),
            ),
            campo(
              'Contador actual (h)',
              horasC,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              hint: '0',
              error: errores['actual'],
            ),
          ),
          // Fijo (por día o por semana) o planificado a mano por turnos en el calendario de uso.
          dos(
            _menu<int>(
              'Ritmo de uso',
              tooltip: 'Cómo se suman las horas: fijas o según los turnos que marques en el calendario',
              valor: a.usoPlanificado ? 2 : (a.usoSemanal ? 1 : 0),
              opciones: const {
                0: 'Media por día natural',
                1: 'Total por semana',
                2: 'Planificado por turnos',
              },
              onSelected: (v) => setState(() {
                a.usoPlanificado = v == 2;
                if (v < 2) a.usoSemanal = v == 1;
              }),
            ),
            a.usoPlanificado
                ? campo(
                    'Horas por turno',
                    turnoC,
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    hint: '8',
                  )
                : campo(
                    a.usoSemanal
                        ? 'Horas de uso por semana'
                        : 'Horas de uso por día',
                    ritmo,
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    hint: 'Sin indicar',
                    error: errores['uso'],
                  ),
          ),
          if (a.usoPlanificado)
            Text(
              'Marca los días y turnos en Activos → «Uso de activos». Cada turno suma sus horas al contador.',
              style: TextStyle(fontSize: 12.5, color: P.textoSuave),
            ),
        ],
      ),
    );
  }

  bool get componente => a.padreId != null;
  String? get error =>
      intentoGuardar && tag.text.trim().isEmpty && nombre.text.trim().isEmpty
      ? 'Ponle un tag o un nombre'
      : null;

  void guardar() {
    setState(() => intentoGuardar = true);
    if (error != null) return _irA(_claveIdentificacion);
    if (_erroresMantenimiento.isNotEmpty) return _irA(_claveMantenimiento);
    a
      ..tag = tag.text.trim()
      ..nombre = nombre.text.trim()
      ..descripcion = descripcion.text.trim()
      ..horasTurno =
          double.tryParse(turnoC.text.trim().replaceAll(',', '.')) ??
          a.horasTurno
      ..fabricante = fabricante.text.trim()
      ..modelo = modelo.text.trim()
      ..numeroSerie = serie.text.trim()
      ..division = division.text.trim()
      ..horas = _valor(horasC, vacio: 0) ?? 0
      ..horasUltimoMantenimiento = math.min(
        _valor(ultimoContador, vacio: 0) ?? 0,
        _valor(horasC, vacio: 0) ?? 0,
      )
      ..horasUso = _valor(ritmo, vacio: 0) ?? 0
      ..repuestos = repuestos.text.trim()
      ..notas = notas.text.trim();
    store.guardarActivo(a);
    if (widget.incrustada) {
      widget.onTerminar?.call();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existe = widget.original != null;
    final padre = store.activo(a.padreId);

    final que = componente ? 'componente' : 'activo';
    return VentanaFormulario(
      incrustada: widget.incrustada,
      soloLectura: widget.soloLectura,
      onCancelar: widget.incrustada ? widget.onTerminar : null,
      etiqueta: padre?.titulo ?? 'Activos',
      titulo: existe ? 'Editar $que' : 'Nuevo $que',
      tituloDesplazado: [
        tag.text,
        nombre.text,
      ].where((x) => x.isNotEmpty).join(' · '),
      onGuardar: guardar,
      avisos: [
        if (error != null)
          ('Te falta el tag o el nombre', () => _irA(_claveIdentificacion)),
        if (intentoGuardar && _erroresMantenimiento.isNotEmpty)
          (_erroresMantenimiento.values.first, () => _irA(_claveMantenimiento)),
      ],
      onBorrar: !existe
          ? null
          : () async {
              final nav = Navigator.of(context);
              final n = store.ramaDe(a.id).length - 1;
              final con = n == 0
                  ? ''
                  : ' y sus $n ${n == 1 ? 'componente' : 'componentes'}';
              if (await confirmar(
                context,
                '¿Eliminar ${a.titulo}$con? Sus OT se quedan, sin activo.',
              )) {
                store.borrarActivo(a.id);
                if (widget.incrustada) {
                  widget.onTerminar?.call();
                } else {
                  nav.pop();
                }
              }
            },
      campos: [
        Bloque(
          componente ? 'Componente' : 'Activo',
          primero: true,
          descripcion: componente
              ? 'Qué pieza de la máquina es.'
              : 'Qué máquina es y cómo se identifica.',
          pie: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              etiqueta('Icono'),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  // Once de siempre, el elegido si es del catálogo amplio, y «+» para abrir el catálogo.
                  for (final (clave, nombre) in [
                    ...todosLosIconos.take(11),
                    if (!todosLosIconos.take(11).any((i) => i.$1 == a.icono))
                      todosLosIconos.firstWhere(
                        (i) => i.$1 == a.icono,
                        orElse: () => todosLosIconos[11],
                      ),
                  ])
                    IconButton(
                      tooltip: nombre,
                      isSelected: a.icono == clave,
                      style: IconButton.styleFrom(
                        fixedSize: const Size(40, 40),
                        backgroundColor: a.icono == clave
                            ? P.morado.withValues(alpha: .1)
                            : Colors.transparent,
                        foregroundColor: a.icono == clave
                            ? P.morado
                            : P.textoSuave,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(P.radioControl),
                        ),
                      ),
                      onPressed: () => setState(() => a.icono = clave),
                      icon: IconoActivo(clave, size: 22),
                    ),
                  IconButton(
                    tooltip: 'Más iconos',
                    style: IconButton.styleFrom(
                      fixedSize: const Size(40, 40),
                      foregroundColor: P.textoSuave,
                      side: BorderSide(color: P.borde),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(P.radioControl),
                      ),
                    ),
                    onPressed: () async {
                      final clave = await elegirIcono(context, a.icono);
                      if (clave != null) setState(() => a.icono = clave);
                    },
                    icon: const Icon(Icons.add_rounded, size: 22),
                  ),
                ],
              ),
            ],
          ),
          [
            dos(
              KeyedSubtree(
                key: _claveIdentificacion,
                child: campo(
                  'Tag',
                  tag,
                  hint: componente ? 'CAM-01-MOT' : 'CAM-01',
                  error: error,
                  obligatorio: true,
                ),
              ),
              campo(
                'Nombre',
                nombre,
                hint: componente ? 'Motor' : 'Camión cisterna',
                obligatorio: true,
              ),
            ),
            // Opcional, como la de los mantenimientos: sale bajo el nombre en las listas.
            campo(
              'Descripción',
              descripcion,
              hint: componente
                  ? 'Motor diésel de 6 cilindros'
                  : 'Transporte de residuos líquidos',
              lineas: 4, // Tan alto como la rejilla de iconos de al lado.
            ),
          ],
        ),
        Bloque('Ficha técnica', descripcion: 'Los datos de la placa.', [
          dos(campo('Fabricante', fabricante), campo('Modelo', modelo)),
          campo('Número de serie', serie),
          if (!componente)
            campo(
              'División o actividad',
              division,
              hint: 'Limpieza de tanques, transporte…',
            ),
        ]),
        _mantenimiento(),
        Bloque('Repuestos', descripcion: 'Piezas y consumibles que usa.', [
          campo('Repuestos', repuestos, lineas: 3),
        ]),
        Bloque('Notas', [campo('Notas internas', notas, lineas: 3)]),
      ],
    );
  }
}
