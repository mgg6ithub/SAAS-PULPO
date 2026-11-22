import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tabla_trabajos.dart';
import 'tarea_card.dart';
import '../marca.dart';

/// Filtro por fecha que llega desde las cifras de Inicio: 0 ninguno, 1 hoy, 2 semana, 3 vencidos, 4 hechos.
final filtroFechaTrabajos = ValueNotifier<int>(0);

/// Pultec: filtro por criticidad (0 = todas; 1.. = tipo de mantenimiento), también desde Inicio.
final filtroCriticidadTrabajos = ValueNotifier<int>(0);

/// Pultec: Órdenes de trabajo partida en dos: pendientes (false) o histórico de las hechas (true).
final historicoTrabajos = ValueNotifier<bool>(false);

/// Pultec: OT a marcar en la lista de Órdenes de trabajo (llegando desde su incidencia con «Ver OT»).
final otMarcada = ValueNotifier<String?>(null);

/// Cada aviso pide a la barra lateral que vaya a Órdenes de trabajo.
final pedirOrdenes = ValueNotifier<int>(0);

/// «Ver OT»: cierra lo que haya encima, va a Órdenes de trabajo (pendientes, sin filtros) y deja marcada esa OT.
void verOtEnOrdenes(BuildContext context, String id) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  historicoTrabajos.value = false;
  filtroFechaTrabajos.value = 0;
  filtroCriticidadTrabajos.value = 0;
  otMarcada.value = id;
  pedirOrdenes.value++;
}

/// Al histórico: completadas y canceladas.
bool _hecha(Tarea t) => t.estado == EstadoTrabajo.realizado || t.estado == EstadoTrabajo.noRealizado;

/// Pultec: en vez de «Esta semana», «Sin técnico» (órdenes pendientes que nadie tiene asignadas).
final _filtrosFecha = [
  ('Para hoy', P.morado, Icons.today_rounded),
  // Pultec: «Sin asignar» sin color, igual que en las columnas.
  industrial ? ('Sin asignar', P.gris, Icons.person_off_outlined) : ('Esta semana', P.teal, Icons.date_range_rounded),
  ('Vencidos', P.rojo, Icons.warning_amber_rounded),
  ('Hechos', P.verde, Icons.task_alt_rounded),
];

bool pasaFechaTrabajo(Tarea t, int f) {
  if (f == 0) return true;
  if (t.esPlantilla || !t.activa) return false;
  if (f == 4) return t.ultimo != null && diasHasta(t.ultimo!) >= -30;
  // Pultec: estado y automatizaciones (5 pendientes, 6 completadas, 7 con automatizaciones).
  if (f == 5) return t.estado == EstadoTrabajo.pendiente || t.estado == EstadoTrabajo.enCurso;
  if (f == 6) return t.estado == EstadoTrabajo.realizado;
  if (f == 7) return t.automatizaciones.isNotEmpty;
  if (f == 2 && industrial) {
    return t.trabajadorIds.isEmpty && (t.estado == EstadoTrabajo.pendiente || t.estado == EstadoTrabajo.enCurso);
  }
  if (t.proximo == null) return false;
  final d = diasHasta(t.proximo!);
  return switch (f) {
    1 => d == 0,
    2 => d >= 0 && d <= 7,
    _ => d < 0,
  };
}

/// Todas las tareas: las de cada cliente y las plantillas (sin cliente).
class TareasPagina extends StatefulWidget {
  final ValueChanged<String> onAbrir;
  const TareasPagina({super.key, required this.onAbrir});

  @override
  State<TareasPagina> createState() => _TareasPaginaState();
}

class _TareasPaginaState extends State<TareasPagina> {
  String q = '';
  int pestana = 0; // 0 de clientes, 1 plantillas, 2 todas
  String? tipo;
  String? _activoFiltro;
  bool lista = true;

  /// Pultec, en el histórico: false las completadas (de serie), true solo las canceladas.
  bool _canceladas = false;

  void _alCambiarFecha() => setState(() => pestana = 0);

  /// Llegando con «Ver OT»: sin búsqueda ni filtros, para que la OT marcada se vea seguro.
  void _alMarcar() => setState(() {
    pestana = 0;
    q = '';
    tipo = null;
    _activoFiltro = null;
  });

  @override
  void initState() {
    super.initState();
    filtroFechaTrabajos.addListener(_alCambiarFecha);
    filtroCriticidadTrabajos.addListener(_alCambiarFecha);
    historicoTrabajos.addListener(_alCambiarFecha);
    otMarcada.addListener(_alMarcar);
    if (otMarcada.value != null) _alMarcar();
  }

