import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tabla_trabajos.dart';
import 'tarea_card.dart';
import '../marca.dart';

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
  bool lista = true;

  Future<void> _editarEtiqueta(EtiquetaTrabajo? e) => showDialog(context: context, builder: (_) => _EtiquetaDialogo(e));

  @override
  Widget build(BuildContext context) {
    final nTrabajos = store.tareas.length - store.plantillas.length;
    final filtradas =
        store.tareas.where((t) {
          if (pestana == 0 && t.esPlantilla) return false;
          if (pestana == 1 && !t.esPlantilla) return false;
          if (tipo != null && t.tipo != tipo) return false;
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
                  TituloVista(m('Trabajos')),
                  Pestanas(
                    opciones: ['Todos · $nTrabajos', 'Plantillas · ${store.plantillas.length}'],
                    seleccion: pestana,
                    onChanged: (i) => setState(() => pestana = i),
                  ),
                ],
                derecha: [
                  Buscador(
                    hint: industrial ? 'Buscar orden de trabajo…' : 'Buscar trabajo…',
                    width: 280,
                    onChanged: (v) => setState(() => q = v),
                  ),
                  SelectorVista(lista: lista, onChanged: (v) => setState(() => lista = v)),
                ],
                principal: BotonPrimario(
                  pestana == 1 ? 'Nueva plantilla' : m('Nuevo trabajo'),
                  tecla: 'N',
                  onPressed: () => abrirTareaForm(context, null, plantilla: pestana == 1),
                ),
              ),
              const SizedBox(height: huecoVista),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
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
              ),
              if (pestana == 1) ...[
                const SizedBox(height: 12),
                Consejo(
                  m('Las plantillas son trabajos que dejas pre-creados con ciertos campos ya rellenos. '
                  'Al crear un trabajo, eliges una plantilla y se rellena casi todo.'),
                ),
              ],
              const SizedBox(height: huecoVista),
              Expanded(
                child: filtradas.isEmpty
                    ? Vacio(
                        icono: Marca.iconoTrabajo,
                        titulo: store.tareas.isEmpty ? m('Aún no hay trabajos') : null,
                        texto: pestana == 0 && nTrabajos == 0
                            ? m('Crea tu primer trabajo, desde cero o a partir de una plantilla.')
                            : m('No hay trabajos con estos filtros'),
                        // Sin búsqueda ni filtro de tipo: botón para crear (el primero, si aún no hay).
                        accion: q.isEmpty && tipo == null
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
                    ? TablaTrabajos(filtradas, onAbrir: widget.onAbrir)
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
  const _ChipTipo(this.nombre, this.color, this.sel, this.onTap);

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
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
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
                      store.borrarEtiqueta(widget.original!.id);
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
