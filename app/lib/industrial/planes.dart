import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'gravedad.dart';
import 'plan.dart';
import 'tipo_mantenimiento.dart';

/// Próximo de un mantenimiento: el puesto a mano o, si va por horas, estimado con el contador y el ritmo de uso
/// de su activo o componente.
DateTime? proximoPlan(PlanMantenimiento p) {
  if (p.proximo != null || p.cadaHoras == null) return p.proximo;
  final a = store.activo(p.activoId);
  if (a == null || a.usoDiario <= 0) return null;
  final quedan = p.cadaHoras! - (a.horas - (p.ultimoHoras ?? 0));
  if (quedan <= 0) return a.fechaLectura;
  final dias = (quedan / a.usoDiario).ceil();
  if (dias > 3652500) return null;
  return masDias(a.fechaLectura, dias);
}

/// Horas que le quedan a un mantenimiento por horas, con el contador de su activo o componente.
double? horasRestantesPlan(PlanMantenimiento p) {
  final a = store.activo(p.activoId);
  if (p.cadaHoras == null || a == null) return null;
  return p.cadaHoras! - (a.horas - (p.ultimoHoras ?? 0));
}

/// Lista de mantenimientos en tabla, como la de componentes: qué es (con su breve descripción), cada cuánto,
/// horas que quedan, próximo y a quién se asigna. Asignar a un técnico crea su OT.
class TablaPlanes extends StatefulWidget {
  final List<PlanMantenimiento> planes;

  /// Id del activo abierto: los de sus componentes llevan delante su código.
  final String activoId;
  const TablaPlanes(this.planes, {super.key, required this.activoId});

  @override
  State<TablaPlanes> createState() => _TablaPlanesState();
}

class _TablaPlanesState extends State<TablaPlanes> {
  /// Borradores de OT de los mantenimientos aún sin asignar, para el selector de técnicos.
  final _borradores = <String, Tarea>{};

  /// Columnas opcionales, en su orden, y las que se ven (se recuerdan mientras dure la sesión).
  static const _opcionales = [
    'Código',
    'Componente',
    'Tipo',
    'Cada cuánto',
    'Horas restantes',
    'Próximo',
    'Último hecho',
    'Categoría',
    'Duración',
    'Repuestos',
    'Orden de trabajo',
    'Asignado a',
  ];
  static const _porDefecto = {'Código', 'Cada cuánto', 'Horas restantes', 'Próximo', 'Asignado a'};
  static final _visibles = {..._porDefecto};

  static const _cols = {
    'Código': Col('Código', flex: 2),
    'Componente': Col('Componente', flex: 2),
    'Tipo': Col('Tipo', ancho: 170),
    'Cada cuánto': Col('Cada cuánto', flex: 2),
    'Horas restantes': Col('Horas restantes', ancho: 130, derecha: true),
    'Próximo': Col('Próximo', ancho: 140),
    'Último hecho': Col('Último hecho', ancho: 120),
    'Categoría': Col('Categoría', flex: 2),
    'Duración': Col('Duración', ancho: 100),
    'Repuestos': Col('Repuestos', flex: 3),
    'Orden de trabajo': Col('Orden de trabajo', ancho: 140),
    'Asignado a': Col('Asignado a', ancho: 96),
  };

