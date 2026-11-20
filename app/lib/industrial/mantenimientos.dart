import 'package:flutter/material.dart';

import '../forms.dart';
import '../informes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'activos.dart';
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
            if (ancho) const Col('Tipo', ancho: 210),
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
              if (medio) Align(alignment: Alignment.centerLeft, child: Pill(x.estado.etiqueta, x.estado.color)),
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
  Future<void> crearOt() async {
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
    );
    nav.pop();
    await abrirTareaForm(nav.context, null, borrador: ot);
    if (store.tareas.any((t) => t.id == ot.id)) {
      store.guardarIncidencia(
        x.copia()
          ..trabajoId = ot.id
          ..estado = EstadoIncidencia.conOt,
      );
    }
  }

  /// Cerrar sin hacer nada: queda en el histórico como desestimada.
  void desestimar() {
    x.estado = EstadoIncidencia.desestimada;
    if (_guardar()) Navigator.pop(context);
  }

  Future<void> _informe() async {
    setState(() => descargando = true);
    try {
      await descargarInformeIncidencia(x);
    } catch (e) {
      debugPrint('Pultec: no se pudo crear el PDF de la incidencia: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text('No se pudo crear el PDF')),
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
      etiqueta: dondeEs(x.activoId).isEmpty ? 'Incidencias' : dondeEs(x.activoId),
      titulo: existe ? 'Incidencia' : 'Nueva incidencia',
      subtitulo: existe ? 'Comunicada por ${tecnico?.nombre ?? 'la oficina'} el ${fecha(x.creada)}' : null,
      tituloDesplazado: descripcion.text,
      extra: existe ? Pill(estado.etiqueta, estado.color, punto: true) : null,
      bajoBotones: BotonMenu<Gravedad>(
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
            ],
          ),
        ),
      ),
      onGuardar: () {
        if (_guardar()) Navigator.pop(context);
      },
      avisos: [if (error != null) ('Te falta qué pasa', () {})],
      onBorrar: !existe
          ? null
          : () async {
              store.deshacible('Has borrado una incidencia', () => store.borrarIncidencia(x.id));
              Navigator.of(context).pop();
            },
      campos: [
        Bloque('Incidencia', primero: true, descripcion: 'Qué máquina o pieza falla y qué le pasa.', [
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
          if (origen != null)
            FilaLista(
              lider: puntoTipo(origen.tipoMantenimiento?.color ?? P.gris),
              titulo: origen.nombre,
              subtitulo: 'Orden en la que se detectó',
              onTap: () => abrirTareaForm(context, origen),
            ),
        ]),
        if (x.fotos.isNotEmpty)
          Bloque('Fotos de la incidencia', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in x.fotos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(P.radio),
                    child: FotoGuardada(f, width: 160, height: 120),
                  ),
              ],
            ),
          ]),
        Bloque(
          'Mantenimiento vinculado',
          descripcion: 'Al completarse la incidencia, este mantenimiento vuelve a contar desde cero.',
          [
            conMargen(
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: planes.any((p) => p.id == x.planId) ? x.planId : null,
                decoration: const InputDecoration(labelText: 'Mantenimiento'),
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
          ],
        ),
        Bloque(
          'Acciones',
          descripcion: switch (estado) {
            EstadoIncidencia.abierta => 'Crea una OT para resolverla o desestímala si no hace falta hacer nada.',
            EstadoIncidencia.conOt => 'Se completa sola al cerrar su orden de trabajo.',
            EstadoIncidencia.completada => 'Resuelta con su orden de trabajo.',
            EstadoIncidencia.desestimada =>
              'Desestimada${x.cerradaEl == null ? '' : ' el ${fecha(x.cerradaEl!)}'}: no hizo falta intervenir.',
          },
          [
            if (estado == EstadoIncidencia.abierta)
              conMargen(
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BotonPrimario('Crear OT', icono: Icons.assignment_outlined, conIcono: true, onPressed: crearOt),
                    BotonAccion('Desestimar', onPressed: desestimar, tooltip: 'Cerrarla sin hacer nada'),
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
            if (existe)
              conMargen(
                Align(
                  alignment: Alignment.centerLeft,
                  child: BotonAccion(
                    descargando ? 'Preparando…' : 'Descargar PDF',
                    icono: Icons.download_rounded,
                    tooltip: 'PDF con la incidencia, sus fotos y su resolución',
                    onPressed: descargando ? () {} : _informe,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