  @override
  void dispose() {
    filtroFechaTrabajos.removeListener(_alCambiarFecha);
    filtroCriticidadTrabajos.removeListener(_alCambiarFecha);
    historicoTrabajos.removeListener(_alCambiarFecha);
    otMarcada.removeListener(_alMarcar);
    // Al salir de la sección, la marca se olvida.
    WidgetsBinding.instance.addPostFrameCallback((_) => otMarcada.value = null);
    super.dispose();
  }

  Future<void> _editarEtiqueta(EtiquetaTrabajo? e) => showDialog(context: context, builder: (_) => _EtiquetaDialogo(e));

  @override
  Widget build(BuildContext context) {
    final nTrabajos = store.tareas.length - store.plantillas.length;
    final fecha = filtroFechaTrabajos.value;
    final criticidad = filtroCriticidadTrabajos.value;
    final rama = _activoFiltro == null ? null : store.ramaDe(_activoFiltro!);
    final filtradas =
        store.tareas.where((t) {
          if (pestana == 0 && t.esPlantilla) return false;
          if (pestana == 1 && !t.esPlantilla) return false;
          if (tipo != null && t.tipo != tipo) return false;
          if (industrial && rama != null && !rama.contains(t.activoId)) return false;
          if (industrial && !t.esPlantilla && _hecha(t) != historicoTrabajos.value) return false;
          if (industrial && !t.esPlantilla && historicoTrabajos.value &&
              (t.estado == EstadoTrabajo.noRealizado) != _canceladas) {
            return false;
          }
          if (!pasaFechaTrabajo(t, fecha)) return false;
          if (criticidad != 0 && t.tipoMantenimiento?.index != criticidad - 1) return false;
          final texto = '${t.nombre} ${t.marca} ${t.ubicacion} ${store.cliente(t.clienteId)?.nombre ?? ''}'
              .toLowerCase();
          return texto.contains(q.toLowerCase());
        }).toList()..sort((a, b) {
          if (a.esPlantilla != b.esPlantilla) return a.esPlantilla ? 1 : -1;
          return (a.proximo ?? DateTime(2100)).compareTo(b.proximo ?? DateTime(2100));
        });
    final tiposUsados = {for (final t in store.tareas) t.tipo};

    return Stack(
      children: [
        Padding(
          padding: margenPagina,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Una sola barra (como el Itinerario): título y filtros a la izquierda; buscador y acciones a la derecha.
              BarraVista(
                izquierda: [
                  // Solo el título: sin icono grande ni frase de relleno debajo.
                  TituloVista(m('Trabajos')),
                  // Pultec: pendientes y, aparte, el histórico de las hechas (para que no sea una lista sin fin).
                  // Pultec: buscador y vista junto al título si caben (si no, bajan debajo).
                  if (industrial) ...[
                    Buscador(hint: 'Buscar orden de trabajo…', width: 280, onChanged: (v) => setState(() => q = v)),
                    SelectorVista(lista: lista, onChanged: (v) => setState(() => lista = v)),
                  ],
                  // Pultec, de momento sin plantillas: solo la lista de órdenes de trabajo.
                  if (!industrial)
                    Pestanas(
                      opciones: ['Todos $nTrabajos', 'Plantillas ${store.plantillas.length}'],
                      seleccion: pestana,
                      onChanged: (i) => setState(() => pestana = i),
                    ),
                ],
                derecha: [
                  if (!industrial) Buscador(
                    hint: industrial ? 'Buscar orden de trabajo…' : 'Buscar trabajo…',
                    width: 280,
                    onChanged: (v) => setState(() => q = v),
                  ),
                  if (!industrial) SelectorVista(lista: lista, onChanged: (v) => setState(() => lista = v)),
                ],
                principal: BotonPrimario(
                  pestana == 1 ? 'Nueva plantilla' : m('Nuevo trabajo'),
                  conIcono: industrial,
                  tecla: 'N',
                  onPressed: () => abrirTareaForm(context, null, plantilla: pestana == 1),
                ),
              ),
              // Pultec: Pendientes / Histórico a la izquierda y la criticidad a la derecha del todo.
              if (industrial) ...[
                const SizedBox(height: huecoVista),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 8,
                    spacing: 12,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Pestanas(
                            opciones: [
                              'Pendientes ${store.tareas.where((t) => !t.esPlantilla && !_hecha(t)).length}',
                              'Histórico ${store.tareas.where((t) => !t.esPlantilla && _hecha(t)).length}',
                            ],
                            iconos: const [Icons.radio_button_unchecked_rounded, Icons.task_alt_rounded],
                            coloresIconos: [null, P.verde],
                            seleccion: historicoTrabajos.value ? 1 : 0,
                            onChanged: (i) {
                              _canceladas = false;
                              historicoTrabajos.value = i == 1;
                              filtroFechaTrabajos.value = 0;
                            },
                          ),
                          // Histórico: de serie, las completadas; un botón enseña solo las canceladas (en rojo).
                          if (historicoTrabajos.value)
                            BotonAccion(
                              'Canceladas',
                              icono: Icons.block_rounded,
                              tooltip: _canceladas ? 'Volver a las completadas' : 'Ver solo las canceladas',
                              color: _canceladas ? P.rojo : null,
                              onPressed: () => setState(() => _canceladas = !_canceladas),
                            ),
                        ],
                      ),
                    Pestanas(
                      opciones: const ['Todos', 'Preventivo', 'No crítico', 'Crítico'],
                      colores: [null, for (final t in TipoMantenimiento.values) t.color],
                      seleccion: criticidad,
                      compactas: true,
                      onChanged: (i) => filtroCriticidadTrabajos.value = i,
                    ),
                    ],
                  ),
                ),
              ],
              // En el histórico no hacen falta los filtros de lo pendiente.
              if (!(industrial && historicoTrabajos.value)) ...[
                const SizedBox(height: huecoVista),
                Row(children: [
                  // Pultec: el activo a la izquierda del todo; los filtros, a la derecha (en espejo: «Todos» al final).
                  if (industrial) ...[
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 210), child: SelectorActivo(_activoFiltro,
                      (id) => setState(() => _activoFiltro = id), filtro: true)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Align(
                  alignment: industrial ? Alignment.centerRight : Alignment.centerLeft,
                  child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: industrial,
                  child: industrial
                      ? Row(
                          // Pultec: un solo filtro a la vez; al tocar el marcado, vuelve a «Todos».
                          children: [
                            // (número de filtro, etiqueta, color, icono); sin «Hechos»: lo cubre el histórico.
                            for (final (i, nombre, color, icono) in [
                              for (final (j, (n, c, ic)) in _filtrosFecha.indexed)
                                if (j != 3) (j + 1, n, c, ic),
                              (7, 'Automatizaciones', P.ambar, Icons.bolt_rounded),
                            ]) ...[
                              _ChipTipo(
                                nombre,
                                color,
                                fecha == i,
                                () => filtroFechaTrabajos.value = fecha == i ? 0 : i,
                                icono: icono,
                                punto: true,
                              ),
                              const SizedBox(width: 6),
                            ],
                            // «Todos» aparte, a la derecha del todo.
                            Container(width: 1, height: 20, color: P.borde, margin: const EdgeInsets.only(right: 6)),
                            _ChipTipo('Todos', P.textoSuave, fecha == 0, () => filtroFechaTrabajos.value = 0, punto: false),
                          ],
                        )
                      : Row(
                          children: [
                            // Por fecha (las mismas cifras de Inicio): al tocar una se filtra; al tocarla otra vez, se quita.
                            for (final (i, (nombre, color, icono)) in _filtrosFecha.indexed) ...[
                              _ChipTipo(
                                fecha == i + 1 ? '$nombre  ×' : nombre,
                                color,
                                fecha == i + 1,
                                () => filtroFechaTrabajos.value = fecha == i + 1 ? 0 : i + 1,
                                icono: icono,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(width: 1, height: 20, color: P.borde, margin: const EdgeInsets.only(right: 6)),
                            // Pultec: sin etiquetas de tipo («Otro»); se filtra por fecha y criticidad.
                            if (!industrial)
                              for (final x in tipos.where((x) => tiposUsados.contains(x.nombre))) ...[
                                _ChipTipo(
                                  x.nombre,
                                  x.color,
                                  tipo == x.nombre,
                                  () => setState(() => tipo = tipo == x.nombre ? null : x.nombre),
                                ),
                                const SizedBox(width: 6),
                              ],
                            for (final e in store.etiquetas) ...[
                              _ChipTipo(e.nombre, Color(e.color), false, () => _editarEtiqueta(e)),
                              const SizedBox(width: 6),
                            ],
                            _ChipNueva(() => _editarEtiqueta(null)),
                          ],
                        ),
                  ))),
                ]),
              ],
              // Pultec: que se entienda de dónde salen las órdenes que se repiten.
              if (industrial && !historicoTrabajos.value && !ajustes.consejoCerrado('ot_mantenimiento')) ...[
                const SizedBox(height: 12),
                const Consejo(
                  clave: 'ot_mantenimiento',
                  'Las órdenes que se repiten se crean solas: crea un mantenimiento en su activo (Activos, el activo, '
                  '+ Mantenimiento) y Pultec generará cada orden cuando toque. Aquí, crea solo las órdenes sueltas.',
                ),
              ],
              if (pestana == 1) ...[
                const SizedBox(height: 12),
                Consejo(
                  m(
                    'Las plantillas son trabajos que dejas pre-creados con ciertos campos ya rellenos. '
                    'Al crear un trabajo, eliges una plantilla y se rellena casi todo.',
                  ),
                ),
              ],
              const SizedBox(height: huecoVista),
              Expanded(
                child: filtradas.isEmpty
                    ? Vacio(
                        icono: Marca.iconoTrabajo,
                        titulo: store.tareas.isEmpty ? m('Aún no hay trabajos') : null,
                        texto: pestana == 0 && nTrabajos == 0
                            ? (industrial
                                  ? 'Crea tu primera orden de trabajo.'
                                  : m('Crea tu primer trabajo, desde cero o a partir de una plantilla.'))
                            : m('No hay trabajos con estos filtros'),
                        // Sin búsqueda ni filtro de tipo: botón para crear (el primero, si aún no hay).
                        accion: q.isEmpty && tipo == null && fecha == 0 && criticidad == 0
                            ? FilledButton(
                                onPressed: () => abrirTareaForm(context, null, plantilla: pestana == 1),
                                child: Text(
                                  pestana == 1
                                      ? 'Nueva plantilla'
                                      : nTrabajos == 0
                                      ? m('Añadir el primer trabajo')
                                      : m('Nuevo trabajo'),
                                ),
                              )
                            : null,
                      )
                    : lista
                    ? TablaTrabajos(filtradas, onAbrir: widget.onAbrir, marcada: otMarcada.value)
                    // Solo se reconstruye al cambiar el nº de columnas; el ancho de cada tarjeta lo pone la Rejilla.
                    : ListaRejilla(
                        anchoMin: 420,
                        hueco: 14,
                        padding: EdgeInsets.zero,
                        total: filtradas.length,
                        item: (i) => TareaCard(filtradas[i]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// «Nueva» etiqueta: sin fondo, con un plus y el borde de rayas.
class _ChipNueva extends StatelessWidget {
  final VoidCallback onTap;
  const _ChipNueva(this.onTap);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Crear una etiqueta',
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: CustomPaint(
        painter: BordeDiscontinuo(P.textoSuave.withValues(alpha: .6), BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: P.textoSuave),
              const SizedBox(width: 5),
              Text(
                'Nueva',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: P.textoSuave),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Filtro por tipo: píldora con el punto de color del tipo; la elegida, con borde de su color.
class _ChipTipo extends StatelessWidget {
  final String nombre;
  final Color color;
  final bool sel;
  final VoidCallback onTap;

  /// Icono de su color en lugar del punto (los filtros de fecha, como las cifras de Inicio).
  final IconData? icono;
  final bool punto;
  const _ChipTipo(this.nombre, this.color, this.sel, this.onTap, {this.icono, this.punto = true});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sel ? color.withValues(alpha: .1) : P.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? color : P.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null)
            Icon(icono, size: 15, color: color)
          else if (punto)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (icono != null || punto) const SizedBox(width: 7),
          Text(
            nombre,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: sel ? color : P.texto),
          ),
        ],
      ),
    ),
  );
}

