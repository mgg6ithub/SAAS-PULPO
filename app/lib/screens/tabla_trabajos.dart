import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
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
    final nombre = m('$n ${n == 1 ? widget.nombre : '${widget.nombre}s'}');
    if (!await confirmar(context, preguntaBorrarTrabajos(seleccion, nombre: nombre))) return;
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
            for (final e in EstadoTrabajo.values)
              opcion(
                e.etiqueta,
                () {
                  store.cambiarEstado(sel, e);
                  aplicado();
                },
                icono: Container(
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
                () => aplicar((t) => t.trabajadorIds = [w.id]),
                icono: Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 20),
              ),
          ],
          child: const Text('Asignado a'),
        ),
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
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: BarraSeleccion(
                acciones: [_cambiar()],
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
            Col(m('Equipo / trabajo'), flex: 4),
            if (medio && widget.conCliente) Col(m('Cliente'), flex: 3),
            if (ancho) const Col('Periodicidad', flex: 2),
            const Col('Fecha y hora', flex: 3),
            if (medio) const Col('Asignado a', ancho: 96),
            const Col('Estado', ancho: 140, derecha: true),
            // Solo si algún trabajo de la lista tiene subtrabajos; al final y abreviada.
            if (medio && ts.any((t) => store.hijas(t.id).isNotEmpty)) const Col('Sub', ancho: 60, ayuda: 'Subtrabajos'),
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
                t.esPlantilla
                    ? const SizedBox()
                    : SelectorTrabajadores(t, () => store.guardarTarea(t), compacto: true, ofrecerSubtrabajos: true),
              t.esPlantilla ? pillEstado(t) : SelectorEstado(t),
              if (medio && ts.any((x) => store.hijas(x.id).isNotEmpty)) _subtrabajos(t),
            ];
          },
        ),
      );
    },
  );
}