  /// Botón de la última columna: menú con todas las columnas para marcar o desmarcar.
  Widget _menuColumnas() => MenuAnchor(
    alignmentOffset: const Offset(-200, 4),
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(P.superficie),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    menuChildren: [
      MenuItemButton(
        onPressed: null,
        child: Text('Columnas', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
      ),
      for (final c in _opcionales)
        MenuItemButton(
          closeOnActivate: false,
          leadingIcon: Icon(
            _visibles.contains(c) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 20,
            color: _visibles.contains(c) ? P.morado : P.textoSuave,
          ),
          onPressed: () => setState(() => _visibles.contains(c) ? _visibles.remove(c) : _visibles.add(c)),
          child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 160), child: Text(c)),
        ),
      const Divider(height: 8),
      MenuItemButton(
        closeOnActivate: false,
        leadingIcon: Icon(Icons.restart_alt_rounded, size: 20, color: P.textoSuave),
        onPressed: () => setState(
          () => _visibles
            ..clear()
            ..addAll(_porDefecto),
        ),
        child: const Text('Volver a las de por defecto'),
      ),
    ],
    builder: (context, menu, _) => IconButton(
      tooltip: 'Elegir columnas',
      visualDensity: VisualDensity.compact,
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      icon: Icon(Icons.view_column_outlined, size: 18, color: P.textoSuave),
    ),
  );

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => box.maxWidth > 600,
    builder: (context, box) {
      // Móvil: solo el mantenimiento y el próximo.
      final medio = box.maxWidth > 600;
      final ps = widget.planes;
      // Una pasada por activos y OT para toda la tabla: por fila, cada búsqueda recorría las listas enteras
      // y el scroll se notaba con muchos mantenimientos.
      final nodos = {for (final a in store.activos) a.id: a};
      final ids = {for (final p in ps) p.activoId};
      final ots = <String, Tarea>{
        for (final t in store.tareas)
          if (!t.esPlantilla && t.activa && ids.contains(t.activoId) && otPendiente(t)) '${t.activoId}|${t.nombre}': t,
      };
      final proximos = {for (final p in ps) p.id: proximoPlan(p)};
      final vistas = [
        for (final c in _opcionales)
          if (medio ? _visibles.contains(c) : c == 'Próximo') c,
      ];
      final columnas = [
        const Col('Mantenimiento', flex: 4),
        for (final c in vistas) _cols[c]!,
        if (medio) Col('Columnas', ancho: 40, derecha: true, cabecera: _menuColumnas()),
      ];
      // Con muchas columnas marcadas no caben: la tabla se desplaza en horizontal en vez de desbordar.
      final necesario = 36 + columnas.fold<double>(0, (s, c) => s + (c.ancho ?? 110.0 * c.flex));
      final anchoTabla = necesario > box.maxWidth ? necesario : box.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: anchoTabla,
          child: Align(
            alignment: Alignment.topCenter,
            child: Tabla(
              columnas: columnas,
              filas: ps.length,
              onTap: (i) => abrirPlanForm(context, activoId: ps[i].activoId, original: ps[i]),
              pie: pieTabla(ps.length, ps.length == 1 ? 'mantenimiento' : 'mantenimientos'),
              celdas: (i) {
                final p = ps[i];
                final nodo = nodos[p.activoId];
                final d = proximos[p.id];
                final otPendienteDe = ots['${p.activoId}|${p.nombre}'];
                Widget celda(String c) {
                  switch (c) {
                    case 'Código':
                      return celdaTexto(nodo == null ? '—' : (nodo.tag.isEmpty ? nodo.nombre : nodo.tag), suave: true);
                    case 'Componente':
                      return celdaTexto(nodo?.nombre ?? '—', suave: true);
                    case 'Tipo':
                      return PillTipo(p.tipo);
                    case 'Cada cuánto':
                      return celdaTexto(p.cada.isEmpty ? (p.proximo == null ? '—' : 'Una vez') : p.cada, suave: true);
                    case 'Horas restantes':
                      final h = horasRestantesPlan(p);
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: celdaTexto(h == null ? '—' : '≈ ${h <= 0 ? 0 : h.toStringAsFixed(0)} h', suave: true),
                      );
                    case 'Próximo':
                      final vencido = d != null && d.isBefore(hoy());
                      return Text(
                        d == null ? '—' : '${p.proximo == null ? '≈ ' : ''}${fecha(d)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: vencido ? P.rojo : P.textoSuave,
                          fontWeight: vencido ? FontWeight.w600 : FontWeight.w400,
                        ),
                      );
                    case 'Último hecho':
                      return celdaTexto(p.ultimo == null ? '—' : fecha(p.ultimo!), suave: true);
                    case 'Categoría':
                      return celdaTexto(p.categoria.isEmpty ? 'Cualquiera' : p.categoria, suave: true);
                    case 'Duración':
                      return celdaTexto(duracion(p.duracionMin), suave: true);
                    case 'Repuestos':
                      return celdaTexto(p.repuestos.isEmpty ? '—' : p.repuestos, suave: true);
                    case 'Orden de trabajo':
                      return otPendienteDe == null
                          ? celdaTexto('Sin crear', suave: true)
                          : Pill(
                              otPendienteDe.trabajadorIds.isEmpty ? 'Sin técnico' : 'Asignada',
                              P.morado,
                              punto: true,
                            );
                    default:
                      final ot = otPendienteDe ?? _borradores.putIfAbsent(p.id, () => p.ot(store.nuevoId()));
                      return SelectorTrabajadores(ot, () {
                        // La primera asignación crea la OT; luego se edita la misma.
                        store.guardarTarea(ot);
                        setState(() => _borradores.remove(p.id));
                      }, compacto: true);
                  }
                }

                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Tooltip(message: p.tipo.etiqueta, child: puntoTipo(p.tipo.color)),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              celdaTexto(p.nombre.isEmpty ? 'Sin nombre' : p.nombre, negrita: true),
                              if (p.descripcion.isNotEmpty)
                                Text(
                                  p.descripcion,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: P.textoSuave, height: 1.35),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final c in vistas) celda(c),
                  if (medio) const SizedBox(),
                ];
              },
            ),
          ),
        ),
      );
    },
  );
}

