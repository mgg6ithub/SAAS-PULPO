import 'dart:convert';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'gravedad.dart';
import 'tipo_mantenimiento.dart';
import 'historicos.dart';
import '../screens/tabla_trabajos.dart';
import '../screens/tarea_detalle.dart';

/// Color del estado de un activo: el de su mantenimiento pendiente más grave (él y sus componentes).
/// Sin nada pendiente, verde: puede funcionar.
TipoMantenimiento? gravedadDe(String activoId) => masGrave(store.otsDe(activoId));
Color colorEstado(TipoMantenimiento? g) => g?.color ?? P.verde;
String textoEstado(TipoMantenimiento? g) => g?.etiqueta ?? 'Al día';

/// Sección «Activos» de iPultec: las máquinas con el color de su estado; al abrir una, su árbol de componentes.
class Activos extends StatefulWidget {
  const Activos({super.key});

  @override
  State<Activos> createState() => _ActivosState();
}

class _ActivosState extends State<Activos> {
  String q = '';
  String? abierto;

  @override
  Widget build(BuildContext context) {
    if (abierto != null) return ActivoDetalle(activoId: abierto!, onVolver: () => setState(() => abierto = null));
    final activos = store.hijosDe(null).where((a) {
      final t = '${a.tag} ${a.nombre} ${a.fabricante} ${a.modelo} ${a.division}'.toLowerCase();
      return t.contains(q.toLowerCase());
    }).toList();
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarraVista(
            izquierda: const [TituloVista('Activos')],
            derecha: [Buscador(hint: 'Buscar activo…', onChanged: (v) => setState(() => q = v))],
            principal: BotonPrimario('Nuevo activo', tecla: 'N', onPressed: () => abrirActivoForm(context)),
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
                : _TablaActivos(activos, (id) => setState(() => abierto = id)),
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
  const _TablaActivos(this.activos, this.onAbrir);

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => (box.maxWidth > 980, box.maxWidth > 600),
    builder: (context, box) {
      final ancho = box.maxWidth > 980;
      // Móvil: el activo y el punto de su estado.
      final medio = box.maxWidth > 600;
      return Tabla(
        columnas: [
          const Col('Activo', flex: 3),
          if (ancho) const Col('Fabricante y modelo', flex: 2),
          if (ancho) const Col('División', flex: 2),
          if (medio) const Col('Componentes', ancho: 120, derecha: true),
          if (ancho) const Col('Horas', ancho: 100, derecha: true),
          if (medio) const Col('Estado', ancho: 190),
        ],
        filas: activos.length,
        celdas: (i) {
          final a = activos[i];
          final g = gravedadDe(a.id);
          return [
            Row(
              children: [
                Tooltip(message: textoEstado(g), child: puntoTipo(colorEstado(g), tam: 10)),
                const SizedBox(width: 10),
                Expanded(child: celdaTexto(a.titulo, negrita: true)),
              ],
            ),
            if (ancho) celdaTexto([a.fabricante, a.modelo].where((x) => x.isNotEmpty).join(' '), suave: true),
            if (ancho) celdaTexto(a.division, suave: true),
            if (medio) celdaTexto('${store.ramaDe(a.id).length - 1}', suave: true),
            if (ancho) celdaTexto(horas(a.horas), suave: true),
            if (medio)
              Align(
                alignment: Alignment.centerLeft,
                child: g == null ? const Pill('Al día', P.verde, punto: true) : PillTipo(g),
              ),
          ];
        },
        onTap: (i) => onAbrir(activos[i].id),
        pie: pieTabla(activos.length, activos.length == 1 ? 'activo' : 'activos'),
      );
    },
  );
}

String horas(double h) => h == 0 ? '—' : '${h % 1 == 0 ? h.toInt() : h} h';

/// Ficha del activo y de cada componente: resumen, datos editables, OT e histórico propio.
class ActivoDetalle extends StatefulWidget {
  final String activoId;
  final VoidCallback onVolver;
  const ActivoDetalle({super.key, required this.activoId, required this.onVolver});

  @override
  State<ActivoDetalle> createState() => _ActivoDetalleState();
}

class _ActivoDetalleState extends State<ActivoDetalle> {
  late String elegido = widget.activoId;
  int pestana = 0;
  bool editando = false;
  String? tareaId;
  final plegados = <String>{};

  void _abrir(String id) => setState(() {
    elegido = id;
    pestana = 0;
    editando = false;
  });

