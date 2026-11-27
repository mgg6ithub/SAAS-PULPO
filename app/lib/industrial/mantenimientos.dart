import 'dart:async';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../informes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'activos.dart';
import 'checklist.dart';
import 'gravedad.dart';
import 'incidencia.dart';
import 'tipo_mantenimiento.dart';

/// Activo raíz (la máquina) del activo o componente.
Activo? raizDe(String? id) {
  var a = store.activo(id);
  while (a?.padreId != null && store.activo(a!.padreId) != null) {
    a = store.activo(a.padreId);
  }
  return a;
}

/// «CAM-01 · Camión › Motor»: la máquina y, si es un componente, cuál.
String dondeEs(String? activoId) {
  final a = store.activo(activoId);
  if (a == null) return '';
  final r = raizDe(activoId)!;
  return r.id == a.id ? a.titulo : '${r.titulo} › ${a.nombre.isEmpty ? a.tag : a.nombre}';
}

/// Pestaña «Mantenimientos» de Activos: OT pendientes o incidencias, de todos los activos o de uno,
/// con el color de su gravedad. [incidencias] elige el filtro y [activoId] el activo (null = todos).
class Mantenimientos extends StatelessWidget {
  final bool incidencias;
  final String? activoId;
  final String q;
  const Mantenimientos({super.key, required this.incidencias, this.activoId, this.q = ''});

  bool _deActivo(String? id) => activoId == null ? store.activo(id) != null : store.ramaDe(activoId!).contains(id);
  bool _busca(String texto) => texto.toLowerCase().contains(q.toLowerCase());

  @override
  Widget build(BuildContext context) => incidencias ? _incidencias(context) : _pendientes(context);

  Widget _pendientes(BuildContext context) {
    final ots =
        [...store.tareas, ...store.subtareas]
            .where((t) => otPendiente(t) && _deActivo(t.activoId) && _busca('${t.nombre} ${dondeEs(t.activoId)}'))
            .toList()
          ..sort((x, y) {
            final g = y.tipoMantenimiento!.index.compareTo(x.tipoMantenimiento!.index);
            return g != 0 ? g : (x.proximo ?? DateTime(2100)).compareTo(y.proximo ?? DateTime(2100));
          });
    if (ots.isEmpty) {
      return const Vacio(
        icono: Icons.check_circle_outline_rounded,
        titulo: 'Nada pendiente',
        texto: 'Todas las OT de estos activos están hechas.',
      );
    }
    return SegunTamano(
      clave: (box) => (box.maxWidth > 980, box.maxWidth > 600),
      builder: (context, box) {
        final ancho = box.maxWidth > 980, medio = box.maxWidth > 600;
        return Tabla(
          columnas: [
            const Col('OT', flex: 3),
            if (medio) const Col('Activo', flex: 3),
            if (ancho) const Col('Técnico', flex: 2),
            if (medio) const Col('Fecha', ancho: 150),
            if (ancho) const Col('Gravedad', ancho: 210),
          ],
          filas: ots.length,
          celdas: (i) {
            final t = ots[i];
            final tecnicos = t.trabajadorIds.map(store.trabajador).whereType<Trabajador>();
            return [
              Row(
                children: [
                  Tooltip(
                    message: t.tipoMantenimiento!.etiqueta,
                    child: puntoTipo(t.tipoMantenimiento!.color, tam: 10),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: celdaTexto(t.nombre.isEmpty ? 'Sin nombre' : t.nombre, negrita: true)),
                ],
              ),
              if (medio) celdaTexto(dondeEs(t.activoId), suave: true),
              if (ancho)
                celdaTexto(tecnicos.isEmpty ? 'Sin asignar' : tecnicos.map((w) => w.nombre).join(', '), suave: true),
              if (medio) celdaTexto(t.proximo == null ? '—' : relativo(t.proximo!), suave: true),
              if (ancho) Align(alignment: Alignment.centerLeft, child: PillTipo(t.tipoMantenimiento!)),
            ];
          },
          onTap: (i) => abrirTareaForm(context, ots[i]),
          pie: pieTabla(ots.length, ots.length == 1 ? 'OT pendiente' : 'OT pendientes'),
        );
      },
    );
  }

