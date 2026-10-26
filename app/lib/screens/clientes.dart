import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class Clientes extends StatefulWidget {
  final ValueChanged<String> onAbrir;
  const Clientes({super.key, required this.onAbrir});

  @override
  State<Clientes> createState() => _ClientesState();
}

class _ClientesState extends State<Clientes> {
  String q = '';
  int filtro = 0; // 0 todos, 1 activos, 2 inactivos
  bool lista = true;

  /// Modo selección: para eliminar varios de golpe.
  bool seleccionando = false;
  final seleccion = <String>{};

  void salirSeleccion() => setState(() {
    seleccionando = false;
    seleccion.clear();
  });

  void alternar(String id) => setState(() => seleccion.contains(id) ? seleccion.remove(id) : seleccion.add(id));

  Future<void> eliminarSeleccion() async {
    final n = seleccion.length;
    if (!await confirmar(context, '¿Eliminar $n ${n == 1 ? 'cliente' : 'clientes'} y sus tareas?')) return;
    for (final id in seleccion) {
      store.borrarCliente(id);
    }
    salirSeleccion();
  }

  @override
  Widget build(BuildContext context) {
    final clientes = store.clientes.where((c) {
      if (filtro == 1 && !c.activa) return false;
      if (filtro == 2 && c.activa) return false;
      final t = '${c.nombre} ${c.ciudad} ${c.cif}'.toLowerCase();
      return t.contains(q.toLowerCase());
    }).toList()..sort((a, b) => a.nombre.compareTo(b.nombre));

    final onTap = seleccionando ? alternar : widget.onAbrir;
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
                        const TituloVista('Clientes'),
                        Pestanas(
                          opciones: ['Todos · ${store.clientes.length}', 'Activos', 'Inactivos'],
                          seleccion: filtro,
                          onChanged: (i) => setState(() => filtro = i),
                        ),
                      ],
                      derecha: [
                        Buscador(hint: 'Buscar cliente…', onChanged: (v) => setState(() => q = v)),
                        SelectorVista(lista: lista, onChanged: (v) => setState(() => lista = v)),
                        BotonPrimario('Nuevo cliente', tecla: 'N', onPressed: () => abrirClienteForm(context)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: huecoVista),
              Expanded(
                child: clientes.isEmpty
                    ? Vacio(
                        icono: Icons.apartment_outlined,
                        titulo: q.isEmpty ? 'Aún no tienes clientes' : null,
                        texto: q.isEmpty
                            ? 'Añade los edificios, colegios u hospitales a los que das mantenimiento.'
                            : 'Ningún cliente coincide con la búsqueda',
                        accion: q.isEmpty
                            ? FilledButton(
                                onPressed: () => abrirClienteForm(context),
                                child: const Text('Añadir el primero'),
                              )
                            : null,
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        layoutBuilder: (actual, anteriores) =>
                            Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
                        child: lista
                            ? _Tabla(
                                clientes,
                                onTap,
                                seleccion: seleccionando ? seleccion : null,
                                onModo: () => seleccionando ? salirSeleccion() : setState(() => seleccionando = true),
                                key: const ValueKey('lista'),
                              )
                            : _Bloques(
                                clientes,
                                onTap,
                                seleccion: seleccionando ? seleccion : null,
                                onMarcar: (id) => setState(() {
                                  seleccionando = true;
                                  seleccion.add(id);
                                }),
                                key: const ValueKey('bloques'),
                              ),
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
                total: clientes.length,
                nombre: 'clientes',
                onTodos: () => setState(() {
                  if (seleccion.length == clientes.length) {
                    seleccion.clear();
                  } else {
                    seleccion.addAll(clientes.map((c) => c.id));
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
}

class _Bloques extends StatelessWidget {
  final List<Cliente> clientes;
  final ValueChanged<String> onAbrir;

  /// Si no es null, se está seleccionando: el toque marca en vez de abrir.
  final Set<String>? seleccion;
  final ValueChanged<String> onMarcar;
  const _Bloques(this.clientes, this.onAbrir, {this.seleccion, required this.onMarcar, super.key});

  @override
  Widget build(BuildContext context) =>
      ListaRejilla(anchoMin: 300, total: clientes.length, item: (i) => _bloque(clientes[i]));

  Widget _bloque(Cliente c) {
    final tareas = store.tareasDe(c.id);
    final vencidas = tareas.where((t) => t.proximo != null && diasHasta(t.proximo!) < 0).length;
    final tiposUsados = {for (final t in tareas) t.tipo}.toList();
    return MarcaSeleccion(
      activo: seleccion != null,
      seleccionado: seleccion?.contains(c.id) ?? false,
      onMarcar: () => onMarcar(c.id),
      child: HoverCard(
        onTap: () => onAbrir(c.id),
        child: Opacity(
          opacity: c.activa ? 1 : .55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(c.iniciales, colorPaleta(c.color), size: 40, cuadrado: true),
                  const Spacer(),
                  if (seleccion == null)
                    c.activa ? const Pill('Activo', P.verde, punto: true) : const Pill('Inactivo', P.gris, punto: true),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                c.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                [c.ciudad, c.provincia].where((x) => x.isNotEmpty).toSet().join(', '),
                style: TextStyle(color: P.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final t in tiposUsados.take(4))
                    Padding(padding: const EdgeInsets.only(right: 6), child: BarraTipo(t, alto: 28)),
                  const Spacer(),
                  Text(
                    '${tareas.length} ${tareas.length == 1 ? 'tarea' : 'tareas'}',
                    style: TextStyle(color: P.textoSuave, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (vencidas > 0) ...[
                    const SizedBox(width: 8),
                    Pill('$vencidas vencida${vencidas == 1 ? '' : 's'}', P.rojo),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista estilo Holded: tabla densa con avatar cuadrado de color y estado en pastilla sólida.
class _Tabla extends StatelessWidget {
  final List<Cliente> clientes;
  final ValueChanged<String> onAbrir;
  final Set<String>? seleccion;

  /// Entra o sale del modo selección (botón de la cabecera, a la izquierda de "Nombre").
  final VoidCallback onModo;
  const _Tabla(this.clientes, this.onAbrir, {this.seleccion, required this.onModo, super.key});

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => (box.maxWidth > 980, box.maxWidth > 600),
    builder: (context, box) {
      final ancho = box.maxWidth > 980;
      // Móvil: solo nombre y estado.
      final medio = box.maxWidth > 600;
      return Align(
        alignment: Alignment.topCenter,
        child: Tabla(
          seleccionCabecera: BotonSeleccionLista(activo: seleccion != null, onTap: onModo),
          columnas: [
            if (seleccion != null) const Col('', ancho: 36, cabecera: SizedBox()),
            const Col('Nombre', flex: 4),
            if (ancho) const Col('CIF/NIF', flex: 2),
            if (medio) const Col('Población', flex: 2),
            if (ancho) const Col('Contacto', flex: 3),
            if (medio) const Col('Tareas', flex: 2),
            if (medio) const Col('Próximo', flex: 2),
            const Col('Estado', ancho: 80, derecha: true),
          ],
          filas: clientes.length,
          onTap: (i) => onAbrir(clientes[i].id),
          pie: pieTabla(clientes.length, clientes.length == 1 ? 'cliente' : 'clientes'),
          celdas: (i) {
            final c = clientes[i];
            final tareas = store.tareasDe(c.id);
            final fechas = tareas.where((t) => t.proximo != null && t.activa).map((t) => t.proximo!).toList()..sort();
            final vencidas = fechas.where((d) => diasHasta(d) < 0).length;
            final tiposUsados = {for (final t in tareas) t.tipo}.take(4);
            return [
              if (seleccion != null) CirculoSeleccion(seleccion!.contains(c.id)),
              Row(
                children: [
                  Avatar(c.iniciales, colorPaleta(c.color), size: 26, cuadrado: true),
                  const SizedBox(width: 10),
                  Flexible(child: celdaTexto(c.nombre, negrita: true)),
                ],
              ),
              if (ancho) celdaTexto(c.cif, suave: true),
              if (medio) celdaTexto(c.ciudad),
              if (ancho)
                celdaTexto([c.contacto, c.telefonoContacto].where((x) => x.isNotEmpty).join(' · '), suave: true),
              if (medio)
                Row(
                  children: [
                    for (final tipo in tiposUsados)
                      Tooltip(
                        message: tipo,
                        child: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(color: tipoDe(tipo).color, shape: BoxShape.circle),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text('${tareas.length}', style: TextStyle(fontSize: 13, color: P.textoSuave)),
                  ],
                ),
              if (medio)
                fechas.isEmpty
                    ? celdaTexto('', suave: true)
                    : Text(
                        vencidas > 0 ? '$vencidas vencida${vencidas == 1 ? '' : 's'}' : relativo(fechas.first),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: vencidas > 0 ? FontWeight.w600 : FontWeight.w400,
                          color: vencidas > 0 ? P.rojo : P.texto,
                        ),
                      ),
              c.activa ? const Pill('Activo', P.verde, punto: true) : const Pill('Inactivo', P.gris, punto: true),
            ];
          },
        ),
      );
    },
  );
}