  void _nuevaOt(Activo a) => abrirTareaForm(
    context,
    null,
    borrador: Tarea(
      id: store.nuevoId(),
      activoId: a.id,
      plantilla: false,
      tipoMantenimiento: TipoMantenimiento.preventivo,
      proximo: hoy(),
      periodicidad: Periodicidad.unica,
      criticidad: Criticidad.rutinaria,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = store.activo(elegido) ?? store.activo(widget.activoId);
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
    elegido = a.id;
    final padre = store.activo(a.padreId);
    final ots = store.otsDe(a.id).where((t) => !t.esPlantilla && t.activa).toList();
    final filas = <(Activo, int)>[];
    void anadir(Activo x, int nivel) {
      filas.add((x, nivel));
      if (!plegados.contains(x.id)) {
        for (final h in store.hijosDe(x.id)) {
          anadir(h, nivel + 1);
        }
      }
    }

    for (final h in store.hijosDe(a.id)) {
      anadir(h, 0);
    }
    final g = gravedadDe(a.id);
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cabecera(
            lider: IconButton(
              tooltip: padre == null ? 'Volver a Activos' : 'Volver a ${padre.titulo}',
              onPressed: padre == null ? widget.onVolver : () => _abrir(padre.id),
              icon: Icon(Icons.arrow_back_rounded, size: 20, color: P.textoSuave),
            ),
            titulo: a.titulo.isEmpty ? 'Activo' : a.titulo,
            subtitulo: [
              if (padre != null) 'Componente de ${padre.titulo}',
              a.fabricante,
              a.modelo,
            ].where((x) => x.isNotEmpty).join(' · '),
            acciones: [
              if (pestana == 0 && filas.isNotEmpty)
                BotonPrimario(
                  'Nuevo componente',
                  icono: Icons.add_rounded,
                  onPressed: () => abrirActivoForm(context, padreId: a.id),
                ),
              if (pestana == 1 && !editando)
                BotonPrimario('Editar', icono: Icons.edit_outlined, onPressed: () => setState(() => editando = true)),
              if (pestana == 2)
                BotonPrimario('Nueva orden de trabajo', icono: Icons.add_rounded, onPressed: () => _nuevaOt(a)),
            ],
          ),
          const SizedBox(height: 18),
          PestanasOscuras(
            opciones: const ['Resumen', 'Datos', 'Órdenes de trabajo', 'Histórico'],
            seleccion: pestana,
            onChanged: (i) => setState(() {
              pestana = i;
              editando = false;
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey('$elegido-$pestana'),
                child: switch (pestana) {
                  0 => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Tarjeta(
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Pill(textoEstado(g), colorEstado(g), punto: true),
                            Text('${store.ramaDe(a.id).length - 1} componentes'),
                            Text('${ots.where(otPendiente).length} OT pendientes'),
                            if (a.horas > 0) Text(horas(a.horas)),
                          ],
                        ),
                      ),
                      const SizedBox(height: huecoVista),
                      Expanded(
                        child: filas.isEmpty
                            ? Vacio(
                                icono: Icons.account_tree_outlined,
                                titulo: 'Sin componentes',
                                texto: 'Añade las piezas y los componentes de este activo.',
                                accion: FilledButton(
                                  onPressed: () => abrirActivoForm(context, padreId: a.id),
                                  child: const Text('Añadir componente'),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filas.length,
                                itemBuilder: (_, i) => _nodo(filas[i].$1, filas[i].$2),
                              ),
                      ),
                    ],
                  ),
                  1 => ActivoForm(
                    key: ValueKey(editando ? '${a.id}-editar' : '${a.id}-${jsonEncode(a.toJson())}'),
                    original: a,
                    incrustada: true,
                    soloLectura: !editando,
                    onTerminar: () => setState(() => editando = false),
                  ),
                  2 =>
                    ots.isEmpty
                        ? const Vacio(
                            icono: Icons.assignment_outlined,
                            titulo: 'Sin órdenes de trabajo',
                            texto: 'Las órdenes de este activo y sus componentes aparecerán aquí.',
                          )
                        : TablaTrabajos(
                            ots,
                            conCliente: false,
                            nombre: 'orden de trabajo',
                            onAbrir: (id) => setState(() => tareaId = id),
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

  Widget _nodo(Activo x, int nivel) {
    final g = gravedadDe(x.id);
    final tieneHijos = store.hijosDe(x.id).isNotEmpty;
    final plegado = plegados.contains(x.id);
    return FilaLista(
      lider: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 16.0 * nivel.clamp(0, 4)),
          if (tieneHijos)
            IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: plegado ? 'Desplegar componentes' : 'Plegar componentes',
              onPressed: () => setState(() => plegado ? plegados.remove(x.id) : plegados.add(x.id)),
              icon: Icon(plegado ? Icons.chevron_right_rounded : Icons.expand_more_rounded),
            ),
          Tooltip(message: textoEstado(g), child: puntoTipo(colorEstado(g), tam: 10)),
        ],
      ),
      titulo: x.titulo.isEmpty ? 'Sin nombre' : x.titulo,
      subtitulo: [
        x.fabricante,
        x.modelo,
        if (x.numeroSerie.isNotEmpty) 'Nº ${x.numeroSerie}',
      ].where((s) => s.isNotEmpty).join(' · '),
      onTap: () => _abrir(x.id),
    );
  }
}

Future<void> abrirActivoForm(BuildContext context, {Activo? original, String? padreId}) =>
    abrirPanel(context, ActivoForm(original: original, padreId: padreId));

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
  late final Activo a = widget.original?.copia() ?? Activo(id: store.nuevoId(), padreId: widget.padreId);
  late final tag = TextEditingController(text: a.tag)..addListener(() => setState(() {}));
  late final nombre = TextEditingController(text: a.nombre)..addListener(() => setState(() {}));
  late final fabricante = TextEditingController(text: a.fabricante);
  late final modelo = TextEditingController(text: a.modelo);
  late final serie = TextEditingController(text: a.numeroSerie);
  late final division = TextEditingController(text: a.division);
  late final horasC = TextEditingController(text: a.horas == 0 ? '' : '${a.horas}');
  late final repuestos = TextEditingController(text: a.repuestos);
  late final notas = TextEditingController(text: a.notas);
  bool intentoGuardar = false;

