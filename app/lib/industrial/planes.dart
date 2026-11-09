import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'gravedad.dart';
import 'activo.dart';
import 'plan.dart';

/// Próximo de un mantenimiento: el puesto a mano o, si va por horas, estimado con el contador y el ritmo de uso
/// de su activo o componente.
/// Activo principal (sin padre) del que cuelga un activo o componente: su contador es el de todos.
Activo? raizActivo(String? id) {
  var a = id == null ? null : store.activo(id);
  while (a?.padreId != null) {
    final p = store.activo(a!.padreId!);
    if (p == null) break;
    a = p;
  }
  return a;
}

String _dia(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Turnos marcados para un día en el calendario de uso (0 = no trabaja).
int turnosDe(Activo r, DateTime d) => r.turnos[_dia(d)] ?? 0;

void ponerTurnos(Activo r, DateTime d, int n) => n <= 0 ? r.turnos.remove(_dia(d)) : r.turnos[_dia(d)] = n;

/// Horas de hoy: las del activo principal. Uso planificado: la lectura más los turnos marcados desde entonces;
/// si no, la lectura más el ritmo de uso por los días pasados.
double horasHoy(Activo a) {
  final r = raizActivo(a.id) ?? a;
  final desde = r.fechaLectura;
  if (r.usoPlanificado) {
    var t = 0;
    for (var d = masDias(desde, 1); !d.isAfter(hoy()); d = masDias(d, 1)) {
      t += turnosDe(r, d);
    }
    return r.horas + t * r.horasTurno;
  }
  return r.horas + r.usoDiario * diasHasta(desde).abs().clamp(0, 36500);
}

/// Cuándo toca un mantenimiento: su fecha o, por horas, la estimada con el uso de su activo principal
/// (planificado: el primer día del calendario en que se alcanzan las horas; null si no llega a planificarse).
DateTime? proximoPlan(PlanMantenimiento p) {
  if (p.proximo != null) return p.proximo;
  // Por días sin próximo: desde el último (o desde hoy). La base estima igual (`private.proximo_estimado`).
  if (p.cadaDias != null) return masDias(p.ultimo ?? hoy(), p.cadaDias!);
  if (p.cadaHoras == null) return null;
  final a = store.activo(p.activoId);
  if (a == null) return null;
  final r = raizActivo(a.id) ?? a;
  var quedan = p.cadaHoras! - (horasHoy(a) - (p.ultimoHoras ?? 0));
  if (quedan <= 0) return hoy();
  if (r.usoPlanificado) {
    for (var d = masDias(hoy(), 1), i = 0; i < 400; d = masDias(d, 1), i++) {
      quedan -= turnosDe(r, d) * r.horasTurno;
      if (quedan <= 0) return d;
    }
    return null;
  }
  if (r.usoDiario <= 0) return null;
  final dias = (quedan / r.usoDiario).ceil();
  if (dias > 3652500) return null;
  return masDias(hoy(), dias);
}

/// Horas que le quedan a un mantenimiento por horas, con el contador de su activo principal.
double? horasRestantesPlan(PlanMantenimiento p) {
  final a = store.activo(p.activoId);
  if (p.cadaHoras == null || a == null) return null;
  return p.cadaHoras! - (horasHoy(a) - (p.ultimoHoras ?? 0));
}

/// Lista de mantenimientos en tabla, como la de componentes: qué es (con su breve descripción), cada cuánto,
/// horas que quedan, próximo y a quién se asigna. Asignar a un técnico crea su OT.
/// «+ Crear orden» de un mantenimiento: botón pequeño azul con fondo suave (en el activo y en Inicio).
class BotonCrearOrden extends StatelessWidget {
  final VoidCallback onPressed;
  const BotonCrearOrden(this.onPressed, {super.key});

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: P.morado,
      backgroundColor: P.morado.withValues(alpha: .07),
      overlayColor: P.morado,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      minimumSize: const Size(0, 30),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
    ),
    onPressed: onPressed,
    // El «+» pegado al texto.
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(Icons.add_rounded, size: 16), SizedBox(width: 3), Text('Crear orden')],
    ),
  );
}

/// Mantenimiento que se abrió desde Inicio: su fila sale con el borde del color de su criticidad.
final planDestacado = ValueNotifier<String?>(null);

/// Misma asociación para la columna de OT y los filtros de asignación.
Map<String, Tarea> ordenesPendientesDePlanes(Iterable<PlanMantenimiento> planes) {
  final ids = planes.map((p) => p.activoId).toSet();
  return {
    for (final t in store.tareas)
      if (!t.esPlantilla && t.activa && ids.contains(t.activoId) && otPendiente(t))
        t.planId ?? '${t.activoId}|${t.nombre}': t,
  };
}