/// Crear o editar una etiqueta: nombre y color.
class _EtiquetaDialogo extends StatefulWidget {
  final EtiquetaTrabajo? original;
  const _EtiquetaDialogo(this.original);

  @override
  State<_EtiquetaDialogo> createState() => _EtiquetaDialogoState();
}

class _EtiquetaDialogoState extends State<_EtiquetaDialogo> {
  late final nombre = TextEditingController(text: widget.original?.nombre);
  late int color = widget.original?.color ?? SelectorColorTarea.colores.first;

  @override
  void dispose() {
    nombre.dispose();
    super.dispose();
  }

  void _guardar() {
    final n = nombre.text.trim();
    if (n.isEmpty) return;
    store.guardarEtiqueta(EtiquetaTrabajo(id: widget.original?.id ?? store.nuevoId(), nombre: n, color: color));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.original == null ? 'Nueva etiqueta' : 'Editar etiqueta',
              style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nombre,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in SelectorColorTarea.colores)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => color = c),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                      child: color == c ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.original != null)
                  TextButton(
                    onPressed: () {
                      store.deshacible(
                        'Has borrado la etiqueta ${widget.original!.nombre}',
                        () => store.borrarEtiqueta(widget.original!.id),
                      );
                      Navigator.pop(context);
                    },
                    child: Text('Eliminar', style: TextStyle(color: P.rojo)),
                  ),
                const SizedBox(width: 8),
                BotonPrimario('Guardar', onPressed: _guardar),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
