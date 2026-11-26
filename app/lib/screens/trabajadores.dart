import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../columnas.dart';
import '../forms.dart';
import '../models.dart';
import '../importar.dart' show QueImportar;
import 'importar_exportar.dart' show abrirImportarExportar;
import '../industrial/activos.dart' show enOrdenDelUsuario;
import '../store.dart';
import 'accesos.dart';
import '../theme.dart';
import '../widgets.dart';
import 'grupos.dart';
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
  /// Pultec: solo los técnicos de este grupo (null = todos).
  String? grupo;

  /// Grupos plegados en la vista por grupos (por id; «» = Sin grupo).
  final plegados = <String>{};
  /// Por defecto, en bloques.
  bool lista = false;

  /// Modo selección: para eliminar varios de golpe.
  bool seleccionando = false;
  final seleccion = <String>{};

  // G: nuevo grupo (como N para un técnico), si no se está escribiendo ni hay una ventana encima.
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_teclaG);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_teclaG);
    super.dispose();
  }

  bool _teclaG(KeyEvent e) {
    if (!industrial || e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyG || !mounted) return false;
    final teclado = HardwareKeyboard.instance;
    if (teclado.isControlPressed || teclado.isMetaPressed || teclado.isAltPressed) return false;
    if (primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    abrirGrupoForm(context);
    return true;
  }

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
      if (grupo != null && !w.enGrupo(grupo)) return false;
      final t = q.toLowerCase();
      // También por el nombre de sus grupos.
      return w.nombreCompleto.toLowerCase().contains(t) ||
          w.grupoIds.any((g) => store.grupo(g)?.nombre.toLowerCase().contains(t) ?? false);
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
                      ],
                      derecha: [
                        if (store.trabajadores.isNotEmpty) ...[
                          // Pultec: busca también por grupo y, al final del campo, el filtro por grupo.
                          Buscador(
                            hint: industrial && store.grupos.isNotEmpty ? 'Buscar técnico o grupo…' : m('Buscar trabajador…'),
                            width: industrial && store.grupos.isNotEmpty ? 290 : 240,
                            onChanged: (v) => setState(() => q = v),
                            sufijo: industrial && store.grupos.isNotEmpty
                                ? FiltroGrupo(grupo, (v) => setState(() => grupo = v))
                                : null,
                          ),
                          if (industrial && store.grupo(grupo) != null)
                            Pill(store.grupo(grupo)!.nombre, P.morado, icono: iconoGrupo),
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
                      ],
                      principal: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pultec: importar y exportar técnicos (solo iconos) justo a la izquierda del principal.
                          if (industrial) ...[
                            BotonImportarExportar(
                              tooltip: 'Importar y exportar técnicos',
                              onPressed: () => abrirImportarExportar(context, que: QueImportar.trabajadores),
                            ),
                            const SizedBox(width: 8),
                            // Crear un grupo y meter técnicos dentro.
                            BotonPrimario(
                              'Nuevo grupo',
                              conIcono: true,
                              tecla: 'G',
                              onPressed: () => abrirGrupoForm(context),
                            ),
                            const SizedBox(width: 8),
                          ],
                          BotonPrimario(
                            m('Nuevo trabajador'),
                            conIcono: industrial,
                            tecla: 'N',
                            onPressed: () => abrirTrabajadorForm(context),
                          ),
                        ],
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
                                industrial
                                    ? 'Añade a tu equipo y, si quieres, organízalo en grupos.'
                                    : 'Añade a tu equipo con sus competencias para que Pultec sepa a quién asignar cada trabajo.',
                              )
                            : m('No hay trabajadores con estos filtros'),
                        accion: store.trabajadores.isEmpty
                            ? FilledButton(
                                onPressed: () => abrirTrabajadorForm(context),
                                child: Text(industrial ? 'Añadir el primer técnico' : m('Añadir el primer trabajador')),
                              )
                            : null,
                        flecha: store.trabajadores.isEmpty,
                        varianteFlecha: 1,
                      )
                    : this.lista
                    ? _tabla(lista)
                    // Pultec con grupos: los técnicos segmentados por grupo desde el principio.
                    : industrial && store.grupos.isNotEmpty
                    ? _RejillaPorGrupos(
                        lista,
                        _tarjeta,
                        plegados: plegados,
                        // Con filtros, los grupos vacíos no salen; sin ellos, sí (para ver los recién creados).
                        conVacios: q.isEmpty && estado == 0 && grupo == null,
                        soloGrupo: grupo,
                        onPlegar: (id) => setState(() => plegados.contains(id) ? plegados.remove(id) : plegados.add(id)),
                      )
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
          // Orden y columnas elegidas se guardan en la cuenta (y Exportar los sigue).
          id: 'tecnicos',
          menuColumnas: industrial && medio,
          seleccionCabecera: BotonSeleccionLista(
            activo: seleccionando,
            onTap: () => seleccionando ? salirSeleccion() : setState(() => seleccionando = true),
          ),
          columnas: [
            if (seleccionando) const Col('', ancho: 36, cabecera: SizedBox()),
            const Col('Nombre', flex: 3, fija: true),
            // Pultec: sus grupos (sin especialidades).
            if (medio) Col(industrial ? 'Grupos' : 'Competencias', flex: 4),
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
                  children: industrial
                      ? [
                          for (final g in gruposOrdenados())
                            if (w.enGrupo(g.id)) Pill(g.nombre, P.gris, icono: iconoGrupo),
                          if (store.sinGrupo(w)) celdaTexto('Sin grupo', suave: true),
                        ]
                      : [
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
                // Pultec: sus grupos en la tarjeta, no especialidades.
                children: industrial
                    ? [
                        for (final g in gruposOrdenados())
                          if (w.enGrupo(g.id)) Pill(g.nombre, P.gris, icono: iconoGrupo),
                      ]
                    : [for (final c in w.competencias) Etiqueta(c, P.morado)],
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

/// Pultec: técnicos por grupo, con los grupos arriba (por nombre) y al final los que no tienen. Cada grupo se
/// pliega o despliega tocando su cabecera; un técnico en varios grupos sale en cada uno. Virtualizada.
class _RejillaPorGrupos extends StatelessWidget {
  final List<Trabajador> ws;
  final Widget Function(Trabajador) tarjeta;
  final Set<String> plegados;
  final bool conVacios;
  final String? soloGrupo;
  final ValueChanged<String> onPlegar;
  const _RejillaPorGrupos(
    this.ws,
    this.tarjeta, {
    required this.plegados,
    required this.conVacios,
    required this.soloGrupo,
    required this.onPlegar,
  });

  static const _anchoMin = 260.0, _hueco = 16.0;
  int _cols(BoxConstraints box) => max(1, ((box.maxWidth + _hueco) / (_anchoMin + _hueco)).floor());

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: _cols,
    builder: (context, box) {
      final cols = _cols(box);
      final filas = <Object>[];
      for (final (g, suyos) in [
        for (final g in gruposOrdenados())
          if (soloGrupo == null || soloGrupo == g.id) (g, ws.where((w) => w.enGrupo(g.id)).toList()),
        if (soloGrupo == null) (null, ws.where(store.sinGrupo).toList()),
      ]) {
        if (suyos.isEmpty && (g == null || !conVacios)) continue;
        final id = g?.id ?? '';
        filas.add((g, suyos.length, plegados.contains(id)));
        if (plegados.contains(id)) continue;
        if (suyos.isEmpty) filas.add(g!);
        for (var i = 0; i < suyos.length; i += cols) {
          filas.add(suyos.sublist(i, min(i + cols, suyos.length)));
        }
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: filas.length,
        itemBuilder: (_, n) => switch (filas[n]) {
          (final GrupoTecnicos? g, final int total, final bool plegado) => _CabeceraGrupo(
            g,
            total,
            plegado: plegado,
            primera: n == 0,
            onTap: () => onPlegar(g?.id ?? ''),
          ),
          // Grupo sin técnicos: una línea para meterlos.
          final GrupoTecnicos g => Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              children: [
                Text('Aún no hay técnicos en este grupo.', style: TextStyle(color: P.textoSuave)),
                const SizedBox(width: 6),
                Enlace('Añadir técnicos', onTap: () => abrirGrupoForm(context, g)),
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

/// Cabecera de un grupo: flecha que gira al plegar, icono de grupo (morado al pasar), nombre, cuántos y «Editar».
class _CabeceraGrupo extends StatefulWidget {
  final GrupoTecnicos? g;
  final int total;
  final bool plegado, primera;
  final VoidCallback onTap;
  const _CabeceraGrupo(this.g, this.total, {required this.plegado, required this.primera, required this.onTap});

  @override
  State<_CabeceraGrupo> createState() => _CabeceraGrupoState();
}

class _CabeceraGrupoState extends State<_CabeceraGrupo> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(0, widget.primera ? 0 : 8, 0, 8),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          height: 34,
          child: Row(
            children: [
              AnimatedRotation(
                turns: widget.plegado ? -.25 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Icon(Icons.expand_more_rounded, size: 20, color: P.textoSuave),
              ),
              const SizedBox(width: 4),
              if (widget.g != null) ...[
                Icon(iconoGrupo, size: 19, color: _encima ? P.morado : P.textoSuave),
                const SizedBox(width: 8),
              ],
              Text(
                widget.g?.nombre ?? 'Sin grupo',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text('${widget.total}', style: TextStyle(fontSize: 14, color: P.textoSuave)),
              if (widget.g != null) ...[
                const SizedBox(width: 6),
                Enlace('Editar', onTap: () => abrirGrupoForm(context, widget.g)),
              ],
            ],
          ),
        ),
      ),
    ),
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

/// La lista de Técnicos en texto, tal como la ve el usuario (sus columnas en su orden), para exportar en PDF y su
/// vista previa. La cabecera, la primera fila.
List<List<String>> listaTecnicosEnTexto() {
  final valores = <String, String Function(Trabajador)>{
    'Nombre': (w) => w.nombreCompleto,
    if (industrial) 'Grupos': (w) => gruposDe(w) else 'Competencias': (w) => w.competencias.join(', '),
    'Teléfono': (w) => w.telefono,
    m('Trabajos'): (w) => '${store.tareas.where((t) => !t.esPlantilla && t.trabajadorIds.contains(w.id)).length}',
    'Hoy': (w) => w.activo ? w.estadoHoy.etiqueta : 'Inactivo',
  };
  final cols = enOrdenDelUsuario([
    for (final c in valores.keys)
      if (c == 'Nombre' || columnasTablas.ve('tecnicos', c)) c,
  ], columnasTablas.orden('tecnicos'));
  final ws = [...store.trabajadores]..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
  return [
    cols,
    for (final w in ws) [for (final c in cols) valores[c]!(w)],
  ];
}
