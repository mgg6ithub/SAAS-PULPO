import 'package:flutter/material.dart';

import '../columnas.dart';
import '../forms.dart';
import '../informes.dart' show descargarInformeIncidencia;
import '../screens/informes.dart' show BotonPdf;
import '../models.dart';
import '../screens/importar_exportar.dart' show Exportable, abrirExportar;
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activos.dart' show enOrdenDelUsuario;
import 'incidencia.dart';
import 'mantenimientos.dart';
import 'tipo_mantenimiento.dart';
import '../screens/tareas.dart' show verOtEnOrdenes;

/// Incidencia a marcar con borde rojo al llegar a Incidencias desde otra vista (p. ej. Estadísticas).
final incidenciaMarcada = ValueNotifier<String?>(null);

/// Cada aviso pide a la barra lateral que vaya a Incidencias.
final pedirIncidencias = ValueNotifier<int>(0);

/// Va a Incidencias (en Pendientes o en Histórico, donde esté, sin filtros) con [id] marcada.
void verIncidencia(BuildContext context, String id) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  incidenciaMarcada.value = id;
  pedirIncidencias.value++;
}

/// Pultec: sección Incidencias. Pendientes (abiertas y con OT) e histórico (completadas y desestimadas):
/// ninguna incidencia desaparece, quedan todas controladas en el tiempo.
class IncidenciasPagina extends StatefulWidget {
  const IncidenciasPagina({super.key});

  @override
  State<IncidenciasPagina> createState() => _IncidenciasPaginaState();
}

class _IncidenciasPaginaState extends State<IncidenciasPagina> {
  String q = '';
  bool historico = false;

  /// Pendientes: 0 todas, 1 abiertas, 2 con OT. Histórico: 0 las completadas, 1 solo las desestimadas.
  int estado = 0;
  String? activoId;

  /// Sube con cada incidencia marcada: rehace el buscador para vaciarlo.
  int _marcas = 0;

  @override
  void initState() {
    super.initState();
    incidenciaMarcada.addListener(_alMarcar);
    _marcar();
  }

  @override
  void dispose() {
    incidenciaMarcada.removeListener(_alMarcar);
    super.dispose();
  }

  void _alMarcar() => setState(_marcar);

  /// Con una incidencia marcada: a la pestaña donde está y sin filtros, para que se vea seguro.
  void _marcar() {
    final x = store.incidencias.where((i) => i.id == incidenciaMarcada.value).firstOrNull;
    if (x == null) return;
    final est = store.estadoIncidencia(x);
    historico = !est.pendiente;
    estado = est == EstadoIncidencia.desestimada ? 1 : 0;
    activoId = null;
    q = '';
    _marcas++;
  }

  /// Tocar la pestaña o un filtro quita la marca.
  void _sinMarca() => incidenciaMarcada.value = null;

