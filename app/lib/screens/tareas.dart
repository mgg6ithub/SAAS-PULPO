import 'dart:math';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tarea_card.dart';

/// Todas las tareas: las de cada cliente y las plantillas (sin cliente).
class TareasPagina extends StatefulWidget {
  const TareasPagina({super.key});

  @override
  State<TareasPagina> createState() => _TareasPaginaState();
}

class _TareasPaginaState extends State<TareasPagina> {
  String q = '';
  int pestana = 0; // 0 de clientes, 1 plantillas, 2 todas
  String? tipo;
  bool lista = true;

  @override
  Widget build(BuildContext context) {
    final deClientes = store.tareas.length - store.plantillas.length;
    final filtradas =
        store.tareas.where((t) {
          if (pestana == 0 && t.esPlantilla) return false;
          if (pestana == 1 && !t.esPlantilla) return false;
          if (tipo != null && t.tipo != tipo) return false;
          final texto = '${t.nombre} ${t.marca} ${t.ubicacion} ${store.cliente(t.clienteId)?.nombre ?? ''}'
              .toLowerCase();
          return texto.contains(q.toLowerCase());
        }).toList()..sort((a, b) {
          if (a.esPlantilla != b.esPlantilla) return a.esPlantilla ? 1 : -1;
          return (a.proximo ?? DateTime(2100)).compareTo(b.proximo ?? DateTime(2100));
        });
    final tiposUsados = {for (final t in store.tareas) t.tipo};

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cabecera(
            titulo: 'Tareas',
            subtitulo: '$deClientes mantenimientos de clientes · ${store.plantillas.length} plantillas',
            acciones: [
              BotonPrimario(
                pestana == 1 ? 'Nueva plantilla' : 'Nueva tarea',
                tecla: 'N',
                onPressed: () => abrirTareaForm(context, null, plantilla: pestana == 1),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ResumenLista([
            (
              'Vencidas',
              store.tareas
                  .where((t) => !t.esPlantilla && t.activa && t.proximo != null && diasHasta(t.proximo!) < 0)
                  .length,
              'pendientes de hacer',
              P.rojo,
            ),
            (
              'Esta semana',
              store.tareas
                  .where(
                    (t) =>
                        !t.esPlantilla &&
                        t.activa &&
                        t.proximo != null &&
                        diasHasta(t.proximo!) >= 0 &&
                        diasHasta(t.proximo!) <= 7,
                  )
                  .length,
              'próximos 7 días',
              P.ambar,
            ),
            (
              'Sin asignar',
              store.tareas.where((t) => !t.esPlantilla && t.activa && t.trabajadorIds.isEmpty).length,
              'sin técnico',
              P.morado,
            ),
          ]),
          const SizedBox(height: 20),
          BarraFiltros(
            izquierda: [
              Pestanas(
                opciones: ['De clientes · $deClientes', 'Plantillas · ${store.plantillas.length}', 'Todas'],
                seleccion: pestana,
                onChanged: (i) => setState(() => pestana = i),
              ),
            ],
            derecha: [
              Buscador(hint: 'Buscar tarea, equipo o cliente…', width: 280, onChanged: (v) => setState(() => q = v)),
              SelectorVista(lista: lista, onChanged: (v) => setState(() => lista = v)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in tipos.where((x) => tiposUsados.contains(x.nombre)))
                _ChipTipo(x, tipo == x.nombre, () => setState(() => tipo = tipo == x.nombre ? null : x.nombre)),
            ],
          ),
          if (pestana == 1) ...[
            const SizedBox(height: 12),
            Tarjeta(
              color: P.moradoSuave,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: P.morado, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Las plantillas no tienen cliente. Al crear una tarea dentro de un cliente, elige una y se rellena casi todo.',
                      style: TextStyle(color: P.moradoOscuro, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: filtradas.isEmpty
                ? Vacio(
                    icono: Icons.handyman_outlined,
                    titulo: store.tareas.isEmpty ? 'Aún no hay tareas' : null,
                    texto: pestana == 0 && deClientes == 0
                        ? 'Crea tareas dentro de tus clientes, desde cero o a partir de una plantilla.'
                        : 'No hay tareas con estos filtros',
                  )
                : lista
                ? _tabla(filtradas)
                : LayoutBuilder(
                    builder: (context, box) {
                      final cols = max(1, (box.maxWidth / 440).floor());
                      final w = (box.maxWidth - (cols - 1) * 14) / cols;
                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [for (final t in filtradas) TareaCard(t, width: w)],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabla(List<Tarea> ts) => LayoutBuilder(
    builder: (context, box) {
      final ancho = box.maxWidth > 1000;
      return Align(
        alignment: Alignment.topCenter,
        child: Tabla(
          columnas: [
            const Col('Equipo / tarea', flex: 4),
            const Col('Cliente', flex: 3),
            if (ancho) const Col('Periodicidad', flex: 2),
            const Col('Próximo', flex: 2),
            if (ancho) const Col('Horario', flex: 2),
            const Col('Asignada a', ancho: 90),
            const Col('Estado', ancho: 80, derecha: true),
          ],
          filas: ts.length,
          onTap: (i) => abrirTareaForm(context, ts[i]),
          pie: pieTabla(ts.length, ts.length == 1 ? 'tarea' : 'tareas'),
          celdas: (i) {
            final t = ts[i];
            final c = store.cliente(t.clienteId);
            final vencida = t.proximo != null && diasHasta(t.proximo!) < 0;
            return [
              Row(
                children: [
                  BarraTipo(t.tipo, alto: 28, color: t.colorBloque),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        celdaTexto(t.nombre, negrita: true),
                        Text(
                          [t.tipo, if (t.ubicacion.isNotEmpty) t.ubicacion].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              c == null
                  ? (t.esPlantilla ? Etiqueta('Plantilla', P.morado) : celdaTexto('Sin cliente', suave: true))
                  : Row(
                      children: [
                        Avatar(c.iniciales, colorPaleta(c.color), size: 20, cuadrado: true),
                        const SizedBox(width: 8),
                        Flexible(child: celdaTexto(c.nombre)),
                      ],
                    ),
              if (ancho) celdaTexto(t.periodicidad.etiqueta),
              t.proximo == null
                  ? celdaTexto('', suave: true)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fecha(t.proximo),
                          style: TextStyle(
                            fontSize: 13,
                            color: vencida ? P.rojo : P.texto,
                            fontWeight: vencida ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        Text(relativo(t.proximo!), style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                      ],
                    ),
              if (ancho) celdaTexto(t.horario ?? '', suave: true),
              t.esPlantilla ? const SizedBox() : AvataresTrabajadores(t.trabajadorIds, size: 24),
              pillEstado(t),
            ];
          },
        ),
      );
    },
  );
}

/// Filtro por tipo: píldora con el punto de color del tipo; la elegida, con borde de su color.
class _ChipTipo extends StatelessWidget {
  final TipoInfo tipo;
  final bool sel;
  final VoidCallback onTap;
  const _ChipTipo(this.tipo, this.sel, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sel ? tipo.color.withValues(alpha: .1) : P.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? tipo.color : P.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tipo.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            tipo.nombre,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: sel ? tipo.color : P.texto),
          ),
        ],
      ),
    ),
  );
}
