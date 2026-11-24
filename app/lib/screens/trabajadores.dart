import 'dart:math';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import 'accesos.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tipos_competencias.dart' show abrirGrupos;
import '../marca.dart';
import 'tareas.dart' show otsAtrasadas, verAtrasadasDe;

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
  /// Por defecto, en bloques.
  bool lista = false;

  /// Modo selección: para eliminar varios de golpe.
  bool seleccionando = false;
  final seleccion = <String>{};

  void salirSeleccion() => setState(() {
    seleccionando = false;
    seleccion.clear();
  });

  Future<void> eliminarSeleccion() async {
    final n = seleccion.length;
    if (!await confirmar(context, m('¿Eliminar $n ${n == 1 ? 'trabajador' : 'trabajadores'}?'), nota: 'Podrás deshacerlo.')) return;
    store.deshacible(m('Has borrado $n ${n == 1 ? 'trabajador' : 'trabajadores'}'), () {
      for (final id in seleccion) {
        store.borrarTrabajador(id);
      }
    });
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
                        // Solo el título: sin icono grande ni frase de relleno debajo.
                        TituloVista(m('Trabajadores')),
                        // Sin ningún trabajador, ni filtros ni buscador: solo el título, invitar y crear.
                        if (store.trabajadores.isNotEmpty) Pestanas(
                          opciones: const ['Todos', 'Disponibles', 'Ocupados', 'Ausentes'],
                          // El punto con el color de cada estado (como en la columna Hoy).
                          colores: [null, for (final e in EstadoHoy.values) e.color],
                          seleccion: estado,
                          onChanged: (i) => setState(() => estado = i),
                        ),
                        if (store.trabajadores.isNotEmpty)
                          _FiltroCompetencia(competencia, (v) => setState(() => competencia = v)),
                      ],
                      derecha: [
                        if (store.trabajadores.isNotEmpty) ...[
                          Buscador(hint: m('Buscar trabajador…'), onChanged: (v) => setState(() => q = v)),
                          SelectorVista(
                            bloquesPrimero: true,
                            lista: this.lista,
                            onChanged: (v) => setState(() => this.lista = v),
                          ),
                        ],
                        // Pultec: grupos de técnicos (crear, ver y meter técnicos).
                        // Quién entra en la empresa con su cuenta: invitar con un enlace o quitar el acceso.
                        if (store.nube != null)
                          BotonAccion(
                            'Accesos',
                            icono: Icons.key_outlined,
                            tooltip: 'Invitar técnicos con un enlace y quitar accesos',
                            onPressed: () => abrirAccesos(context),
                          ),
                        if (industrial && store.trabajadores.isNotEmpty)
                          BotonAccion(
                            'Grupo',
                            icono: Icons.add_rounded,
                            tooltip: 'Crear grupos y meter técnicos',
                            onPressed: () => abrirGrupos(context),
                          ),
                      ],
                      principal: BotonPrimario(
                        m('Nuevo trabajador'),
                        conIcono: industrial,
                        tecla: 'N',
                        onPressed: () => abrirTrabajadorForm(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: huecoVista),
              Expanded(
                child: lista.isEmpty
                    ? Vacio(
                        icono: Marca.iconoTrabajador,
                        titulo: store.trabajadores.isEmpty ? m('Aún no hay trabajadores') : null,
                        texto: store.trabajadores.isEmpty
                            ? m(
                                'Añade a tu equipo con sus competencias para que Pultec sepa a quién asignar cada trabajo.',
                              )
                            : m('No hay trabajadores con estos filtros'),
                        accion: store.trabajadores.isEmpty
                            ? FilledButton(
                                onPressed: () => abrirTrabajadorForm(context),
                                child: Text(m('Añadir el primer trabajador')),
                              )
                            : null,
                      )
                    : this.lista
                    ? _tabla(lista)
                    // Pultec con grupos: los técnicos segmentados por grupo desde el principio.
                    : industrial && store.grupos.isNotEmpty
                    ? _RejillaPorGrupos(lista, _tarjeta)
                    : ListaRejilla(anchoMin: 260, total: lista.length, item: (i) => _tarjeta(lista[i])),
              ),
            ],
          ),
        ),
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
                  seleccionados: seleccion.length,
                  total: lista.length,
                  nombre: m('trabajadores'),
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
          ),
      ],
    );
  }

  void _tocar(Trabajador w) {
    if (seleccionando) {
      setState(() => seleccion.contains(w.id) ? seleccion.remove(w.id) : seleccion.add(w.id));
    } else {
      store.verNuevo(w.id);
      widget.onAbrir(w.id);
    }
  }

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
            if (medio) Col(m('Trabajos'), flex: 1),
            const Col('Hoy', ancho: 90, derecha: true),
          ],
          filas: ws.length,
          onTap: (i) => _tocar(ws[i]),
          pie: pieTabla(ws.length, m(ws.length == 1 ? 'trabajador' : 'trabajadores')),
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
                        conNuevo(w.id, celdaTexto(w.nombreCompleto, negrita: true)),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
          Column(
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
                  // Si la tarjeta es estrecha, el número de órdenes se corta en vez de salirse.
                  Flexible(child: Pill(m('$asignadas trabajos'), P.gris)),
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
          // Pultec: arriba a la izquierda, cuántas órdenes lleva atrasadas; al tocarla, se ven en Órdenes de trabajo.
          if (industrial && otsAtrasadas(w.id).isNotEmpty)
            Positioned(top: -8, left: -8, child: _InsigniaAtrasadas(w)),
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

/// Pultec: tarjetas de técnicos por grupo (por nombre de grupo; al final, los que no tienen). Cada grupo con su
/// título, cuántos son y su área en gris. Virtualizada como `ListaRejilla`.
class _RejillaPorGrupos extends StatelessWidget {
  final List<Trabajador> ws;
  final Widget Function(Trabajador) tarjeta;
  const _RejillaPorGrupos(this.ws, this.tarjeta);

  static const _anchoMin = 260.0, _hueco = 16.0;
  int _cols(BoxConstraints box) => max(1, ((box.maxWidth + _hueco) / (_anchoMin + _hueco)).floor());

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: _cols,
    builder: (context, box) {
      final cols = _cols(box);
      final grupos = [...store.grupos]..sort((a, b) => a.nombre.compareTo(b.nombre));
      final filas = <Object>[];
      for (final (titulo, area, suyos) in [
        for (final g in grupos) (g.nombre, g.area, ws.where((w) => w.grupoId == g.id).toList()),
        ('Sin grupo', '', ws.where((w) => store.grupo(w.grupoId) == null).toList()),
      ]) {
        if (suyos.isEmpty) continue;
        filas.add((titulo, area, suyos.length));
        for (var i = 0; i < suyos.length; i += cols) {
          filas.add(suyos.sublist(i, min(i + cols, suyos.length)));
        }
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: filas.length,
        itemBuilder: (_, n) => switch (filas[n]) {
          (final String titulo, final String area, final int total) => Padding(
            padding: EdgeInsets.fromLTRB(4, n == 0 ? 4 : 12, 4, 10),
            child: Row(
              children: [
                Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('$total', style: TextStyle(fontSize: 14, color: P.textoSuave)),
                if (area.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(area, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: P.textoSuave)),
                  ),
                ],
              ],
            ),
          ),
          final List<Trabajador> fila => Padding(
            padding: const EdgeInsets.only(bottom: _hueco),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: _hueco),
                  Expanded(child: j < fila.length ? tarjeta(fila[j]) : const SizedBox()),
                ],
              ],
            ),
          ),
          _ => const SizedBox.shrink(),
        },
      );
    },
  );
}

/// Número rojo de órdenes atrasadas de un técnico: al pasar el ratón lo explica; al tocarlo, abre Órdenes de
/// trabajo con sus vencidas.
class _InsigniaAtrasadas extends StatelessWidget {
  final Trabajador w;
  const _InsigniaAtrasadas(this.w);

  @override
  Widget build(BuildContext context) {
    final n = otsAtrasadas(w.id).length;
    return Tooltip(
      message: '${w.nombre} tiene $n ${n == 1 ? 'orden atrasada' : 'órdenes atrasadas'}. Toca para verlas.',
      child: Material(
        color: P.rojo,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => verAtrasadasDe(w.id),
          child: Container(
            constraints: const BoxConstraints(minWidth: 26),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            alignment: Alignment.center,
            child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
