import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'gravedad.dart';
import 'planes.dart';
import 'tipo_mantenimiento.dart';

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
                        ? FilledButton(onPressed: () => abrirActivoForm(context), child: const Text('Añadir el primero'))
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

/// Ficha de un activo: su árbol de componentes con el color de cada nodo y, al lado, los mantenimientos
/// pendientes y futuros del nodo elegido.
class ActivoDetalle extends StatefulWidget {
  final String activoId;
  final VoidCallback onVolver;
  const ActivoDetalle({super.key, required this.activoId, required this.onVolver});

  @override
  State<ActivoDetalle> createState() => _ActivoDetalleState();
}

class _ActivoDetalleState extends State<ActivoDetalle> {
  late String elegido = widget.activoId;
  final plegados = <String>{};

  @override
  Widget build(BuildContext context) {
    final a = store.activo(widget.activoId);
    if (a == null) {
      // Se acaba de borrar: volvemos a la lista.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVolver());
      return const SizedBox();
    }
    if (store.activo(elegido) == null) elegido = a.id;
    final g = gravedadDe(a.id);
    final filas = <(Activo, int)>[];
    void anadir(Activo x, int nivel) {
      filas.add((x, nivel));
      if (plegados.contains(x.id)) return;
      for (final h in store.hijosDe(x.id)) {
        anadir(h, nivel + 1);
      }
    }

    anadir(a, 0);
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cabecera(
            lider: IconButton(
              tooltip: 'Volver a Activos',
              onPressed: widget.onVolver,
              icon: Icon(Icons.arrow_back_rounded, size: 20, color: P.textoSuave),
            ),
            titulo: a.titulo.isEmpty ? 'Activo' : a.titulo,
            subtitulo: [
              [a.fabricante, a.modelo].where((x) => x.isNotEmpty).join(' '),
              if (a.horas > 0) horas(a.horas),
              a.division,
            ].where((x) => x.isNotEmpty).join(' · '),
            acciones: [
              Pill(textoEstado(g), colorEstado(g), punto: true),
              const SizedBox(width: 4),
              OutlinedButton(onPressed: () => abrirActivoForm(context, original: a), child: const Text('Editar')),
              BotonPrimario('Nuevo componente', onPressed: () => abrirActivoForm(context, padreId: a.id)),
            ],
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            // Ancho: árbol y mantenimientos uno al lado del otro; estrecho, uno encima del otro.
            child: SegunTamano(
              clave: (box) => box.maxWidth > 760,
              builder: (context, box) {
                final ancho = box.maxWidth > 760;
                return Flex(
                  direction: ancho ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: SeccionTarjeta(
                        alto: double.infinity,
                        titulo: 'Componentes',
                        subtitulo: '${filas.length - 1} ${filas.length == 2 ? 'componente' : 'componentes'}',
                        children: [for (final (x, nivel) in filas) _nodo(x, nivel)],
                      ),
                    ),
                    const SizedBox(width: huecoVista, height: huecoVista),
                    Expanded(flex: 2, child: _Mantenimientos(store.activo(elegido)!)),
                  ],
                );
              },
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
    return Container(
      color: x.id == elegido ? P.hoverFila : null,
      child: FilaLista(
        lider: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20.0 * nivel),
            SizedBox(
              width: 24,
              child: tieneHijos
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: plegado ? 'Desplegar' : 'Plegar',
                      onPressed: () => setState(() => plegado ? plegados.remove(x.id) : plegados.add(x.id)),
                      icon: Icon(
                        plegado ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                        color: P.textoSuave,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Tooltip(message: textoEstado(g), child: puntoTipo(colorEstado(g), tam: 10)),
          ],
        ),
        titulo: x.titulo.isEmpty ? 'Sin nombre' : x.titulo,
        subtitulo: [
          [x.fabricante, x.modelo].where((y) => y.isNotEmpty).join(' '),
          if (x.numeroSerie.isNotEmpty) 'Nº ${x.numeroSerie}',
        ].where((y) => y.isNotEmpty).join(' · '),
        derecha: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Nuevo componente dentro',
              onPressed: () => abrirActivoForm(context, padreId: x.id),
              icon: Icon(Icons.add_rounded, size: 18, color: P.textoSuave),
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: () => abrirActivoForm(context, original: x),
              icon: Icon(Icons.edit_outlined, size: 18, color: P.textoSuave),
            ),
          ],
        ),
        onTap: () => setState(() => elegido = x.id),
      ),
    );
  }
}