Future<void> abrirPlanForm(BuildContext context, {required String activoId, PlanMantenimiento? original}) =>
    abrirPanel(context, PlanForm(activoId: activoId, original: original));

/// Alta y edición de un mantenimiento periódico de un activo o componente.
class PlanForm extends StatefulWidget {
  final String activoId;
  final PlanMantenimiento? original;
  const PlanForm({super.key, required this.activoId, this.original});

  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  late final PlanMantenimiento p =
      widget.original?.copia() ?? PlanMantenimiento(id: store.nuevoId(), activoId: widget.activoId);
  late final nombre = TextEditingController(text: p.nombre)..addListener(() => setState(() {}));
  late final dias = TextEditingController(text: p.cadaDias?.toString() ?? '')..addListener(_alCambiarDias);
  late final horasC = TextEditingController(text: p.cadaHoras?.toString() ?? '')..addListener(() => setState(() {}));
  late final contador = TextEditingController(text: p.ultimoHoras == null ? '' : '${p.ultimoHoras}');
  late final descripcion = TextEditingController(text: p.descripcion);
  late final repuestos = TextEditingController(text: p.repuestos);
  late final procedimiento = TextEditingController(text: p.procedimiento);
  bool intentoGuardar = false;

  /// Cómo se programa: 0 = cada N días, 1 = cada N horas de uso, 2 = una fecha concreta.
  late int modo = p.cadaHoras != null
      ? 1
      : p.cadaDias == null && p.proximo != null
      ? 2
      : 0;
  static const _modos = ['Días', 'Horas de uso', 'Fecha concreta'];

  int? _entero(TextEditingController c) {
    final n = int.tryParse(c.text.trim());
    return n == null || n <= 0 ? null : n;
  }

  /// Con el último hecho, el próximo sale solo al cambiar cada cuántos días.
  void _alCambiarDias() => setState(() {
    final n = _entero(dias);
    if (p.ultimo != null && n != null) p.proximo = masDias(p.ultimo!, n);
  });

  String? get errorNombre => intentoGuardar && nombre.text.trim().isEmpty ? 'Ponle un nombre' : null;
  String? get errorCada =>
      intentoGuardar &&
          switch (modo) {
            0 => _entero(dias) == null,
            1 => _entero(horasC) == null,
            _ => p.proximo == null,
          }
      ? (modo == 2 ? 'Elige la fecha' : 'Cada cuánto toca')
      : null;

