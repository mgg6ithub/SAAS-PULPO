import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
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
]..sort((a, b) => b.$1.compareTo(a.$1));

/// Periodos del filtro de fecha, en días hacia atrás (null = todo).
const _periodos = <(String, int?)>[
  ('Últimos 30 días', 30),
  ('Últimos 3 meses', 91),
  ('Último año', 365),
  ('Todo', null),
];

/// Sección «Históricos» de iPultec: registro de las OT realizadas, filtrable por activo, técnico, tipo
/// y fecha. Arriba, cuántas hay de cada tipo (pulsar una filtra por ese tipo).
class Historicos extends StatefulWidget {
  final String? activoId;
  final bool incrustada;
  const Historicos({super.key, this.activoId, this.incrustada = false});

  @override
  State<Historicos> createState() => _HistoricosState();
}

class _HistoricosState extends State<Historicos> {
  String? activoId, tecnicoId;
  TipoMantenimiento? tipo;
  int periodo = 1;

  /// Lo que pasa los filtros de activo, técnico y fecha (el de tipo va aparte para contar por tipo).
  List<Realizada> _filtradas() {
    final id = widget.activoId ?? activoId;
    final rama = id == null ? null : store.ramaDe(id);
    final dias = _periodos[periodo].$2;
    return otsRealizadas().where((r) {
      final (d, t) = r;
      if (rama != null && !rama.contains(t.activoId)) return false;
      if (tecnicoId != null && !t.trabajadorIds.contains(tecnicoId)) return false;
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
          BarraVista(
            izquierda: [TituloVista(widget.incrustada ? 'Histórico' : 'Históricos')],
            derecha: [
              if (widget.activoId == null) _Filtro<String>(
                todos: 'Todos los activos',
                valor: activoId,
                opciones: [for (final a in activos) (a.id, a.titulo)],
                onChanged: (v) => setState(() => activoId = v),
              ),
              _Filtro<String>(
                todos: 'Todos los técnicos',
                valor: tecnicoId,
                opciones: [for (final w in tecnicos) (w.id, w.nombre)],
                onChanged: (v) => setState(() => tecnicoId = v),
              ),
              _Filtro<int>(
                todos: _periodos.last.$1,
                valor: periodo == _periodos.length - 1 ? null : periodo,
                opciones: [for (final (i, p) in _periodos.indexed.take(_periodos.length - 1)) (i, p.$1)],
                onChanged: (v) => setState(() => periodo = v ?? _periodos.length - 1),
              ),
            ],
          ),
          const SizedBox(height: huecoVista),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final x in TipoMantenimiento.values)
                _ChipCuenta(
                  x,
                  base.where((r) => r.$2.tipoMantenimiento == x).length,
                  sel: tipo == x,
                  onTap: () => setState(() => tipo = tipo == x ? null : x),
                ),
            ],
          ),
          const SizedBox(height: 14),
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
      return Tabla(
        columnas: [
          const Col('Fecha', ancho: 120),
          const Col('Orden de trabajo', flex: 3),
          if (medio) const Col('Activo', flex: 3),
          if (medio) const Col('Ejecutado por', flex: 2),
          if (medio) const Col('Tipo', ancho: 190),
        ],
        filas: lista.length,
        celdas: (i) {
          final (d, t) = lista[i];
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
            if (medio) celdaTexto(_activo(t.activoId), suave: true),
            if (medio)
              celdaTexto(
                // Quien la cerró (lo guarda la base); en las antiguas, los asignados.
                t.ejecutadoPor != null
                    ? store.trabajador(t.ejecutadoPor!)?.nombre ?? '—'
                    : t.trabajadorIds.isEmpty
                    ? '—'
                    : [for (final id in t.trabajadorIds) ?store.trabajador(id)?.nombre].join(', '),
                suave: true,
              ),
            if (medio)
              Align(
                alignment: Alignment.centerLeft,
                child: t.tipoMantenimiento == null ? celdaTexto('—', suave: true) : PillTipo(t.tipoMantenimiento!),
              ),
          ];
        },
        onTap: (i) => abrirTareaForm(context, lista[i].$2),
        pie: pieTabla(lista.length, lista.length == 1 ? 'orden de trabajo realizada' : 'órdenes de trabajo realizadas'),
      );
    },
  );
}

/// Cuántas OT realizadas hay de un tipo, con su color; pulsar filtra por él (y otra vez lo quita).
class _ChipCuenta extends StatelessWidget {
  final TipoMantenimiento tipo;
  final int n;
  final bool sel;
  final VoidCallback onTap;
  const _ChipCuenta(this.tipo, this.n, {required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: sel ? tipo.color.withValues(alpha: .1) : P.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? tipo.color : P.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          puntoTipo(tipo.color),
          const SizedBox(width: 8),
          Flexible(child: Text(tipo.etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: sel ? tipo.color : P.texto))),
          const SizedBox(width: 8),
          Text(
            '$n',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? tipo.color : P.texto),
          ),
        ],
      ),
    ),
  );
}

/// Desplegable de filtro: transparente con su valor por defecto; con un valor elegido, en morado suave.
class _Filtro<T> extends StatelessWidget {
  final String todos;
  final T? valor;
  final List<(T, String)> opciones;
  final ValueChanged<T?> onChanged;
  const _Filtro({required this.todos, required this.valor, required this.opciones, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final texto = opciones.where((o) => o.$1 == valor).firstOrNull?.$2 ?? todos;
    return BotonMenu<T?>(
      tooltip: todos,
      seleccionado: valor,
      onSelected: onChanged,
      opciones: [(null, Text(todos)), for (final (v, t) in opciones) (v, Text(t))],
      child: Container(
        height: 36,
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
