import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../screens/informes.dart' show InformesDelTrabajo;
import 'gravedad.dart';
import 'iconos.dart';
import 'planes.dart' show raizActivo;
import 'tipo_mantenimiento.dart';

/// Una OT realizada: el día en que se hizo y la OT.
typedef Realizada = (DateTime, Tarea);

/// Todas las OT industriales realizadas (cada día de su historial cuenta una vez), de la más reciente a la
/// más antigua. El técnico es el que tiene asignada la OT: el historial guarda solo el día.
List<Realizada> otsRealizadas() => [
  for (final t in [...store.tareas, ...store.subtareas])
    // Sin mirar si es plantilla: una OT de un activo puede no tener cliente, y las plantillas no tienen historial.
    if (t.activoId != null || t.tipoMantenimiento != null)
      for (final d in {...t.historial, ?t.ultimo}) (d, t),
  // Las que no se pudieron hacer también cuentan en el historial (siguen pendientes, pero con aviso).
  for (final t in [...store.tareas, ...store.subtareas])
    if (t.resultado == 2 && t.ultimo == null) (t.proximo ?? hoy(), t),
]..sort((a, b) => b.$1.compareTo(a.$1));

/// Periodos del filtro de fecha, en días hacia atrás (null = todo).
const _periodos = <(String, int?)>[
  ('Todo', null),
  ('Últimos 30 días', 30),
  ('Últimos 3 meses', 91),
  ('Último año', 365),
];

/// Sección «Históricos» de Pultec: registro de las OT realizadas, filtrable por activo, técnico, tipo
/// y fecha. Arriba, cuántas hay de cada tipo (pulsar una filtra por ese tipo).
class Historicos extends StatefulWidget {
  final String? activoId;
  final bool incrustada;

  /// Solo las de este técnico (ficha del técnico).
  final String? tecnicoId;
  const Historicos({super.key, this.activoId, this.incrustada = false, this.tecnicoId});

  @override
  State<Historicos> createState() => _HistoricosState();
}

class _HistoricosState extends State<Historicos> {
  String? activoId, tecnicoId;
  TipoMantenimiento? tipo;
  int periodo = 2;