  void guardar() {
    setState(() => intentoGuardar = true);
    if (errorNombre != null || errorCada != null) return;
    p
      ..nombre = nombre.text.trim()
      ..descripcion = descripcion.text.trim()
      ..cadaDias = modo == 0 ? _entero(dias) : null
      ..cadaHoras = modo == 1 ? _entero(horasC) : null
      ..ultimoHoras = double.tryParse(contador.text.trim().replaceAll(',', '.'))
      ..repuestos = repuestos.text.trim()
      ..procedimiento = procedimiento.text.trim();
    store.guardarPlan(p);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existe = widget.original != null;
    return VentanaFormulario(
      etiqueta: store.activo(p.activoId)?.titulo ?? 'Activo',
      titulo: existe ? 'Editar mantenimiento' : 'Nuevo mantenimiento',
      tituloDesplazado: nombre.text,
      bajoBotones: MenuTipoMantenimiento(p.tipo, (t) => setState(() => p.tipo = t)),
      onGuardar: guardar,
      avisos: [
        if (errorNombre != null) ('Te falta el nombre', () {}),
        if (errorCada != null) ('Te falta cada cuánto toca', () {}),
      ],
      onBorrar: !existe
          ? null
          : () async {
              final nav = Navigator.of(context);
              if (await confirmar(context, '¿Eliminar el mantenimiento ${p.nombre}? Sus OT se quedan.')) {
                store.borrarPlan(p.id);
                nav.pop();
              }
            },
      campos: [
        Bloque('Mantenimiento', primero: true, descripcion: 'Qué hay que hacer en este componente.', [
          campo('Nombre', nombre, hint: 'Cambio de aceite', error: errorNombre, obligatorio: true),
          campo('Breve descripción', descripcion, hint: 'Vaciar, cambiar filtro y rellenar'),
        ]),
        Bloque(
          'Cada cuánto',
          descripcion: 'Por días, por horas de uso o en una fecha. Por horas, sin próximo, se estima con el contador.',
          [
            dos(
              conMargen(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    etiqueta('Programar por'),
                    BotonMenu<int>(
                      relleno: EdgeInsets.zero,
                      tooltip: 'Cómo se programa el mantenimiento',
                      seleccionado: modo,
                      opciones: [for (final (i, m) in _modos.indexed) (i, Text(m))],
                      onSelected: (m) => setState(() => modo = m),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          suffixIcon: Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave),
                        ),
                        child: Text(_modos[modo]),
                      ),
                    ),
                  ],
                ),
              ),
              switch (modo) {
                0 => campo('Cada cuántos días', dias, hint: '90', error: errorCada, obligatorio: true),
                1 => campo('Cada cuántas horas', horasC, hint: '500', error: errorCada, obligatorio: true),
                _ => CampoFecha('Fecha', p.proximo, (d) => setState(() => p.proximo = d)),
              },
            ),
            const SizedBox(height: 16),
            dos(
              CampoFecha('Último hecho', p.ultimo, (d) {
                p.ultimo = d;
                _alCambiarDias();
              }, hasta: hoy()),
              modo == 2 ? const SizedBox() : CampoFecha('Próximo', p.proximo, (d) => setState(() => p.proximo = d)),
            ),
            dos(
              campo(
                'Contador en el último (h)',
                contador,
                teclado: const TextInputType.numberWithOptions(decimal: true),
                hint: '0',
              ),
              const SizedBox(),
            ),
          ],
        ),
        Bloque('Quién y cuánto', descripcion: 'Solo los técnicos de esta categoría pueden recibir la OT.', [
          dos(
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiqueta('Categoría de técnico'),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: p.categoria,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Cualquiera')),
                      for (final c in {...competencias, if (p.categoria.isNotEmpty) p.categoria})
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (c) => setState(() => p.categoria = c!),
                  ),
                ],
              ),
            ),
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiqueta('Duración'),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: p.duracionMin,
                    items: [
                      for (final m in {...duraciones, p.duracionMin}.toList()..sort())
                        DropdownMenuItem(value: m, child: Text(duracion(m))),
                    ],
                    onChanged: (m) => setState(() => p.duracionMin = m!),
                  ),
                ],
              ),
            ),
          ),
        ]),
        Bloque('Repuestos', descripcion: 'Piezas y consumibles que hacen falta.', [
          campo('Repuestos', repuestos, hint: 'Filtro de aceite, 12 l de aceite 15W40…', lineas: 3),
        ]),
        Bloque('Procedimiento', descripcion: 'Los pasos, para que cualquier técnico lo haga igual.', [
          campo('Procedimiento', procedimiento, lineas: 5),
        ]),
      ],
    );
  }
}