  Widget _incidencias(BuildContext context) {
    final lista =
        store.incidencias
            .where((x) => _deActivo(x.activoId) && _busca('${x.descripcion} ${dondeEs(x.activoId)}'))
            .toList()
          ..sort((x, y) {
            // Las abiertas primero; dentro, las más graves y las más nuevas.
            final e = x.estado.index.compareTo(y.estado.index);
            if (e != 0) return e;
            final g = y.gravedad.index.compareTo(x.gravedad.index);
            return g != 0 ? g : y.creada.compareTo(x.creada);
          });
    if (lista.isEmpty) {
      return Vacio(
        icono: Icons.report_outlined,
        titulo: 'Sin incidencias',
        texto: 'Cuando una máquina falle, apúntalo aquí con su gravedad y sácale una OT.',
        accion: store.activos.isEmpty
            ? null
            : FilledButton(
                onPressed: () => abrirIncidenciaForm(context, activoId: activoId),
                child: const Text('Nueva incidencia'),
              ),
      );
    }
    return SegunTamano(
      clave: (box) => (box.maxWidth > 980, box.maxWidth > 600),
      builder: (context, box) {
        final ancho = box.maxWidth > 980, medio = box.maxWidth > 600;
        return Tabla(
          columnas: [
            const Col('Incidencia', flex: 3),
            if (medio) const Col('Activo', flex: 3),
            if (ancho) const Col('Gravedad', ancho: 130),
            if (ancho) const Col('Fecha', ancho: 150),
            if (medio) const Col('Estado', ancho: 130),
          ],
          filas: lista.length,
          celdas: (i) {
            final x = lista[i];
            return [
              Row(
                children: [
                  Tooltip(message: x.gravedad.etiqueta, child: puntoTipo(x.gravedad.color, tam: 10)),
                  const SizedBox(width: 10),
                  Expanded(child: celdaTexto(x.descripcion.isEmpty ? 'Sin descripción' : x.descripcion, negrita: true)),
                ],
              ),
              if (medio) celdaTexto(dondeEs(x.activoId), suave: true),
              if (ancho)
                Align(alignment: Alignment.centerLeft, child: Pill(x.gravedad.etiqueta, x.gravedad.color, punto: true)),
              if (ancho) celdaTexto(relativo(DateUtils.dateOnly(x.creada)), suave: true),
              if (medio) Align(alignment: Alignment.centerLeft, child: Pill(x.estado.etiqueta, x.estado.color, icono: x.estado.icono)),
            ];
          },
          onTap: (i) => abrirIncidenciaForm(context, original: lista[i]),
          pie: pieTabla(lista.length, lista.length == 1 ? 'incidencia' : 'incidencias'),
        );
      },
    );
  }
}

/// Filtro de activo de la pestaña de mantenimientos: todos o una máquina.
class FiltroActivo extends StatelessWidget {
  final String? valor;
  final ValueChanged<String?> onChanged;
  const FiltroActivo(this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Filtrar por activo',
    onSelected: (v) => onChanged(v.isEmpty ? null : v),
    itemBuilder: (_) => [
      const PopupMenuItem(value: '', child: Text('Todos los activos')),
      for (final a in store.hijosDe(null))
        PopupMenuItem(
          value: a.id,
          child: Row(children: [puntoTipo(colorEstado(gravedadDe(a.id))), const SizedBox(width: 10), Text(a.titulo)]),
        ),
    ],
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: valor == null ? Colors.transparent : P.morado.withValues(alpha: .4)),
        color: valor == null ? Colors.transparent : P.moradoSuave,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(valor == null ? Icons.add_rounded : Icons.filter_list_rounded, size: 16, color: P.morado),
          const SizedBox(width: 4),
          Text(
            store.activo(valor)?.titulo ?? 'Activo',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.morado),
          ),
        ],
      ),
    ),
  );
}

