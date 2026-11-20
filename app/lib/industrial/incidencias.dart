import 'package:flutter/material.dart';

import '../forms.dart';
import '../informes.dart' show descargarInformeIncidencia;
import '../screens/informes.dart' show BotonPdf;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'incidencia.dart';
import 'mantenimientos.dart';
import 'tipo_mantenimiento.dart';

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

  /// 0 todas; 1 la primera de su pestaña (abierta / completada); 2 la segunda (con OT / desestimada).
  int estado = 0;
  String? activoId;

  @override
  Widget build(BuildContext context) {
    final rama = activoId == null ? null : store.ramaDe(activoId!);
    final todas = [for (final x in store.incidencias) (x, store.estadoIncidencia(x))];
    final pendientes = todas.where((e) => e.$2.pendiente).length;
    final lista =
        todas.where((e) {
          final (x, est) = e;
          if (est.pendiente == historico) return false;
          if (estado != 0 && est.index != (historico ? 1 : -1) + estado) return false;
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
                opciones: ['Pendientes · $pendientes', 'Histórico · ${todas.length - pendientes}'],
                iconos: const [Icons.radio_button_unchecked_rounded, Icons.task_alt_rounded],
                seleccion: historico ? 1 : 0,
                onChanged: (i) => setState(() {
                  historico = i == 1;
                  estado = 0;
                }),
              ),
              Pestanas(
                opciones: ['Todas', for (final e in estados) e.etiqueta],
                colores: [null, for (final e in estados) e.color],
                seleccion: estado,
                compactas: true,
                onChanged: (i) => setState(() => estado = i),
              ),
            ],
            derecha: [
              Buscador(hint: 'Buscar incidencia…', width: 240, onChanged: (v) => setState(() => q = v)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 210),
                child: SelectorActivo(activoId, (id) => setState(() => activoId = id), filtro: true),
              ),
            ],
            principal: BotonPrimario(
              'Incidencia',
              conIcono: true,
              color: P.rojo,
              tecla: 'N',
              onPressed: () => abrirIncidenciaForm(context, activoId: activoId),
            ),
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            child: lista.isEmpty
                ? Vacio(
                    icono: Icons.report_outlined,
                    titulo: historico ? 'Sin incidencias cerradas' : 'Sin incidencias pendientes',
                    texto: historico
                        ? 'Aquí quedan las incidencias completadas con su OT y las desestimadas.'
                        : 'Lo que comuniquen los técnicos aparece aquí para revisarlo.',
                  )
                : _TablaIncidencias(lista, historico: historico),
          ),
        ],
      ),
    );
  }
}

class _TablaIncidencias extends StatelessWidget {
  final List<(Incidencia, EstadoIncidencia)> lista;
  final bool historico;
  const _TablaIncidencias(this.lista, {required this.historico});

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
        seleccionCabecera: s.cabecera,
        columnas: [
          ...s.columna,
          const Col('Incidencia', flex: 4),
          if (medio) const Col('Activo', flex: 3),
          if (ancho) const Col('Comunicada por', flex: 2),
          if (ancho) Col(historico ? 'Cerrada' : 'Fecha', ancho: 140),
          if (medio) const Col('Estado', ancho: 140),
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
                Expanded(child: celdaTexto(x.descripcion.isEmpty ? 'Sin descripción' : x.descripcion, negrita: true)),
              ],
            ),
            if (medio) celdaTexto(dondeEs(x.activoId), suave: true),
            if (ancho) celdaTexto((x.tecnicoId == null ? null : store.trabajador(x.tecnicoId!))?.nombre ?? 'Oficina', suave: true),
            if (ancho) celdaTexto(relativo(DateUtils.dateOnly(historico ? x.cerradaEl ?? x.creada : x.creada)), suave: true),
            if (medio)
              Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: ot == null ? '' : 'OT: ${ot.nombre}',
                  child: Pill(est.etiqueta, est.color, punto: true),
                ),
              ),
            // Informe de la incidencia (con el parte de su OT si ya lo tiene) con un clic.
            if (medio) BotonPdf(() => descargarInformeIncidencia(x), tooltip: 'Descargar el informe en PDF'),
          ];
        },
        onTap: (i) => s.tocar(lista[i].$1.id, () => abrirIncidenciaForm(context, original: lista[i].$1)),
        pie: pieTabla(lista.length, lista.length == 1 ? 'incidencia' : 'incidencias'),
      ),
      );
    },
  );
}
