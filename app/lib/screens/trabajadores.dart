import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class Trabajadores extends StatefulWidget {
  final ValueChanged<String> onAbrir;
  const Trabajadores({super.key, required this.onAbrir});

  @override
  State<Trabajadores> createState() => _TrabajadoresState();
}

class _TrabajadoresState extends State<Trabajadores> {
  String q = '';
  int estado = 0; // 0 todos; si no, EstadoHoy.values[estado - 1]
  String? competencia;
  bool lista = true;

  /// Modo selección: para eliminar varios de golpe.
  bool seleccionando = false;
  final seleccion = <String>{};

  void salirSeleccion() => setState(() {
    seleccionando = false;
    seleccion.clear();
  });

  Future<void> eliminarSeleccion() async {
    final n = seleccion.length;
    if (!await confirmar(context, '¿Eliminar $n ${n == 1 ? 'trabajador' : 'trabajadores'}?')) return;
    for (final id in seleccion) {
      store.borrarTrabajador(id);
    }
    salirSeleccion();
  }

  @override
  Widget build(BuildContext context) {
    final lista = store.trabajadores.where((w) {
      if (estado > 0 && (w.estadoHoy != EstadoHoy.values[estado - 1] || !w.activo)) return false;
      if (competencia != null && !w.competencias.contains(competencia)) return false;
      return w.nombreCompleto.toLowerCase().contains(q.toLowerCase());
    }).toList()..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));

    return Stack(
      children: [
        Padding(
          padding: margenPagina,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Atenuado(
                activo: seleccionando,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Una sola barra: título y filtros a la izquierda; buscador y acciones a la derecha.
                    BarraVista(
                      izquierda: [
                        const TituloVista('Trabajadores'),
                        Pestanas(
                          opciones: const ['Todos', 'Disponibles', 'Ocupados', 'Ausentes'],
                          seleccion: estado,
                          onChanged: (i) => setState(() => estado = i),
                        ),
                        _FiltroCompetencia(competencia, (v) => setState(() => competencia = v)),
                      ],
                      derecha: [
                        Buscador(hint: 'Buscar trabajador…', onChanged: (v) => setState(() => q = v)),
                        SelectorVista(lista: this.lista, onChanged: (v) => setState(() => this.lista = v)),
                        BotonPrimario('Nuevo trabajador', tecla: 'N', onPressed: () => abrirTrabajadorForm(context)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: huecoVista),
              Expanded(
                child: lista.isEmpty
                    ? Vacio(
                        icono: Icons.badge_outlined,
                        titulo: store.trabajadores.isEmpty ? 'Aún no hay trabajadores' : null,
                        texto: store.trabajadores.isEmpty
                            ? 'Añade a tu equipo con sus competencias para que Pulpo sepa a quién asignar cada tarea.'
                            : 'No hay trabajadores con estos filtros',
                      )
                    : this.lista
                    ? _tabla(lista)
                    : ListaRejilla(anchoMin: 260, total: lista.length, item: (i) => _tarjeta(lista[i])),
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
                total: lista.length,
                nombre: 'trabajadores',
                onTodos: () => setState(() {
                  if (seleccion.length == lista.length) {
                    seleccion.clear();
                  } else {
                    seleccion.addAll(lista.map((w) => w.id));
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

  void _tocar(Trabajador w) => seleccionando
      ? setState(() => seleccion.contains(w.id) ? seleccion.remove(w.id) : seleccion.add(w.id))
      : widget.onAbrir(w.id);

  Widget _tabla(List<Trabajador> ws) => SegunTamano(
    clave: (box) => (box.maxWidth > 980, box.maxWidth > 600),
    builder: (context, box) {
      final ancho = box.maxWidth > 980;
      // Móvil: sin competencias ni tareas.
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
            const Col('Nombre', flex: 3),
            if (medio) const Col('Competencias', flex: 4),
            if (ancho) const Col('Teléfono', flex: 2),
            if (medio) const Col('Tareas', flex: 1),
            const Col('Hoy', ancho: 90, derecha: true),
          ],
          filas: ws.length,
          onTap: (i) => _tocar(ws[i]),
          pie: pieTabla(ws.length, ws.length == 1 ? 'trabajador' : 'trabajadores'),
          celdas: (i) {
            final w = ws[i];
            final asignadas = store.tareas.where((t) => !t.esPlantilla && t.trabajadorIds.contains(w.id)).length;
            return [
              if (seleccionando) CirculoSeleccion(seleccion.contains(w.id)),
              Row(
                children: [
                  Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 28),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        celdaTexto(w.nombreCompleto, negrita: true),
                        if (w.email.isNotEmpty)
                          Text(
                            w.email,
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
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final c in w.competencias.take(3)) Etiqueta(c, P.morado),
                    if (w.competencias.length > 3)
                      Text('+${w.competencias.length - 3}', style: TextStyle(fontSize: 12, color: P.textoSuave)),
                  ],
                ),
              if (ancho) celdaTexto(w.telefono, suave: true),
              if (medio) celdaTexto('$asignadas'),
              w.activo
                  ? Pill(w.estadoHoy.etiqueta, w.estadoHoy.color, punto: true)
                  : const Pill('Inactivo', P.gris, punto: true),
            ];
          },
        ),
      );
    },
  );

  Widget _tarjeta(Trabajador w) {
    final asignadas = store.tareas.where((t) => t.trabajadorIds.contains(w.id)).length;
    return MarcaSeleccion(
      activo: seleccionando,
      seleccionado: seleccion.contains(w.id),
      onMarcar: () => setState(() {
        seleccionando = true;
        seleccion.add(w.id);
      }),
      child: HoverCard(
        padding: const EdgeInsets.all(20),
        onTap: () => _tocar(w),
        child: Opacity(
          opacity: w.activo ? 1 : .55,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 56),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: w.activo ? w.estadoHoy.color : P.gris,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(w.nombreCompleto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                w.titulos.isEmpty ? '—' : w.titulos,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: P.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  w.activo
                      ? Pill(w.estadoHoy.etiqueta, w.estadoHoy.color, punto: true)
                      : const Pill('Inactivo', P.gris, punto: true),
                  const SizedBox(width: 6),
                  Pill('$asignadas tareas', P.gris),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [for (final c in w.competencias) Etiqueta(c, P.morado)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desplegable compacto de competencia, del alto de los demás filtros ("+ Filtro" de Holded).
class _FiltroCompetencia extends StatelessWidget {
  final String? valor;
  final ValueChanged<String?> onChanged;
  const _FiltroCompetencia(this.valor, this.onChanged);

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Filtrar por competencia',
    onSelected: (v) => onChanged(v.isEmpty ? null : v),
    itemBuilder: (_) => [
      const PopupMenuItem(value: '', child: Text('Todas las competencias')),
      for (final c in competencias) PopupMenuItem(value: c, child: Text(c)),
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
          Icon(valor == null ? Icons.add_rounded : Icons.workspace_premium_outlined, size: 16, color: P.morado),
          const SizedBox(width: 4),
          Text(
            valor ?? 'Filtro',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.morado),
          ),
        ],
      ),
    ),
  );
}