Future<void> abrirIncidenciaForm(BuildContext context, {Incidencia? original, String? activoId}) =>
    abrirPanel(context, IncidenciaForm(original: original, activoId: activoId));

/// Alta y edición de una incidencia: qué activo o componente, qué pasa y lo grave que es. Desde aquí sale
/// la OT que la arregla.
class IncidenciaForm extends StatefulWidget {
  final Incidencia? original;
  final String? activoId;
  const IncidenciaForm({super.key, this.original, this.activoId});

  @override
  State<IncidenciaForm> createState() => _IncidenciaFormState();
}

class _IncidenciaFormState extends State<IncidenciaForm> {
  late final Incidencia x =
      widget.original?.copia() ??
      Incidencia(id: store.nuevoId(), activoId: widget.activoId ?? store.hijosDe(null).firstOrNull?.id ?? '');
  late final descripcion = TextEditingController(text: x.descripcion)..addListener(() => setState(() {}));
  bool intentoGuardar = false, descargando = false;

  String? get error => intentoGuardar && descripcion.text.trim().isEmpty ? 'Cuenta qué pasa' : null;

  bool _guardar() {
    setState(() => intentoGuardar = true);
    if (error != null || store.activo(x.activoId) == null) return false;
    x.descripcion = descripcion.text.trim();
    store.guardarIncidencia(x);
    return true;
  }

  /// Guarda la incidencia y abre su OT ya rellena: lo comunicado va a la descripción (no al título) y se
  /// pueden poner repuestos y procedimiento. Al guardarla, la incidencia pasa a «Con OT».
  /// [interrumpida]: la OT que se acaba de interrumpir. La nueva sigue su mantenimiento (cuenta como hecho al
  /// cerrarla y no se genera otra preventiva mientras tanto) y su checklist, con lo ya marcado.
  Future<void> crearOt({Tarea? interrumpida}) async {
    // Una sola OT por incidencia: si ya tiene una abierta, no se crea otra.
    final yaTiene = store.tarea(x.trabajoId);
    if (yaTiene != null && yaTiene.estado.abierta) return;
    if (!_guardar()) return;
    final nav = Navigator.of(context);
    final a = store.activo(x.activoId);
    final ot = Tarea(
      id: store.nuevoId(),
      nombre: 'Reparar ${a == null ? 'activo' : a.nombre.isEmpty ? a.tag : a.nombre}',
      descripcion: x.descripcion,
      activoId: x.activoId,
      plantilla: false,
      tipoMantenimiento: x.gravedad.tipo,
      proximo: hoy(),
      periodicidad: Periodicidad.unica,
      criticidad: Criticidad.rutinaria,
      // Por defecto, quien se encarga de la orden en la que se detectó; si no, quien la comunicó.
      trabajadorIds: _tecnicosPorDefecto(),
      grupoId: store.tarea(x.origenTrabajoId)?.grupoId,
      planId: interrumpida?.planId,
    );
    // Se crea ya y se enlaza a la incidencia (pasa a «Con OT» al momento, también en la lista); luego se abre
    // para ajustarla. Así no se puede crear dos veces.
    store.guardarTarea(ot);
    final pasos = interrumpida == null
        ? const <PasoChecklist>[]
        : [for (final p in checklistDe(interrumpida)) PasoChecklist.fromJson(p.toJson())];
    if (pasos.isNotEmpty) {
      // La checklist va por su función de la base: cuando ya esté guardada la OT.
      unawaited(() async {
        await store.nube?.guardado;
        await store.marcarChecklist(ot, pasos);
      }().catchError((Object e) => debugPrint('Pultec: no se pudo copiar la checklist: $e')));
    }
    store.guardarIncidencia(
      x
        ..trabajoId = ot.id
        ..estado = EstadoIncidencia.conOt,
    );
    nav.pop();
    await abrirTareaForm(nav.context, ot);
  }

  /// La OT en la que se avisó, si sigue abierta: la oficina decide si se sigue en ella o se interrumpe.
  Tarea? get origen {
    final o = store.tarea(x.origenTrabajoId);
    return o != null && o.estado.abierta ? o : null;
  }