class TablaPlanes extends StatefulWidget {
  final List<PlanMantenimiento> planes;

  /// Id del activo abierto: los de sus componentes llevan delante su código.
  final String activoId;
  const TablaPlanes(this.planes, {super.key, required this.activoId});

  @override
  State<TablaPlanes> createState() => _TablaPlanesState();
}

class _TablaPlanesState extends State<TablaPlanes> {
  /// Columnas opcionales, en su orden, y las que se ven (se recuerdan mientras dure la sesión).
  static const _opcionales = [
    'Código',
    'Orden de trabajo',
    // 'Prioridad', // Aparcada para el futuro.
    'Fecha',
    'Cada cuánto',
    'Horas restantes',
    'Componente',
    'Último hecho',
    'Categoría',
    'Duración',
    'Repuestos',
  ];
  static const _porDefecto = {'Código', 'Cada cuánto', 'Horas restantes', 'Fecha', 'Orden de trabajo'};
  static final _visibles = {..._porDefecto};

  static const _cols = {
    'Código': Col('Código', ancho: 130),
    'Componente': Col('Componente', flex: 2),
    'Prioridad': Col('Prioridad', ancho: 150),
    'Cada cuánto': Col('Cada cuánto', ancho: 120),
    'Horas restantes': Col('Horas restantes', ancho: 120, derecha: true),
    'Fecha': Col('Fecha', ancho: 140),
    'Último hecho': Col('Último hecho', ancho: 120),
    'Categoría': Col('Categoría', flex: 2),
    'Duración': Col('Duración', ancho: 100),
    'Repuestos': Col('Repuestos', flex: 3),
    'Orden de trabajo': Col('Orden de trabajo', ancho: 230),
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
      final ots = ordenesPendientesDePlanes(ps);
      final proximos = {for (final p in ps) p.id: proximoPlan(p)};
      final vistas = [
        for (final c in _opcionales)
          if (medio ? _visibles.contains(c) : c == 'Fecha') c,
      ];
      final columnas = [
        const Col('Mantenimiento', flex: 4),
        for (final c in vistas) _cols[c]!,
        if (medio) Col('Columnas', ancho: 40, derecha: true, cabecera: _menuColumnas()),
      ];
      // Con muchas columnas marcadas no caben: la tabla se desplaza en horizontal en vez de desbordar.
      final necesario = 36 + columnas.fold<double>(0, (s, c) => s + (c.ancho ?? 70.0 * c.flex));
      return DesplazarTabla(
        ancho: necesario,
        child: Align(
          alignment: Alignment.topCenter,
          child: Tabla(
            columnas: columnas,
            filas: ps.length,
            onTap: (i) => abrirPlanForm(context, activoId: ps[i].activoId, original: ps[i]),
            pie: pieTabla(ps.length, ps.length == 1 ? 'mantenimiento' : 'mantenimientos'),
            resaltar: (i) => ps[i].id == planDestacado.value ? P.morado : null,
            celdas: (i) {
              final p = ps[i];
              final nodo = nodos[p.activoId];
              final d = proximos[p.id];
              final otPendienteDe = ots[p.id] ?? ots['${p.activoId}|${p.nombre}'];
              Widget celda(String c) {
                switch (c) {
                  case 'Código':
                    return celdaTexto(nodo == null ? '—' : (nodo.tag.isEmpty ? nodo.nombre : nodo.tag), suave: true);
                  case 'Componente':
                    return celdaTexto(nodo?.nombre ?? '—', suave: true);
                  case 'Prioridad':
                    return Tooltip(
                      message: p.prioridad.descripcion,
                      child: Pill(p.prioridad.etiqueta, p.prioridad.color, punto: true),
                    );
                  case 'Cada cuánto':
                    return celdaTexto(p.cada.isEmpty ? (p.proximo == null ? '—' : 'Una vez') : p.cada, suave: true);
                  case 'Horas restantes':
                    final h = horasRestantesPlan(p);
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: celdaTexto(h == null ? '—' : '≈ ${h <= 0 ? 0 : h.toStringAsFixed(0)} h', suave: true),
                    );
                  case 'Fecha':
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
                    // El técnico es de la orden, no del mantenimiento. La orden la crea la base sola al guardar
                    // el mantenimiento: si aún no ha llegado, se espera.
                    if (otPendienteDe == null) return celdaTexto('Creando orden…', suave: true);
                    final f = otPendienteDe.proximo;
                    final vencida = f != null && diasHasta(f) < 0;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => abrirTareaForm(context, otPendienteDe),
                            child: Pill(
                              [vencida ? 'Vencida' : 'Pendiente', if (f != null) fecha(f)].join(' '),
                              vencida ? P.rojo : P.morado,
                              punto: true,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectorTrabajadores(
                            otPendienteDe,
                            () {
                              store.guardarTarea(otPendienteDe);
                              if (mounted) setState(() {});
                            },
                            textoSinAsignar: 'Sin técnico',
                            reducido: true,
                          ),
                        ],
                      ),
                    );
                  default:
                    return const SizedBox();
                }
              }

              return [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 6), child: iconoAsignacion(otPendienteDe)),
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
  late final contador = TextEditingController(text: p.ultimoHoras == null ? '' : '${p.ultimoHoras}')
    ..addListener(() => setState(() {}));
  late final descripcion = TextEditingController(text: p.descripcion);
  late final repuestos = TextEditingController(text: p.repuestos);
  late final procedimiento = TextEditingController(text: p.procedimiento);
  late final avisoDias = TextEditingController(text: p.avisoDias?.toString() ?? '');
  late final avisoCorreos = TextEditingController(text: p.avisoCorreos);
  late final preparar = TextEditingController(text: p.preparar);
  late final empresaExterna = TextEditingController(text: p.empresaExterna);
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

  double? _horasActivo() {
    final a = store.activo(p.activoId);
    return a == null ? null : horasHoy(a);
  }

  /// Cuándo tocará con lo que hay escrito ahora: «≈ 07/02/2027 · en 90 días (estimado)», en tono neutro.
  String? get estimacion {
    if (modo == 2) return null;
    final prueba = p.copia()
      ..cadaDias = modo == 0 ? _entero(dias) : null
      ..cadaHoras = modo == 1 ? _entero(horasC) : null
      ..ultimoHoras = double.tryParse(contador.text.trim().replaceAll(',', '.')) ?? (modo == 1 ? _horasActivo() : null);
    if (prueba.cadaDias == null && prueba.cadaHoras == null) return null;
    final d = proximoPlan(prueba);
    if (d == null) return modo == 1 ? 'Sin estimación: falta el ritmo de uso del activo' : null;
    return '≈ ${fecha(d)}, ${relativo(d).toLowerCase()} (estimado)';
  }

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
      // Por horas sin contador en el último: cuenta desde las horas de hoy (si no, tocaría ya).
      ..ultimoHoras = double.tryParse(contador.text.trim().replaceAll(',', '.')) ?? (modo == 1 ? _horasActivo() : null)
      ..repuestos = repuestos.text.trim()
      ..procedimiento = procedimiento.text.trim()
      ..avisoDias = _entero(avisoDias)
      ..avisoCorreos = avisoCorreos.text.trim()
      ..preparar = preparar.text.trim()
      ..empresaExterna = p.subcontratado ? empresaExterna.text.trim() : '';
    store.guardarPlan(p);
    // Su OT pendiente aún sin técnico recibe la asignación nueva (las siguientes ya las asigna la base).
    final ot = store.tareas.where((t) => t.planId == p.id && t.activa && otPendiente(t)).firstOrNull;
    if (ot != null && ot.trabajadorIds.isEmpty && (p.trabajadorId != null || p.grupoId != null)) {
      final c = ot.copia();
      if (p.trabajadorId != null) {
        c
          ..trabajadorIds = [p.trabajadorId!]
          ..grupoId = null;
      } else {
        store.asignarAGrupo(c, p.grupoId!);
      }
      store.guardarTarea(c);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existe = widget.original != null;
    return VentanaFormulario(
      etiqueta: store.activo(p.activoId)?.titulo ?? 'Activo',
      titulo: existe ? 'Editar mantenimiento' : 'Nuevo mantenimiento',
      tituloDesplazado: nombre.text,
      // Futuro: bajoBotones: MenuPrioridadMantenimiento(p.prioridad, (t) => setState(() => p.prioridad = t)),
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
            if (estimacion case final e?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(e, style: TextStyle(fontSize: 13, color: P.textoSuave)),
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
        Bloque('Quién y cuánto', descripcion: 'A quién va su orden de trabajo (un técnico o un grupo) y cuánto dura.', [
          // Asignar a y duración en una fila (sin categoría: el grupo ya dice quién lo hace).
          dos(
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiqueta('Asignar a'),
                  SelectorAsignacionPlan(
                    trabajadorId: p.trabajadorId,
                    grupoId: p.grupoId,
                    onChanged: (w, g) => setState(() {
                      p.trabajadorId = w;
                      p.grupoId = g;
                    }),
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
        Bloque(
          'Preparación',
          descripcion: 'Aviso previo para tener a tiempo grúas, repuestos complejos o personal cualificado o externo.',
          [
            dos(
              campo('Avisar con antelación (días)', avisoDias, hint: 'Sin aviso', teclado: TextInputType.number),
              campo('A quién avisar', avisoCorreos, hint: 'Correos separados por comas · vacío = administradores'),
            ),
            campo('Qué preparar', preparar, hint: 'Grúa de 20 t, kit de válvula, técnico de alta tensión…', lineas: 2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: p.subcontratado,
              onChanged: (v) => setState(() => p.subcontratado = v),
              title: const Text('Lo hace una empresa externa'),
              subtitle: Text(
                'Su OT no se asigna a los técnicos de la casa.',
                style: TextStyle(fontSize: 12.5, color: P.textoSuave),
              ),
            ),
            if (p.subcontratado) campo('Empresa externa y contacto', empresaExterna, hint: 'Grúas Norte · 600 000 000'),
          ],
        ),
      ],
    );
  }
}

/// «Asignar a» del mantenimiento, con la misma forma que el desplegable de técnicos: primero los grupos (cada uno
/// abre «Repartir en el grupo» y sus técnicos), luego los técnicos sin grupo. Uno solo, o nadie.
class SelectorAsignacionPlan extends StatelessWidget {
  final String? trabajadorId, grupoId;
  final void Function(String? trabajadorId, String? grupoId) onChanged;
  const SelectorAsignacionPlan({super.key, this.trabajadorId, this.grupoId, required this.onChanged});

  Widget _marca(bool si) => Icon(
    si ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
    size: 20,
    color: si ? P.morado : P.textoSuave,
  );

  Widget _tecnico(Trabajador w) => MenuItemButton(
    leadingIcon: _marca(trabajadorId == w.id),
    onPressed: () => onChanged(w.id, null),
    child: Row(
      children: [
        Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 22),
        const SizedBox(width: 8),
        Text(w.nombreCompleto),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ws = store.trabajadores.where((w) => w.activo).toList()..sort((a, b) => a.nombre.compareTo(b.nombre));
    final grupos = [...store.grupos]..sort((a, b) => a.nombre.compareTo(b.nombre));
    final sueltos = ws.where((w) => store.grupo(w.grupoId) == null).toList();
    final g = store.grupo(grupoId);
    final w = trabajadorId == null ? null : store.trabajador(trabajadorId!);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(P.superficie),
        maximumSize: const WidgetStatePropertyAll(Size(420, 420)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: _marca(w == null && g == null),
          onPressed: () => onChanged(null, null),
          child: const Text('Sin asignar'),
        ),
        if (grupos.isNotEmpty) const Divider(height: 8),
        for (final x in grupos)
          SubmenuButton(
            menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(P.superficie)),
            menuChildren: [
              MenuItemButton(
                leadingIcon: _marca(grupoId == x.id),
                onPressed: () => onChanged(null, x.id),
                child: const Text('Repartir en el grupo'),
              ),
              const Divider(height: 8),
              if (store.tecnicosDe(x.id).isEmpty)
                MenuItemButton(
                  onPressed: null,
                  child: Text('Sin técnicos', style: TextStyle(color: P.textoSuave)),
                )
              else
                for (final t in store.tecnicosDe(x.id)) _tecnico(t),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: Row(
                children: [
                  Text(x.nombre, style: TextStyle(fontWeight: grupoId == x.id ? FontWeight.w700 : FontWeight.w500)),
                  if (x.area.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(x.area, style: TextStyle(color: P.textoSuave)),
                  ],
                ],
              ),
            ),
          ),
        if (sueltos.isNotEmpty) ...[const Divider(height: 8), for (final t in sueltos) _tecnico(t)],
        const Divider(height: 8),
        // Crear un grupo aquí mismo y dejarlo elegido.
        MenuItemButton(
          leadingIcon: Icon(Icons.add_rounded, size: 20, color: P.morado),
          onPressed: () async {
            final nuevo = await crearGrupoRapido(context);
            if (nuevo != null) onChanged(null, nuevo.id);
          },
          child: Text(
            'Nuevo grupo',
            style: TextStyle(color: P.morado, fontWeight: FontWeight.w600),
          ),
        ),
      ],
      builder: (context, menu, _) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        child: InputDecorator(
          decoration: InputDecoration(suffixIcon: Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave)),
          child: Text(
            w != null
                ? w.nombreCompleto
                : g != null
                ? '${g.nombre}, se reparte'
                : 'Sin asignar',
            style: TextStyle(color: w == null && g == null ? P.textoSuave : P.texto),
          ),
        ),
      ),
    );
  }
}