  /// Lo que pasa los filtros de activo, técnico y fecha (el de tipo va aparte para contar por tipo).
  List<Realizada> _filtradas() {
    final id = widget.activoId ?? activoId;
    final rama = id == null ? null : store.ramaDe(id);
    final dias = _periodos[periodo].$2;
    return otsRealizadas().where((r) {
      final (d, t) = r;
      if (rama != null && !rama.contains(t.activoId)) return false;
      final tec = widget.tecnicoId ?? tecnicoId;
      if (tec != null && t.ejecutadoPor != tec && !t.trabajadorIds.contains(tec)) return false;
      return dias == null || diasHasta(d) >= -dias;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final base = _filtradas();
    final lista = tipo == null ? base : base.where((r) => r.$2.tipoMantenimiento == tipo).toList();
    final activos = store.hijosDe(null);
    final tecnicos = store.trabajadores.where((w) => w.activo).toList();
    return Padding(
      padding: widget.incrustada ? EdgeInsets.zero : margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TituloVista(widget.incrustada ? 'Histórico' : 'Históricos'),
          const SizedBox(height: huecoVista),
          SegunTamano(
            clave: (box) => box.maxWidth > 1500,
            builder: (context, box) => SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12, runSpacing: 8,
                children: [
                  Pestanas(
                    opciones: ['Todos', for (final t in TipoMantenimiento.values)
                      '${const ['Preventivo', 'No crítico', 'Crítico'][t.index]} ${base.where((r) => r.$2.tipoMantenimiento == t).length}'],
                    colores: [null, for (final t in TipoMantenimiento.values) t.color],
                    anchosIguales: true,
                    seleccion: tipo == null ? 0 : tipo!.index + 1,
                    compactas: true,
                    onChanged: (i) => setState(() => tipo = i == 0 ? null : TipoMantenimiento.values[i - 1]),
                  ),
                  Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (box.maxWidth > 1500)
                      Pestanas(
                        opciones: [for (final p in _periodos) p.$1],
                        seleccion: periodo,
                        compactas: true,
                        onChanged: (i) => setState(() => periodo = i),
                      )
                    else
                      _Filtro<int>(
                        todos: _periodos.first.$1,
                        valor: periodo == 0 ? null : periodo,
                        opciones: [for (final (i, p) in _periodos.indexed.skip(1)) (i, p.$1)],
                        onChanged: (v) => setState(() => periodo = v ?? 0),
                      ),
                    if (widget.activoId == null)
                      _Filtro<String>(
                        todos: 'Todos los activos', valor: activoId,
                        opciones: [for (final a in activos) (a.id, a.titulo)],
                        onChanged: (v) => setState(() => activoId = v),
                      ),
                    _Filtro<String>(
                      todos: 'Todos los técnicos', valor: tecnicoId,
                      iconoOpcion: (id) => AvataresTrabajadores([id], size: 22),
                      opciones: [for (final w in tecnicos) (w.id, w.nombre)],
                      onChanged: (v) => setState(() => tecnicoId = v),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            child: lista.isEmpty
                ? Vacio(
                    icono: Icons.history_rounded,
                    titulo: otsRealizadas().isEmpty ? 'Aún no hay órdenes de trabajo realizadas' : null,
                    texto: otsRealizadas().isEmpty
                        ? 'Cada orden de trabajo que se marque como hecha quedará aquí registrada.'
                        : 'Ninguna orden de trabajo realizada con estos filtros',
                  )
                : _TablaRealizadas(lista),
          ),
        ],
      ),
    );
  }
}

class _TablaRealizadas extends StatelessWidget {
  final List<Realizada> lista;
  const _TablaRealizadas(this.lista);

  /// "CAM-01 · Camión › Motor": el activo y, si la OT es de un componente, el componente.
  String _activo(String? id) {
    final c = store.activo(id);
    if (c == null) return '—';
    var raiz = c;
    for (var p = store.activo(raiz.padreId); p != null; p = store.activo(p.padreId)) {
      raiz = p;
    }
    return raiz.id == c.id ? c.titulo : '${raiz.titulo} › ${c.nombre.isEmpty ? c.tag : c.nombre}';
  }

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => (box.maxWidth > 980, box.maxWidth > 600),
    builder: (context, box) {
      final medio = box.maxWidth > 600;
      return Align(alignment: Alignment.topCenter, child: Tabla(
        columnas: [
          const Col('Fecha', ancho: 120),
          const Col('Orden de trabajo', flex: 3),
          if (medio) const Col('Activo', flex: 5),
          if (medio) const Col('Ejecutado por', flex: 2),
          if (medio) const Col('Tipo', ancho: 190),
          const Col('Resultado', ancho: 170),
        ],
        filas: lista.length,
        celdas: (i) {
          final (d, t) = lista[i];
          final activo = store.activo(t.activoId);
          final ejecutores = t.ejecutadoPor != null ? [t.ejecutadoPor!] : t.trabajadorIds;
          final nombres = [for (final id in ejecutores) ?store.trabajador(id)?.nombre];
          return [
            celdaTexto(fecha(d), suave: true),
            Row(
              children: [
                if (!medio && t.tipoMantenimiento != null) ...[
                  puntoTipo(t.tipoMantenimiento!.color),
                  const SizedBox(width: 8),
                ],
                Expanded(child: celdaTexto(t.nombre.isEmpty ? t.tipo : t.nombre, negrita: true)),
              ],
            ),
            if (medio) Row(children: [
              if (activo != null) ...[
                IconoActivo(activo.icono, size: 22, color: P.textoSuave),
                const SizedBox(width: 8),
              ],
              Expanded(child: Tooltip(message: _activo(t.activoId),
                child: celdaTexto(_activo(t.activoId), suave: true))),
            ]),
            if (medio) Row(children: [
              if (nombres.isNotEmpty) ...[
                AvataresTrabajadores(ejecutores, size: 22),
                const SizedBox(width: 8),
              ],
              Expanded(child: celdaTexto(nombres.isEmpty ? '—' : nombres.join(', '), suave: true)),
            ]),
            if (medio)
              Align(
                alignment: Alignment.centerLeft,
                child: t.tipoMantenimiento == null ? celdaTexto('—', suave: true) : PillTipo(t.tipoMantenimiento!),
              ),
            // Verde si fue bien; ámbar con incidencia; rojo si no se pudo hacer.
            Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (_) {
                  final (texto, color) = resultadoOt(t);
                  return texto == 'Hecha'
                      ? Pill('Completado', P.verde, icono: Icons.check_circle_outline_rounded)
                      : Pill(texto, color, punto: true);
                },
              ),
            ),
          ];
        },
        // Lo hecho no se edita aquí: se ve la orden con su parte.
        onTap: (i) => verOrdenHecha(context, lista[i].$2),
        pie: pieTabla(lista.length, lista.length == 1 ? 'orden de trabajo realizada' : 'órdenes de trabajo realizadas'),
      ));
    },
  );
}

/// Desplegable de filtro: transparente con su valor por defecto; con un valor elegido, en morado suave.
class _Filtro<T> extends StatelessWidget {
  final String todos;
  final T? valor;
  final List<(T, String)> opciones;
  final ValueChanged<T?> onChanged;
  final Widget Function(T)? iconoOpcion;
  const _Filtro({required this.todos, required this.valor, required this.opciones, required this.onChanged, this.iconoOpcion});

  @override
  Widget build(BuildContext context) {
    final texto = opciones.where((o) => o.$1 == valor).firstOrNull?.$2 ?? todos;
    return BotonMenu<T?>(
      resaltarHover: false,
      relleno: EdgeInsets.zero,
      tooltip: todos,
      seleccionado: valor,
      onSelected: onChanged,
      opciones: [
        (null, Text(todos)),
        for (final (v, t) in opciones)
          (v, Row(mainAxisSize: MainAxisSize.min, children: [
            if (iconoOpcion != null) ...[iconoOpcion!(v), const SizedBox(width: 8)],
            Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ])),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(P.radioControl),
          border: Border.all(color: valor == null ? P.borde : P.morado.withValues(alpha: .4)),
          color: valor == null ? Colors.transparent : P.moradoSuave,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valor == null ? P.texto : P.morado),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: valor == null ? P.textoSuave : P.morado),
          ],
        ),
      ),
    );
  }
}

/// Una OT del histórico: activo, criticidad, resultado y sus partes (fotos, firma, PDF). Solo lectura.
Future<void> verOrdenHecha(BuildContext context, Tarea t) {
  final a = raizActivo(t.activoId);
  final (texto, color) = resultadoOt(t);
  return showDialog(
    context: context,
    builder: (c) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a?.titulo ?? 'Sin activo', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                        const SizedBox(height: 2),
                        Text(t.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (t.tipoMantenimiento != null) PillTipo(t.tipoMantenimiento!),
                  Pill(texto, color, punto: true),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(child: SingleChildScrollView(child: InformesDelTrabajo(t))),
            ],
          ),
        ),
      ),
    ),
  );
}