  /// Se resuelve en la misma OT: la incidencia se une a ella y el técnico la reanuda.
  ///
  /// Si esa OT ya resuelve otra incidencia (la que la creó), no quedan dos: la nueva se une a aquella, que sube de
  /// nivel (gravedad y tipo de la OT, si la nueva es más grave), toma la descripción nueva y guarda la de antes
  /// debajo, con las fotos de las dos.
  void seguirEnLaOt() {
    final o = origen;
    if (o == null || !_guardar()) return;
    final previa = store.incidenciaDeOt(o.id);
    if (previa == null || previa.id == x.id) {
      store.guardarIncidencia(
        x
          ..trabajoId = o.id
          ..estado = EstadoIncidencia.conOt,
      );
    } else {
      final grave = x.gravedad.index > previa.gravedad.index ? x.gravedad : previa.gravedad;
      store.guardarIncidencia(
        previa.copia()
          ..descripcion = [x.descripcion, if (previa.descripcion.isNotEmpty) 'Antes: ${previa.descripcion}'].join('\n\n')
          ..gravedad = grave
          ..fotos = [...previa.fotos, ...x.fotos]
      );
      if (o.tipoMantenimiento == null || grave.tipo.index > o.tipoMantenimiento!.index) {
        store.guardarTarea(o..tipoMantenimiento = grave.tipo);
      }
      store.borrarIncidencia(x.id);
    }
    Navigator.pop(context);
  }

  /// Grave: la OT en la que se avisó se cierra como interrumpida y sigue en una OT correctiva nueva.
  Future<void> interrumpirYCrearOt() async {
    final o = origen;
    if (o == null || !_guardar()) return;
    if (!await confirmar(
      context,
      '¿Interrumpir «${o.nombre}» y crear una OT correctiva?',
      accion: 'Interrumpir y crear OT',
      nota: 'La orden queda cerrada como interrumpida y el trabajo sigue en la nueva.',
    )) {
      return;
    }
    store.cambiarEstado([o], EstadoTrabajo.interrumpida);
    await crearOt(interrumpida: o);
  }

  List<String> _tecnicosPorDefecto() {
    final deOrigen = [...?store.tarea(x.origenTrabajoId)?.trabajadorIds];
    if (deOrigen.isNotEmpty) return deOrigen;
    return [if (x.tecnicoId != null && store.trabajador(x.tecnicoId!) != null) x.tecnicoId!];
  }

  /// Con OT: la cancela (queda en el histórico) y desestima la incidencia, sin ir a la orden.
  Future<void> cancelarOtYDesestimar() async {
    final ot = store.tarea(x.trabajoId);
    if (!await confirmar(
      context,
      '¿Cancelar su orden de trabajo y desestimar la incidencia?',
      accion: 'Cancelar OT y desestimar',
      nota: 'La orden queda en el histórico como cancelada.',
    )) {
      return;
    }
    if (ot != null && ot.estado.abierta) store.cambiarEstado([ot], EstadoTrabajo.noRealizado);
    x.estado = EstadoIncidencia.desestimada;
    if (_guardar() && mounted) Navigator.pop(context);
  }

  /// Cerrar sin hacer nada: queda en el histórico como desestimada.
  void desestimar() {
    x.estado = EstadoIncidencia.desestimada;
    if (_guardar()) Navigator.pop(context);
  }