  @override
  Widget build(BuildContext context) {
    final rama = activoId == null ? null : store.ramaDe(activoId!);
    final todas = [for (final x in store.incidencias) (x, store.estadoIncidencia(x))];
    final pendientes = todas.where((e) => e.$2.pendiente).length;
    final lista =
        todas.where((e) {
          final (x, est) = e;
          if (est.pendiente == historico) return false;
          if (historico) {
            if (est != (estado == 1 ? EstadoIncidencia.desestimada : EstadoIncidencia.completada)) return false;
          } else if (estado != 0 && est.index != estado - 1) {
            return false;
          }
          if (rama != null && !rama.contains(x.activoId)) return false;
          final quien = (x.tecnicoId == null ? null : store.trabajador(x.tecnicoId!))?.nombre ?? '';
          return '${x.descripcion} ${dondeEs(x.activoId)} $quien'.toLowerCase().contains(q.toLowerCase());
        }).toList()..sort((a, b) {
          // Pendientes: abiertas primero, las más graves y las más nuevas. Histórico: lo último cerrado arriba.
          if (historico) return (b.$1.cerradaEl ?? b.$1.creada).compareTo(a.$1.cerradaEl ?? a.$1.creada);
          final e = a.$2.index.compareTo(b.$2.index);
          if (e != 0) return e;
          final g = b.$1.gravedad.index.compareTo(a.$1.gravedad.index);
          return g != 0 ? g : b.$1.creada.compareTo(a.$1.creada);
        });
    final estados = historico
        ? [EstadoIncidencia.completada, EstadoIncidencia.desestimada]
        : [EstadoIncidencia.abierta, EstadoIncidencia.conOt];
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarraVista(
            izquierda: [
              const TituloVista('Incidencias'),
              Pestanas(
                opciones: ['Pendientes $pendientes', 'Histórico ${todas.length - pendientes}'],
                iconos: const [Icons.radio_button_unchecked_rounded, Icons.task_alt_rounded],
                coloresIconos: [null, P.verde],
                seleccion: historico ? 1 : 0,
                onChanged: (i) => setState(() {
                  historico = i == 1;
                  estado = 0;
                  _sinMarca();
                }),
              ),
              // Histórico: de serie, las completadas; un botón enseña solo las desestimadas.
              if (historico)
                BotonAccion(
                  'Desestimadas',
                  icono: EstadoIncidencia.desestimada.icono,
                  tooltip: estado == 1 ? 'Volver a las completadas' : 'Ver solo las desestimadas',
                  color: estado == 1 ? P.rojo : null,
                  onPressed: () => setState(() => estado = estado == 1 ? 0 : 1),
                )
              else
                Pestanas(
                  opciones: ['Todas', for (final e in estados) e.etiqueta],
                  iconos: [null, for (final e in estados) e.icono],
                  coloresIconos: [null, for (final e in estados) e.color],
                  seleccion: estado,
                  compactas: true,
                  onChanged: (i) => setState(() => estado = i),
                ),
            ],
            derecha: [
              Buscador(
                key: ValueKey('buscar-$_marcas'),
                hint: 'Buscar incidencia…',
                width: 240,
                onChanged: (v) => setState(() => q = v),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 210),
                child: SelectorActivo(activoId, (id) => setState(() => activoId = id), filtro: true),
              ),
            ],
            principal: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Exportar o imprimir las incidencias que se ven (con los filtros puestos), a la izquierda.
                if (todas.isNotEmpty) ...[
                  BotonImportarExportar(
                    soloExportar: true,
                    tooltip: 'Exportar o imprimir las incidencias que ves',
                    onPressed: () => abrirExportar(
                      context,
                      Exportable(
                        historico ? 'Histórico de incidencias' : 'Incidencias',
                        () => incidenciasEnTexto(lista, historico: historico),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                BotonPrimario(
                  'Incidencia',
                  conIcono: true,
                  color: P.rojo,
                  tecla: 'N',
                  onPressed: () => abrirIncidenciaForm(context, activoId: activoId),
                ),
              ],
            ),
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            child: lista.isEmpty
                ? Vacio(
                    icono: Icons.report_outlined,
                    color: P.rojo,
                    // El título dice lo que se está filtrando.
                    titulo: historico
                        ? (estado == 1 ? 'Sin incidencias desestimadas' : 'Sin incidencias completadas')
                        : const ['Sin incidencias pendientes', 'Sin incidencias abiertas', 'Sin incidencias con OT'][estado],
                    texto: historico
                        ? 'Aquí quedan las incidencias completadas con su OT y las desestimadas.'
                        : 'Lo que comuniquen los técnicos aparece aquí para revisarlo.',
                  )
                : _TablaIncidencias(lista, historico: historico, marcada: incidenciaMarcada.value),
          ),
        ],
      ),
    );
  }
}

/// Nombre con el que se guardan las columnas de la lista de incidencias (la abierta y la del historial, cada una).
String tablaIncidencias(bool historico) => historico ? 'incidencias-historial' : 'incidencias';

/// Incidencias [lista] en texto, tal como se ven (con los filtros puestos). Cabecera primero.
List<List<String>> incidenciasEnTexto(List<(Incidencia, EstadoIncidencia)> lista, {required bool historico}) {
  final valores = <String, String Function(Incidencia, EstadoIncidencia)>{
    'Incidencia': (x, _) => x.descripcion.isEmpty ? 'Sin descripción' : x.descripcion,
    'Activo': (x, _) => dondeEs(x.activoId),
    'Comunicada por': (x, _) => (x.tecnicoId == null ? null : store.trabajador(x.tecnicoId!))?.nombre ?? 'Oficina',
    historico ? 'Cerrada' : 'Fecha': (x, _) => fecha(historico ? x.cerradaEl ?? x.creada : x.creada),
    'Estado': (_, e) => e.etiqueta,
  };
  final tabla = tablaIncidencias(historico);
  final cols = enOrdenDelUsuario([
    for (final c in valores.keys)
      if (c == 'Incidencia' || columnasTablas.ve(tabla, c)) c,
  ], columnasTablas.orden(tabla));
  // La gravedad, que en la lista es el punto de color, va al lado de la incidencia.
  final i = cols.indexOf('Incidencia');
  final conGravedad = [...cols]..insert(i + 1, 'Gravedad');
  return [
    conGravedad,
    for (final (x, e) in lista)
      [
        for (final c in conGravedad) c == 'Gravedad' ? x.gravedad.etiqueta : valores[c]!(x, e),
      ],
  ];
}

class _TablaIncidencias extends StatelessWidget {
  final List<(Incidencia, EstadoIncidencia)> lista;
  final bool historico;

