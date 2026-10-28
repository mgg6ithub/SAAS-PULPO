import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tarea_card.dart';

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
  bool seleccionando = false;
  final seleccion = <String>{};

  void salirSeleccion() => setState(() {
    seleccionando = false;
    seleccion.clear();
  });

  Future<void> eliminarSeleccion() async {
    final n = seleccion.length;
    if (!await confirmar(context, '¿Eliminar $n ${n == 1 ? 'trabajo' : 'trabajos'}?')) return;
    for (final id in seleccion) {
      store.borrarTarea(id);
    }
    salirSeleccion();
  }

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
                  const TituloVista('Trabajos'),
                  Pestanas(
                    opciones: ['Todos · $nTrabajos', 'Plantillas · ${store.plantillas.length}'],
                    seleccion: pestana,
                    onChanged: (i) => setState(() => pestana = i),
                  ),
                ],
                derecha: [
                  Buscador(
                    hint: 'Buscar trabajo, equipo o cliente…',
                    width: 280,
                    onChanged: (v) => setState(() => q = v),
                  ),
                  SelectorVista(
                    lista: lista,
                    onChanged: (v) => setState(() {
                      lista = v;
                      seleccionando = false;
                      seleccion.clear();
                    }),
                  ),
                ],
                principal: BotonPrimario(
                  pestana == 1 ? 'Nueva plantilla' : 'Nuevo trabajo',
                  tecla: 'N',
                  onPressed: () => abrirTareaForm(context, null, plantilla: pestana == 1),
                ),
              ),
              const SizedBox(height: huecoVista),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final x in tipos.where((x) => tiposUsados.contains(x.nombre)))
                    _ChipTipo(x, tipo == x.nombre, () => setState(() => tipo = tipo == x.nombre ? null : x.nombre)),
                ],
              ),
              if (pestana == 1) ...[
                const SizedBox(height: 12),
                const Consejo(
                  'Las plantillas son trabajos que dejas pre-creados con ciertos campos ya rellenos. '
                  'Al crear un trabajo, eliges una plantilla y se rellena casi todo.',
                ),
              ],
              const SizedBox(height: huecoVista),
              Expanded(
                child: filtradas.isEmpty
                    ? Vacio(
                        icono: Icons.handyman_outlined,
                        titulo: store.tareas.isEmpty ? 'Aún no hay trabajos' : null,
                        texto: pestana == 0 && nTrabajos == 0
                            ? 'Crea tu primer trabajo, desde cero o a partir de una plantilla.'
                            : 'No hay trabajos con estos filtros',
                        // Sin búsqueda ni filtro de tipo: botón para crear (el primero, si aún no hay).
                        accion: q.isEmpty && tipo == null
                            ? FilledButton(
                                onPressed: () => abrirTareaForm(context, null, plantilla: pestana == 1),
                                child: Text(
                                  pestana == 1
                                      ? 'Nueva plantilla'
                                      : nTrabajos == 0
                                      ? 'Añadir el primer trabajo'
                                      : 'Nuevo trabajo',
                                ),
                              )
                            : null,
                      )
                    : lista
                    ? _tabla(filtradas)
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
        if (seleccionando)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: BarraSeleccion(
                seleccionados: seleccion.length,
                total: filtradas.length,
                nombre: 'trabajos',
                onTodos: () => setState(() {
                  if (filtradas.every((t) => seleccion.contains(t.id))) {
                    seleccion.removeAll(filtradas.map((t) => t.id));
                  } else {
                    seleccion.addAll(filtradas.map((t) => t.id));
                  }
                }),
                onEliminar: eliminarSeleccion,
                onSalir: salirSeleccion,
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabla(List<Tarea> ts) => SegunTamano(
    clave: (box) => (box.maxWidth > 1000, box.maxWidth > 600),
    builder: (context, box) {
      final ancho = box.maxWidth > 1000;
      // Móvil: solo las columnas clave.
      final medio = box.maxWidth > 600;
      return Align(
        alignment: Alignment.topCenter,
        child: Tabla(
          seleccionCabecera: BotonSeleccionLista(
            activo: seleccionando,
            onTap: () => seleccionando ? salirSeleccion() : setState(() => seleccionando = true),
          ),
          columnas: [
            if (seleccionando) const Col('', ancho: 36, cabecera: SizedBox()),
            const Col('Equipo / trabajo', flex: 4),
            if (medio) const Col('Cliente', flex: 3),
            if (ancho) const Col('Periodicidad', flex: 2),
            const Col('Próximo', flex: 2),
            if (ancho) const Col('Horario', flex: 2),
            if (medio) const Col('Asignado a', ancho: 90),
            const Col('Estado', ancho: 80, derecha: true),
          ],
          filas: ts.length,
          onTap: (i) {
            if (seleccionando) {
              setState(() => seleccion.contains(ts[i].id) ? seleccion.remove(ts[i].id) : seleccion.add(ts[i].id));
            } else {
              widget.onAbrir(ts[i].id);
            }
          },
          pie: pieTabla(ts.length, ts.length == 1 ? 'trabajo' : 'trabajos'),
          celdas: (i) {
            final t = ts[i];
            final c = store.cliente(t.clienteId);
            final vencida = t.proximo != null && diasHasta(t.proximo!) < 0;
            return [
              if (seleccionando) CirculoSeleccion(seleccion.contains(t.id)),
              Row(
                children: [
                  BarraTipo(t.tipo, alto: 28, color: t.colorBloque),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        celdaTexto(t.nombre, negrita: true),
                        Text(
                          [t.tipo, if (t.ubicacion.isNotEmpty) t.ubicacion].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (medio)
                c == null
                    ? (t.esPlantilla ? Etiqueta('Plantilla', P.morado) : celdaTexto('Sin cliente', suave: true))
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
                        Text(relativo(t.proximo!), style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                      ],
                    ),
              if (ancho) celdaTexto(t.horario ?? '', suave: true),
              if (medio) t.esPlantilla ? const SizedBox() : AvataresTrabajadores(t.trabajadorIds, size: 24),
              pillEstado(t),
            ];
          },
        ),
      );
    },
  );
}

/// Filtro por tipo: píldora con el punto de color del tipo; la elegida, con borde de su color.
class _ChipTipo extends StatelessWidget {
  final TipoInfo tipo;
  final bool sel;
  final VoidCallback onTap;
  const _ChipTipo(this.tipo, this.sel, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sel ? tipo.color.withValues(alpha: .1) : P.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? tipo.color : P.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tipo.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            tipo.nombre,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: sel ? tipo.color : P.texto),
          ),
        ],
      ),
    ),
  );
}