  Future<void> _informe() async {
    setState(() => descargando = true);
    try {
      await descargarInformeIncidencia(context, x);
    } catch (e) {
      debugPrint('Pultec: no se pudo crear el PDF de la incidencia: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: const Duration(seconds: 6), behavior: SnackBarBehavior.floating, width: 360, content: Text('No se pudo crear el PDF')),
        );
      }
    }
    if (mounted) setState(() => descargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final existe = widget.original != null;
    final estado = store.estadoIncidencia(x);
    final ot = store.tarea(x.trabajoId);
    final origen = store.tarea(x.origenTrabajoId);
    final tecnico = x.tecnicoId == null ? null : store.trabajador(x.tecnicoId!);
    // Mantenimientos de la máquina (y sus componentes) a los que se puede vincular.
    final raiz = raizDe(x.activoId);
    final rama = raiz == null ? const <String>{} : store.ramaDe(raiz.id).toSet();
    final planes = store.planes.where((p) => rama.contains(p.activoId)).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return VentanaFormulario(
      titulo: existe ? 'Incidencia' : 'Nueva incidencia',
      colorTitulo: P.rojo,
      // Quién la comunicó (con su avatar), el día y la hora.
      bajoTitulo: existe
          // Una sola línea que se recorta (en el móvil el título se queda estrecho junto a la gravedad).
          ? Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Comunicada por '),
                  if (tecnico != null)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Avatar(inicialesDe(tecnico.nombreCompleto), colorPaleta(tecnico.color), size: 18),
                      ),
                    ),
                  TextSpan(
                    text: '${tecnico?.nombre ?? 'la oficina'} el ${fecha(x.creada)} a las '
                        '${hhmm(x.creada.hour * 60 + x.creada.minute)}',
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: P.textoSuave, fontSize: 13),
            )
          : null,
      tituloDesplazado: descripcion.text,
      // Estado y gravedad, en la misma línea.
      bajoBotones: Row(mainAxisSize: MainAxisSize.min, children: [
        if (existe) ...[Pill(estado.etiqueta, estado.color, icono: estado.icono), const SizedBox(width: 12)],
        BotonMenu<Gravedad>(
        tooltip: 'Gravedad',
        seleccionado: x.gravedad,
        onSelected: (g) => setState(() => x.gravedad = g),
        opciones: [
          for (final g in const [Gravedad.media, Gravedad.grave])
            (g, Row(children: [puntoTipo(g.color), const SizedBox(width: 10), Text(g.etiqueta)])),
        ],
        child: SizedBox(
          height: 22,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              puntoTipo(x.gravedad.color),
              const SizedBox(width: 8),
              Text('Gravedad', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
              const SizedBox(width: 6),
              Text(x.gravedad.etiqueta, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              Icon(Icons.unfold_more_rounded, size: 16, color: P.textoSuave),
            ],
          ),
        ),
      ),
      ]),
      onGuardar: () {
        if (_guardar()) Navigator.pop(context);
      },
      avisos: [if (error != null) ('Te falta qué pasa', () {})],
      // Una incidencia no se borra (para cerrarla sin hacer nada está «Desestimar» y queda en el histórico); con
      // OT, abajo a la izquierda, cancelar su OT y desestimarla.
      textoBorrar: 'Cancelar OT y desestimar',
      onBorrar: existe && estado == EstadoIncidencia.conOt ? cancelarOtYDesestimar : null,
      campos: [
        Bloque('Incidencia', primero: true, [
          conMargen(
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: store.activo(x.activoId)?.id,
              decoration: const InputDecoration(labelText: 'Activo o componente'),
              items: [
                for (final (a, nivel) in arbolActivos())
                  DropdownMenuItem(
                    value: a.id,
                    child: Padding(
                      padding: EdgeInsets.only(left: 16.0 * nivel),
                      child: Text(a.titulo),
                    ),
                  ),
              ],
              onChanged: (id) => setState(() {
                x.activoId = id!;
                // El mantenimiento vinculado tiene que ser de la misma máquina.
                final r = raizDe(id);
                if (r == null || !store.ramaDe(r.id).contains(store.planes.where((p) => p.id == x.planId).firstOrNull?.activoId)) {
                  x.planId = null;
                }
              }),
            ),
          ),
          campo(
            'Qué pasa',
            descripcion,
            hint: 'Pierde aceite por la junta',
            lineas: 3,
            error: error,
            obligatorio: true,
          ),
          // Al completarse la incidencia, este mantenimiento vuelve a contar desde cero.
          conMargen(
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: planes.any((p) => p.id == x.planId) ? x.planId : null,
              decoration: const InputDecoration(labelText: 'Mantenimiento vinculado'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin vincular')),
                for (final p in planes)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      p.activoId == raiz?.id ? p.nombre : '${p.nombre}, ${store.activo(p.activoId)?.nombre ?? ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => x.planId = id),
            ),
          ),
          if (origen != null)
            FilaLista(
              lider: puntoTipo(origen.tipoMantenimiento?.color ?? P.gris),
              titulo: origen.nombre,
              subtitulo: 'Orden en la que se detectó',
              // Solo para verla: la orden en la que se detectó no se cambia desde la incidencia.
              onTap: () => abrirTareaForm(context, origen, soloLectura: true),
            ),
        ]),
        if (x.fotos.isNotEmpty)
          Bloque('Fotos de la incidencia', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Al pulsar, a pantalla completa (con flechas si hay varias).
                for (final (n, f) in x.fotos.indexed)
                  MouseRegion(
                    cursor: SystemMouseCursors.zoomIn,
                    child: GestureDetector(
                      onTap: () => verFotos(context, x.fotos, n),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(P.radio),
                        child: FotoGuardada(f, width: 160, height: 120),
                      ),
                    ),
                  ),
              ],
            ),
          ]),
        Bloque(
          'Acciones',
          // El PDF, abajo a la izquierda (bajo el título).
          pie: existe
              ? BotonAccion(
                  descargando ? 'Preparando…' : 'Descargar PDF',
                  icono: Icons.download_rounded,
                  tooltip: 'PDF con la incidencia, sus fotos y su resolución',
                  onPressed: descargando ? () {} : _informe,
                )
              : null,
          descripcion: estado == EstadoIncidencia.desestimada
              ? 'Desestimada${x.cerradaEl == null ? '' : ' el ${fecha(x.cerradaEl!)}'}.'
              : null,
          [
            if (estado == EstadoIncidencia.abierta && !(ot?.estado.abierta ?? false))
              conMargen(
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  // Avisada desde una OT aún abierta: seguir en ella o, si es grave, interrumpirla y seguir en otra.
                  children: origen == null
                      ? [
                          BotonPrimario('Crear OT', icono: Icons.assignment_outlined, conIcono: true, onPressed: crearOt),
                          BotonAccion('Desestimar', onPressed: desestimar, tooltip: 'Cerrarla sin hacer nada'),
                        ]
                      : [
                          if (x.gravedad == Gravedad.grave) ...[
                            BotonPrimario('Interrumpir y crear OT', onPressed: interrumpirYCrearOt),
                            BotonAccion('Seguir en la misma OT', tooltip: 'Se resuelve dentro de su OT: el técnico la reanuda', onPressed: seguirEnLaOt),
                          ] else ...[
                            BotonPrimario('Seguir en la misma OT', onPressed: seguirEnLaOt),
                            BotonAccion('Interrumpir y crear OT', tooltip: 'Cierra su OT como interrumpida y crea una correctiva', onPressed: interrumpirYCrearOt),
                          ],
                          BotonAccion('Desestimar', onPressed: desestimar, tooltip: 'Cerrarla sin hacer nada; el técnico reanuda su OT'),
                        ],
                ),
              ),
            if (ot != null)
              FilaLista(
                lider: puntoTipo(ot.tipoMantenimiento?.color ?? P.gris),
                titulo: ot.nombre,
                subtitulo: [
                  ot.estado.etiqueta,
                  if (ot.estado == EstadoTrabajo.realizado && ot.ultimo != null)
                    fecha(ot.ultimo!)
                  else if (ot.proximo != null)
                    fecha(ot.proximo!),
                ].join(', '),
                onTap: () => abrirTareaForm(context, ot),
              ),
            if (estado == EstadoIncidencia.desestimada)
              Align(
                alignment: Alignment.centerLeft,
                child: Enlace('Reabrir', onTap: () => setState(() => x.estado = EstadoIncidencia.abierta)),
              ),
          ],
        ),
      ],
    );
  }
}
