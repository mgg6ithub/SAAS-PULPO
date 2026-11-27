import 'package:flutter/material.dart';

import '../industrial/tipo_mantenimiento.dart';
import '../industrial/iconos.dart';
import '../industrial/gravedad.dart' show EnVivoOt, cancelarOts, origenOt, periodicidadOt, AnilloCiclo, cicloOt, descripcionOt;
import '../columnas.dart';
import '../forms.dart';
import '../industrial/activos.dart' show arbolActivos, enOrdenDelUsuario;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'informes.dart' show BotonPdf;
import '../marca.dart';

/// La lista de trabajos (columnas que se redimensionan y se intercambian, selección múltiple, hover).
/// La usan la página de Trabajos y la ficha de un trabajo para sus subtrabajos: se ven igual.
class TablaTrabajos extends StatefulWidget {
  final List<Tarea> trabajos;
  final ValueChanged<String> onAbrir;

  /// Columna de cliente.
  final bool conCliente;

  /// Ancho a partir del cual salen todas las columnas (la ficha de un trabajo es más estrecha que la página).
  final double umbralAncho;

  /// Cómo se llama cada fila, en singular ('trabajo', 'subtrabajo').
  final String nombre;

  /// OT a destacar (borde morado) y dejar marcada para el teclado: la de «Ver OT» de una incidencia.
  final String? marcada;
  const TablaTrabajos(
    this.trabajos, {
    super.key,
    required this.onAbrir,
    this.conCliente = true,
    this.umbralAncho = 1000,
    this.nombre = 'trabajo',
    this.marcada,
  });

  @override
  State<TablaTrabajos> createState() => _TablaTrabajosState();
}

class _TablaTrabajosState extends State<TablaTrabajos> {
  final _completando = ValueNotifier<Set<String>>({});

  Future<void> _animarCompletada(String id) async {
    _completando.value = {..._completando.value, id};
    await Future<void>.delayed(const Duration(milliseconds: 280));
  }

  @override
  void didUpdateWidget(covariant TablaTrabajos oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.trabajos.map((t) => t.id).toSet();
    _completando.value = _completando.value.intersection(ids);
  }

  @override
  void dispose() {
    _completando.dispose();
    super.dispose();
  }

  bool seleccionando = false;
  final seleccion = <String>{};

  void salirSeleccion() => setState(() {
    seleccionando = false;
    seleccion.clear();
  });

  Future<void> eliminarSeleccion() async {
    // Pultec: las OT abiertas no se borran, se cancelan (quedan en el histórico); las del histórico sí se borran.
    if (industrial) {
      final sel = [for (final id in seleccion) ?store.tarea(id)];
      final cerradas = sel.where((t) => !t.estado.abierta).toList();
      if (cerradas.isNotEmpty) {
        final que = '${cerradas.length} ${cerradas.length == 1 ? 'orden del histórico' : 'órdenes del histórico'}';
        if (!await confirmar(context, '¿Eliminar $que?', nota: 'Podrás deshacerlo.')) return;
        store.deshacible('Has borrado $que', () {
          for (final t in cerradas) {
            store.borrarTarea(t.id);
          }
        });
      }
      if (!mounted) return;
      final abiertas = sel.where((t) => t.estado.abierta).toList();
      if (abiertas.isNotEmpty) cancelarOts(context, abiertas);
      salirSeleccion();
      return;
    }
    final n = seleccion.length;
    final nombre = m('$n ${n == 1 ? widget.nombre : '${widget.nombre}s'}');
    if (!await confirmar(context, preguntaBorrarTrabajos(seleccion, nombre: nombre), nota: 'Podrás deshacerlo.')) return;
    store.deshacible('Has borrado $nombre', () {
      for (final id in seleccion) {
        store.borrarTarea(id);
      }
    });
    salirSeleccion();
  }

  String _descripcion(Tarea t) => descripcionOt(t);

  /// Cuántos subtrabajos tiene el trabajo.
  Widget _subtrabajos(Tarea t) {
    final n = store.hijas(t.id).length;
    if (n == 0) return celdaTexto('', suave: true);
    return Row(
      children: [
        Icon(Icons.account_tree_outlined, size: 14, color: P.textoSuave),
        const SizedBox(width: 6),
        celdaTexto('$n'),
      ],
    );
  }

