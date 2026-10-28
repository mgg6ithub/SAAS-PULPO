import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

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
  const TablaTrabajos(
    this.trabajos, {
    super.key,
    required this.onAbrir,
    this.conCliente = true,
    this.umbralAncho = 1000,
    this.nombre = 'trabajo',
  });

  @override
  State<TablaTrabajos> createState() => _TablaTrabajosState();
}

class _TablaTrabajosState extends State<TablaTrabajos> {
  bool seleccionando = false;
  final seleccion = <String>{};

  void salirSeleccion() => setState(() {
    seleccionando = false;
    seleccion.clear();
  });

  Future<void> eliminarSeleccion() async {
    final n = seleccion.length;
    if (!await confirmar(context, '¿Eliminar $n ${n == 1 ? widget.nombre : '${widget.nombre}s'}?')) return;
    for (final id in seleccion) {
      store.borrarTarea(id);
    }
    salirSeleccion();
  }

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

  @override
  Widget build(BuildContext context) {
    final ts = widget.trabajos;
    return Stack(
      children: [
        _tabla(ts),
        if (seleccionando)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: BarraSeleccion(
                seleccionados: seleccion.length,
                total: ts.length,
                nombre: '${widget.nombre}s',
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
      ],
    );
  }

  Widget _tabla(List<Tarea> ts) => SegunTamano(
    clave: (box) => (box.maxWidth > widget.umbralAncho, box.maxWidth > 600),
    builder: (context, box) {
      final ancho = box.maxWidth > widget.umbralAncho;
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
            if (medio && widget.conCliente) const Col('Cliente', flex: 3),
            if (medio) const Col('Subtrabajos', ancho: 100),
            if (ancho) const Col('Periodicidad', flex: 2),
            const Col('Próximo', flex: 2),
            if (ancho) const Col('Horario', flex: 2),
            if (medio) const Col('Asignado a', ancho: 120),
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
          pie: pieTabla(ts.length, ts.length == 1 ? widget.nombre : '${widget.nombre}s'),
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
              if (medio && widget.conCliente)
                c == null
                    ? (t.esPlantilla ? Etiqueta('Plantilla', P.morado) : celdaTexto('Sin cliente', suave: true))
                    : Row(
                        children: [
                          Avatar(c.iniciales, colorPaleta(c.color), size: 20, cuadrado: true),
                          const SizedBox(width: 8),
                          Flexible(child: celdaTexto(c.nombre)),
                        ],
                      ),
              if (medio) _subtrabajos(t),
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
              if (medio)
                t.esPlantilla
                    ? const SizedBox()
                    : SelectorTrabajadores(t, () => store.guardarTarea(t), compacto: true, ofrecerSubtrabajos: true),
              pillEstado(t),
            ];
          },
        ),
      );
    },
  );
}