/// Mantenimientos del nodo elegido: su plan periódico y las OT (de él y sus componentes), pendientes, del
/// más grave al más leve, y futuras.
class _Mantenimientos extends StatelessWidget {
  final Activo a;
  const _Mantenimientos(this.a);

  @override
  Widget build(BuildContext context) {
    final ots = store.otsDe(a.id).where((t) => t.activa).toList()
      ..sort((x, y) {
        final g = (y.tipoMantenimiento?.index ?? -1).compareTo(x.tipoMantenimiento?.index ?? -1);
        return g != 0 ? g : (x.proximo ?? DateTime(2100)).compareTo(y.proximo ?? DateTime(2100));
      });
    final hoyMismo = hoy();
    final pendientes = ots
        .where((t) => otPendiente(t) && (t.proximo == null || !t.proximo!.isAfter(hoyMismo)))
        .toList();
    final futuros = ots.where((t) => !pendientes.contains(t) && otPendiente(t)).toList();
    Widget fila(Tarea t) => FilaLista(
      lider: puntoTipo(t.tipoMantenimiento?.color ?? P.gris),
      titulo: t.nombre.isEmpty ? 'Sin nombre' : t.nombre,
      subtitulo: [
        store.activo(t.activoId)?.titulo ?? '',
        if (t.proximo != null) '${fecha(t.proximo!)} · ${relativo(t.proximo!)}',
      ].where((x) => x.isNotEmpty).join(' · '),
      onTap: () => abrirTareaForm(context, t),
    );
    final planes = store.planesDe(a.id);
    return SeccionTarjeta(
      alto: double.infinity,
      titulo: 'Mantenimientos',
      subtitulo: a.titulo,
      accion: Enlace(
        'Nueva OT',
        onTap: () => abrirTareaForm(
          context,
          null,
          borrador: Tarea(
            id: store.nuevoId(),
            activoId: a.id,
            tipoMantenimiento: TipoMantenimiento.preventivo,
            proximo: hoy(),
            periodicidad: Periodicidad.unica,
            criticidad: Criticidad.rutinaria,
          ),
        ),
      ),
      children: [
        _titulo('Plan de mantenimiento'),
        for (final p in planes) filaPlan(context, p),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Enlace('Nuevo mantenimiento', onTap: () => abrirPlanForm(context, activoId: a.id)),
          ),
        ),
        if (ots.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text('Sin OT pendientes.', style: TextStyle(fontSize: 13, color: P.textoSuave)),
          ),
        if (pendientes.isNotEmpty) _titulo('Pendientes'),
        for (final t in pendientes) fila(t),
        if (futuros.isNotEmpty) _titulo('Próximos'),
        for (final t in futuros) fila(t),
        if (a.repuestos.isNotEmpty) ...[
          _titulo('Repuestos'),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Text(a.repuestos, style: const TextStyle(fontSize: 13.5)),
          ),
        ],
      ],
    );
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: .6, color: P.textoSuave),
    ),
  );
}

Future<void> abrirActivoForm(BuildContext context, {Activo? original, String? padreId}) =>
    abrirPanel(context, ActivoForm(original: original, padreId: padreId));

/// Alta y edición de un activo o de un componente (con [padreId], dentro de un activo o de otro componente).
class ActivoForm extends StatefulWidget {
  final Activo? original;
  final String? padreId;
  const ActivoForm({super.key, this.original, this.padreId});

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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existe = widget.original != null;
    final padre = store.activo(a.padreId);
    final que = componente ? 'componente' : 'activo';
    return VentanaFormulario(
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
                nav.pop();
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