  /// La que llega marcada desde otra vista: borde rojo y a la vista.
  final String? marcada;
  const _TablaIncidencias(this.lista, {required this.historico, this.marcada});

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => (box.maxWidth > 980, box.maxWidth > 640),
    builder: (context, box) {
      final ancho = box.maxWidth > 980, medio = box.maxWidth > 640;
      return SeleccionMultiple(
        ids: [for (final e in lista) e.$1.id],
        singular: 'incidencia',
        plural: 'incidencias',
        borrar: store.borrarIncidencia,
        builder: (context, s) => Tabla(
        // Orden y columnas elegidas se guardan en la cuenta (y Exportar los sigue).
        id: tablaIncidencias(historico),
        menuColumnas: medio,
        seleccionCabecera: s.cabecera,
        resaltar: marcada == null ? null : (i) => lista[i].$1.id == marcada ? P.rojo : null,
        focoInicial: marcada == null ? null : lista.indexWhere((e) => e.$1.id == marcada),
        columnas: [
          ...s.columna,
          const Col('Incidencia', flex: 4, fija: true),
          if (medio) const Col('Activo', flex: 3),
          if (ancho) const Col('Comunicada por', flex: 2),
          if (ancho) Col(historico ? 'Cerrada' : 'Fecha', ancho: 140),
          if (medio) const Col('Estado', ancho: 180),
          if (medio) const Col('', ancho: 48, cabecera: SizedBox()),
        ],
        filas: lista.length,
        celdas: (i) {
          final (x, est) = lista[i];
          final ot = store.tarea(x.trabajoId);
          return [
            ...s.casilla(x.id),
            Row(
              children: [
                Tooltip(message: x.gravedad.etiqueta, child: puntoTipo(x.gravedad.color, tam: 10)),
                const SizedBox(width: 10),
                Expanded(
                  child: conNuevo(x.id, celdaTexto(x.descripcion.isEmpty ? 'Sin descripción' : x.descripcion, negrita: true)),
                ),
              ],
            ),
            // La máquina; el componente se ve al abrir la incidencia.
            if (medio) celdaTexto(raizDe(x.activoId)?.titulo ?? '', suave: true),
            if (ancho) _quien(x.tecnicoId == null ? null : store.trabajador(x.tecnicoId!)),
            if (ancho) celdaTexto(relativo(DateUtils.dateOnly(historico ? x.cerradaEl ?? x.creada : x.creada)), suave: true),
            if (medio)
              Row(
                children: [
                  // La píldora se recorta en columnas estrechas; «Ver», siempre a la derecha y en todas las filas.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRect(
                        child: Tooltip(message: ot == null ? '' : 'OT: ${ot.nombre}', child: Pill(est.etiqueta, est.color, icono: est.icono)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Con su OT por hacer lleva a ella; sin ella, abre la incidencia.
                  ot != null && est == EstadoIncidencia.conOt
                      ? EnlaceVerOt(ot.id)
                      : EnlaceVer('Ver la incidencia', () {
                          store.verNuevo(x.id);
                          abrirIncidenciaForm(context, original: x);
                        }),
                ],
              ),
            // Informe de la incidencia (con el parte de su OT si ya lo tiene) con un clic.
            if (medio) BotonPdf(() => descargarInformeIncidencia(context, x), tooltip: 'Descargar el informe en PDF'),
          ];
        },
        onTap: (i) => s.tocar(lista[i].$1.id, () {
          store.verNuevo(lista[i].$1.id);
          abrirIncidenciaForm(context, original: lista[i].$1);
        }),
        pie: pieTabla(lista.length, lista.length == 1 ? 'incidencia' : 'incidencias'),
      ),
      );
    },
  );
}

/// «👁 Ver» en tono neutro, el mismo en toda la app y siempre a la derecha de su fila.
/// Quién la comunicó: su avatar y su nombre (sin técnico, la oficina).
Widget _quien(Trabajador? w) => Row(
  children: [
    if (w != null) ...[Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 22), const SizedBox(width: 8)],
    Expanded(child: celdaTexto(w?.nombre ?? 'Oficina', suave: true)),
  ],
);

class EnlaceVer extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  const EnlaceVer(this.tooltip, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, size: 15, color: P.textoSuave),
            const SizedBox(width: 5),
            Text('Ver', style: TextStyle(fontSize: 12.5, color: P.textoSuave, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ),
  );
}

/// «Ver» de una orden: va a Órdenes de trabajo con ella marcada.
class EnlaceVerOt extends StatelessWidget {
  final String otId;
  const EnlaceVerOt(this.otId, {super.key});

  @override
  Widget build(BuildContext context) => EnlaceVer('Ver la orden de trabajo', () => verOtEnOrdenes(context, otId));
}