  /// Cambia a la vez lo seleccionado: estado, asignado, cliente, fecha o periodicidad.
  Widget _cambiar() {
    final sel = [for (final id in seleccion) ?store.tarea(id)];
    void aplicado() => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 320,
        content: Text(m('Cambiado en ${sel.length} ${sel.length == 1 ? widget.nombre : '${widget.nombre}s'}')),
      ),
    );
    void aplicar(void Function(Tarea t) cambio) {
      store.aplicarA(sel, cambio);
      aplicado();
    }

    Widget opcion(String texto, VoidCallback onPressed, {Widget? icono}) =>
        MenuItemButton(leadingIcon: icono, onPressed: onPressed, child: Text(texto));

    return MenuAnchor(
      alignmentOffset: const Offset(0, -4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(P.superficie),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      menuChildren: [
        SubmenuButton(
          menuChildren: [
            for (final e in estadosTrabajo)
              opcion(
                e.etiqueta,
                () {
                  // Pultec: cancelar solo las que se pueden (no las de mantenimientos vigentes).
                  if (industrial && e == EstadoTrabajo.noRealizado) return cancelarOts(context, sel);
                  store.cambiarEstado(sel, e);
                  aplicado();
                },
                icono: industrial
                    ? Icon(
                        e == EstadoTrabajo.realizado
                            ? Icons.check_circle_outline_rounded
                            : e == EstadoTrabajo.noRealizado
                            ? Icons.block_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: e == EstadoTrabajo.noRealizado ? P.rojo : P.textoSuave,
                      )
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
                      ),
              ),
          ],
          child: const Text('Estado'),
        ),
        SubmenuButton(
          menuChildren: [
            opcion('Sin asignar', () => aplicar((t) => t.trabajadorIds = [])),
            for (final w in store.trabajadores.where((w) => w.activo))
              opcion(
                w.nombreCompleto,
                // Pultec: las OT de otra categoría se quedan como estaban.
                () => aplicar((t) => store.puedeRecibir(w, t) ? t.trabajadorIds = [w.id] : null),
                icono: Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 20),
              ),
          ],
          child: const Text('Asignado a'),
        ),
        if (industrial)
          SubmenuButton(
            menuChildren: [
              opcion('Sin activo', () => aplicar((t) => t.activoId = null)),
              for (final (a, _) in arbolActivos()) opcion(a.titulo, () => aplicar((t) => t.activoId = a.id)),
            ],
            child: const Text('Activo o componente'),
          )
        else
          SubmenuButton(
            menuChildren: [
              opcion(m('Sin cliente'), () => aplicar((t) => t.clienteId = null)),
              for (final c in [...store.clientes]..sort((a, b) => a.nombre.compareTo(b.nombre)))
                opcion(
                  c.nombre,
                  () => aplicar((t) => t.clienteId = c.id),
                  icono: Avatar(c.iniciales, colorPaleta(c.color), size: 20, cuadrado: true),
                ),
            ],
            child: Text(m('Cliente')),
          ),
        opcion('Fecha…', () async {
          final d = await showDatePicker(
            context: context,
            initialDate: hoy(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) aplicar((t) => t.proximo = d);
        }),
        SubmenuButton(
          menuChildren: [
            for (final p in Periodicidad.values)
              opcion(
                p.etiqueta,
                () => aplicar((t) {
                  t.periodicidad = p;
                  if (p.repite && t.proximo == null) t.proximo = masDias(t.ultimo ?? hoy(), p.dias);
                }),
              ),
          ],
          child: const Text('Periodicidad'),
        ),
      ],
      builder: (context, menu, _) => TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        onPressed: sel.isEmpty ? null : () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.unfold_more_rounded, size: 18),
        iconAlignment: IconAlignment.end,
        label: const Text('Cambiar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.trabajos;
    return Stack(
      children: [
        _tabla(ts),
        if (seleccionando)
          Positioned(
            // Sin pisar la campana de avisos (abajo a la derecha); si no cabe, se encoge.
            left: 96,
            right: 96,
            bottom: 24,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: BarraSeleccion(
                  acciones: [_cambiar()],
                  // Pultec: en el histórico (todo cerrado) se elimina; si hay alguna abierta, se cancela.
                  textoEliminar: industrial &&
                          (seleccion.isEmpty
                              ? ts.any((t) => t.estado.abierta)
                              : seleccion.any((id) => store.tarea(id)?.estado.abierta ?? false))
                      ? 'Cancelar'
                      : 'Eliminar',
                  seleccionados: seleccion.length,
                  total: ts.length,
                  nombre: m('${widget.nombre}s'),
                  onTodos: () => setState(() {
                    if (ts.every((t) => seleccion.contains(t.id))) {
                      seleccion.removeAll(ts.map((t) => t.id));
                    } else {
                      seleccion.addAll(ts.map((t) => t.id));
                    }
                  }),
                  onEliminar: eliminarSeleccion,
                  onSalir: salirSeleccion,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabla(List<Tarea> ts) => SegunTamano(
    clave: (box) => (box.maxWidth > widget.umbralAncho, box.maxWidth > 600, box.maxWidth > 1100),
    builder: (context, box) {
      // El PDF con un clic solo si cabe (en estrecho, desde la ficha de la orden).
      // Mientras se selecciona, en su sitio van los círculos de selección.
      final conPdf = !seleccionando && box.maxWidth > 980 && ts.any((t) => t.estado == EstadoTrabajo.realizado);
      // El anillo del ciclo solo si alguna orden lo tiene (las hechas no): si no, el nombre va al principio.
      final conAnillo = industrial && ts.any((t) => cicloOt(t) != null);
      // Al final, «En vivo» solo si alguna orden está en curso ahora mismo.
      final conVivo = industrial && box.maxWidth > 600 && ts.any((t) => t.estado == EstadoTrabajo.enCurso);
      final ancho = box.maxWidth > widget.umbralAncho;
      // Poco sitio (p. ej. media pantalla): columnas más estrechas y criticidad solo con su punto.
      final apurado = box.maxWidth <= 1100;
      // Móvil: solo las columnas clave.
      final medio = box.maxWidth > 600;
      return Align(
        alignment: Alignment.topCenter,
        child: Tabla(
          // Pultec: orden y columnas elegidas se guardan en la cuenta (y Exportar los sigue); se eligen en el
          // menú del final.
          id: industrial ? 'ordenes' : null,
          menuColumnas: industrial && medio,
          resaltar: widget.marcada == null ? null : (i) => ts[i].id == widget.marcada ? P.morado : null,
          focoInicial: widget.marcada == null ? null : ts.indexWhere((t) => t.id == widget.marcada),
          seleccionCabecera: BotonSeleccionLista(
            activo: seleccionando,
            onTap: () => seleccionando ? salirSeleccion() : setState(() => seleccionando = true),
          ),
          columnas: [
            if (seleccionando) const Col('', ancho: 36, cabecera: SizedBox()),
            Col(industrial ? 'Orden de trabajo' : m('Equipo / trabajo'), flex: 4, fija: true),
            // Pultec: de serie, sin «Fecha y hora» (la fecha exacta sale al pasar el ratón por el anillo del principio).
            if (industrial) ...[
              if (medio && widget.conCliente) const Col('Activo', flex: 4),
              if (medio) const Col('Origen', ancho: 150),
              // Siempre «Criticidad» con su píldora (Preventivo, No crítico, Crítico), aunque haya poco sitio.
              Col('Gravedad', ancho: apurado ? 128 : 170),
              if (medio) Col('Asignado a', ancho: apurado ? 72 : 96),
              if (medio) const Col('Fecha y hora', ancho: 160, oculta: true),
              if (ancho) const Col('Periodicidad', ancho: 120),
            ] else ...[
              if (medio && widget.conCliente) Col(m('Cliente'), flex: 3),
              if (ancho) const Col('Periodicidad', flex: 2),
              const Col('Fecha y hora', flex: 3),
              if (medio) const Col('Asignado a', ancho: 96),
            ],
            Col('Estado', ancho: industrial && apurado ? 116 : 140, derecha: true),
            if (conVivo) const Col('En vivo', ancho: 110),
            // Pultec, en el histórico: el parte en PDF con un clic (sin título, va la primera: bajo el botón de
            // selección, como los círculos al seleccionar).
            if (industrial && conPdf) const Col('', ancho: 36, cabecera: SizedBox()),
            // Columna de automatizaciones (rayo), quitada de momento: las automatizaciones se replantean.
            // if (industrial && medio)
            //   const Col('Automatización', ancho: 30, derecha: true,
            //       cabecera: Tooltip(message: 'Automatizaciones', child: _Rayo())),
            // Solo si algún trabajo de la lista tiene subtrabajos; al final y abreviada.
            if (!industrial && medio && ts.any((t) => store.hijas(t.id).isNotEmpty))
              const Col('Sub', ancho: 60, ayuda: 'Subtrabajos'),
          ],
          filas: ts.length,
          envolverFila: industrial ? (i, fila) => ValueListenableBuilder<Set<String>>(
            key: ValueKey(ts[i].id),
            valueListenable: _completando,
            child: fila,
            builder: (context, saliendo, child) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: saliendo.contains(ts[i].id) ? 0 : 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              child: child,
              builder: (context, valor, child) => IgnorePointer(
                ignoring: saliendo.contains(ts[i].id),
                child: ClipRect(child: Align(heightFactor: valor, alignment: Alignment.topCenter,
                  child: Opacity(opacity: valor, child: child))),
              ),
            ),
          ) : null,
          onTap: (i) {
            if (seleccionando) {
              setState(() => seleccion.contains(ts[i].id) ? seleccion.remove(ts[i].id) : seleccion.add(ts[i].id));
            } else {
              store.verNuevo(ts[i].id);
              widget.onAbrir(ts[i].id);
            }
          },
          // «orden de trabajo» → «órdenes de trabajo» (no «orden de trabajos»).
          pie: pieTabla(
            ts.length,
            ts.length == 1
                ? widget.nombre
                : widget.nombre.startsWith('orden ')
                ? 'órdenes ${widget.nombre.substring(6)}'
                : '${widget.nombre}s',
          ),
          celdas: (i) {
            final t = ts[i];
            final c = store.cliente(t.clienteId);
            final vencida = t.proximo != null && diasHasta(t.proximo!) < 0;
            return [
              if (seleccionando) CirculoSeleccion(seleccion.contains(t.id)),
              Row(
                children: [
                  // Pultec: cuánto le queda al ciclo, de un vistazo.
                  if (conAnillo) ...[AnilloCiclo(cicloOt(t)), const SizedBox(width: 10)],
                  if (!industrial) ...[BarraTipo(t.tipo, alto: 28, color: t.colorBloque), const SizedBox(width: 10)],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        conNuevo(t.id, celdaTexto(t.nombre, negrita: true)),
                        // Pultec: debajo, qué hay que hacer (la de la orden, o la de su mantenimiento o incidencia).
                        if (industrial && _descripcion(t).isNotEmpty)
                          Text(
                            _descripcion(t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: P.textoSuave),
                          ),
                        // Pultec: sin el tipo («Otro»), que no significa nada; solo la ubicación si la hay.
                        if (!industrial)
                          Text(
                            industrial ? t.ubicacion : [t.tipo, if (t.ubicacion.isNotEmpty) t.ubicacion].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (industrial) ...[
                if (medio && widget.conCliente)
                  Tooltip(message: store.activo(t.activoId)?.titulo ?? 'Sin activo',
                        child: Row(children: [
                          if (store.activo(t.activoId) case final activo?) ...[
                            IconoActivo(activo.icono, size: 22, color: P.textoSuave),
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: celdaTexto(store.activo(t.activoId)?.titulo ?? 'Sin activo', suave: true)),
                        ])),
                // Con el icono de su sitio: mantenimiento (portapapeles), incidencia (aviso) o a mano (una mano).
                if (medio)
                  Builder(builder: (_) {
                    final (origen, color) = origenOt(t);
                    final icono = origen == 'Mantenimiento'
                        ? Icons.content_paste_rounded
                        : origen == 'Incidencia'
                        ? Icons.report_outlined
                        : Icons.back_hand_outlined;
                    return Row(children: [
                      // Incidencia en rojo, manual (una mano) en azul y mantenimiento en gris.
                      Icon(icono, size: 18, color: origen == 'Incidencia' ? color : origen == 'Manual' ? P.azul : P.textoSuave),
                      const SizedBox(width: 6),
                      Flexible(child: celdaTexto(origen, suave: true)),
                    ]);
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: t.tipoMantenimiento == null ? celdaTexto('—', suave: true) : PillTipo(t.tipoMantenimiento!),
                  ),
                if (medio)
                  t.esPlantilla ? const SizedBox() : SelectorTrabajadores(
                        t,
                        () => store.guardarTarea(t),
                        compacto: true,
                        ofrecerSubtrabajos: !industrial,
                      ),
                if (medio)
              t.proximo == null
                  ? celdaTexto('', suave: true)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fecha(t.proximo),
                          style: TextStyle(
                            fontSize: 13,
                            color: vencida ? P.rojo : P.texto,
                            fontWeight: vencida ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        Text(
                          [relativo(t.proximo!), ?t.horario].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                        ),
                      ],
                    ),
                if (ancho) celdaTexto(periodicidadOt(t)),
              ] else ...[
                // El cliente se cambia desde la lista; un subtrabajo comparte el de su trabajo.
                if (medio && widget.conCliente)
                t.esPlantilla
                    ? Etiqueta('Plantilla', P.morado)
                    : t.padreId == null
                    ? SelectorCliente(t.clienteId, (id) {
                        t.clienteId = id;
                        store.guardarTarea(t);
                      }, compacto: true)
                    : c == null
                    ? celdaTexto(m('Sin cliente'), suave: true)
                    : Row(
                        children: [
                          Avatar(c.iniciales, colorPaleta(c.color), size: 20, cuadrado: true),
                          const SizedBox(width: 8),
                          Flexible(child: celdaTexto(c.nombre)),
                        ],
                      ),
                if (ancho) celdaTexto(t.periodicidad.etiqueta),
              t.proximo == null
                  ? celdaTexto('', suave: true)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fecha(t.proximo),
                          style: TextStyle(
                            fontSize: 13,
                            color: vencida ? P.rojo : P.texto,
                            fontWeight: vencida ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        Text(
                          [relativo(t.proximo!), ?t.horario].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                        ),
                      ],
                    ),
                if (medio)
                  t.esPlantilla ? const SizedBox() : SelectorTrabajadores(
                        t,
                        () => store.guardarTarea(t),
                        compacto: true,
                        ofrecerSubtrabajos: !industrial,
                      ),
              ],
              t.esPlantilla ? pillEstado(t) : SelectorEstado(t, antesCompletar: industrial ? () => _animarCompletada(t.id) : null),
              if (conVivo) Padding(padding: const EdgeInsets.only(left: 12), child: EnVivoOt(t)),
              // Celda del rayo (automatizaciones), quitada con su columna.
//               if (industrial && medio)
//                 Tooltip(
//                   message: t.automatizaciones.isEmpty
//                       ? 'Sin automatizaciones'
//                       : '${t.automatizaciones.length} automatizaciones · ${t.automatizaciones.where((a) => a.activa).length} activas',
//                   child: t.automatizaciones.any((a) => a.activa)
//                       ? const _Rayo()
//                       : Icon(
//                           t.automatizaciones.isEmpty ? Icons.remove_rounded : Icons.pause_rounded,
//                           size: 16,
//                           color: P.textoSuave,
//                         ),
//                 ),
              if (!industrial && medio && ts.any((x) => store.hijas(x.id).isNotEmpty)) _subtrabajos(t),
              if (industrial && conPdf)
                t.estado == EstadoTrabajo.realizado
                    // Mismo eje que el botón de selección de la cabecera (8 px del borde, la fila tiene 18 - 4).
                    ? Transform.translate(offset: const Offset(-6, 0), child: BotonPdf.orden(t, context, compacto: true))
                    : const SizedBox(),
            ];
          },
        ),
      );
    },
  );
}

// /// Rayo de automatizaciones: amarillo con un brillo suave del mismo color.
// class _Rayo extends StatelessWidget {
//   const _Rayo();
// 
//   @override
//   Widget build(BuildContext context) => Icon(
//     Icons.bolt_rounded,
//     size: 18,
//     color: P.amarillo,
//     shadows: [Shadow(color: P.amarillo.withValues(alpha: .55), blurRadius: 8)],
//   );
// }

/// Órdenes de trabajo [ts] en texto, tal como se ven en la lista: sus columnas en su orden. Cabecera primero.
List<List<String>> otsEnTexto(List<Tarea> ts) {
  String asignado(Tarea t) {
    final nombres = [for (final id in t.trabajadorIds) ?store.trabajador(id)?.nombreCompleto];
    if (nombres.isNotEmpty) return nombres.join(', ');
    return store.grupos.where((g) => g.id == t.grupoId).firstOrNull?.nombre ?? 'Sin asignar';
  }

  final valores = <String, String Function(Tarea)>{
    'Orden de trabajo': (t) => t.nombre,
    'Activo': (t) => store.activo(t.activoId)?.titulo ?? 'Sin activo',
    'Origen': (t) => origenOt(t).$1,
    'Gravedad': (t) => t.tipoMantenimiento?.etiqueta ?? '—',
    'Asignado a': asignado,
    'Fecha y hora': (t) => t.proximo == null ? '' : [fecha(t.proximo), ?t.horario].join(' '),
    'Periodicidad': periodicidadOt,
    'Estado': (t) => t.estadoTexto,
  };
  final cols = enOrdenDelUsuario([
    for (final c in valores.keys)
      if (c == 'Orden de trabajo' || columnasTablas.ve('ordenes', c, porDefecto: c != 'Fecha y hora')) c,
  ], columnasTablas.orden('ordenes'));
  return [
    cols,
    for (final t in ts) [for (final c in cols) valores[c]!(t)],
  ];
}