  @override
  void dispose() {
    for (final c in [tag, nombre, fabricante, modelo, serie, division, horasC, repuestos, notas]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get componente => a.padreId != null;
  String? get error =>
      intentoGuardar && tag.text.trim().isEmpty && nombre.text.trim().isEmpty ? 'Ponle un tag o un nombre' : null;

  void guardar() {
    setState(() => intentoGuardar = true);
    if (error != null) return;
    a
      ..tag = tag.text.trim()
      ..nombre = nombre.text.trim()
      ..fabricante = fabricante.text.trim()
      ..modelo = modelo.text.trim()
      ..numeroSerie = serie.text.trim()
      ..division = division.text.trim()
      ..horas = double.tryParse(horasC.text.trim().replaceAll(',', '.')) ?? 0
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
      tituloDesplazado: [tag.text, nombre.text].where((x) => x.isNotEmpty).join(' · '),
      onGuardar: guardar,
      avisos: [if (error != null) ('Te falta el tag o el nombre', () {})],
      onBorrar: !existe
          ? null
          : () async {
              final nav = Navigator.of(context);
              final n = store.ramaDe(a.id).length - 1;
              final con = n == 0 ? '' : ' y sus $n ${n == 1 ? 'componente' : 'componentes'}';
              if (await confirmar(context, '¿Eliminar ${a.titulo}$con? Sus OT se quedan, sin activo.')) {
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
          descripcion: componente ? 'Qué pieza de la máquina es.' : 'Qué máquina es y cómo se identifica.',
          [
            dos(
              campo('Tag', tag, hint: componente ? 'CAM-01-MOT' : 'CAM-01', error: error, obligatorio: true),
              campo('Nombre', nombre, hint: componente ? 'Motor' : 'Camión cisterna', obligatorio: true),
            ),
          ],
        ),
        Bloque('Ficha técnica', descripcion: 'Los datos de la placa.', [
          dos(campo('Fabricante', fabricante), campo('Modelo', modelo)),
          dos(campo('Número de serie', serie), campo('Horas de uso', horasC, hint: '0')),
          if (!componente) campo('División o actividad', division, hint: 'Limpieza de tanques, transporte…'),
        ]),
        Bloque('Repuestos', descripcion: 'Piezas y consumibles que usa.', [campo('Repuestos', repuestos, lineas: 3)]),
        Bloque('Notas', [campo('Notas internas', notas, lineas: 3)]),
      ],
    );
  }
}
