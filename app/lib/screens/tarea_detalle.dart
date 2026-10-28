import 'dart:convert';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tabla_trabajos.dart';
import 'tarea_automatizaciones.dart';

/// Ficha de un trabajo con pestañas, como la de un cliente: Resumen (cifras, subtrabajos e histórico)
/// y Datos (el formulario del trabajo, editable directamente).
class TareaDetalle extends StatefulWidget {
  final String tareaId;
  final VoidCallback onVolver;

  /// Entrar en otro trabajo (un subtrabajo, o el trabajo del que cuelga).
  final ValueChanged<String> onAbrir;
  const TareaDetalle({super.key, required this.tareaId, required this.onVolver, required this.onAbrir});

  @override
  State<TareaDetalle> createState() => _TareaDetalleState();
}

class _TareaDetalleState extends State<TareaDetalle> {
  int pestana = 0;

  /// En Datos, el formulario solo se puede cambiar tras pulsar «Editar».
  bool editando = false;

  @override
  Widget build(BuildContext context) {
    final t = store.tarea(widget.tareaId);
    if (t == null) {
      // Se acaba de borrar: volvemos a la lista.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVolver());
      return const SizedBox();
    }
    final cliente = store.cliente(t.clienteId);
    final padre = store.tarea(t.padreId);

    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cabecera(
            lider: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: padre == null ? 'Volver a Trabajos' : 'Volver a ${padre.nombre}',
                  onPressed: padre == null ? widget.onVolver : () => widget.onAbrir(padre.id),
                  icon: Icon(Icons.arrow_back_rounded, size: 20, color: P.textoSuave),
                ),
                const SizedBox(width: 4),
                BarraTipo(t.tipo, alto: 40, color: t.colorBloque),
              ],
            ),
            titulo: t.nombre.isEmpty ? 'Sin nombre' : t.nombre,
            subtitulo: [
              t.tipo,
              if (padre != null) 'Subtrabajo de ${padre.nombre}',
              cliente?.nombre ?? (t.esPlantilla ? 'Plantilla' : 'Sin cliente'),
            ].join(' · '),
            // Resumen: añadir subtrabajo; Datos: editar; Histórico: nada; Automatizaciones: añadir regla.
            acciones: [
              if (pestana == 0)
                BotonPrimario(
                  'Subtrabajo',
                  conIcono: true,
                  icono: Icons.add_rounded,
                  tecla: 'N',
                  onPressed: () => abrirSubtrabajoRapido(context, t),
                )
              else if (pestana == 1 && !editando)
                BotonPrimario(
                  'Editar',
                  conIcono: true,
                  icono: Icons.edit_outlined,
                  onPressed: () => setState(() => editando = true),
                )
              else if (pestana == 3)
                BotonPrimario(
                  'Automatización',
                  conIcono: true,
                  icono: Icons.add_rounded,
                  onPressed: () => abrirAutomatizacion(context, t),
                ),
            ],
          ),
          const SizedBox(height: 18),
          PestanasOscuras(
            opciones: const ['Resumen', 'Datos', 'Histórico', 'Automatizaciones'],
            seleccion: pestana,
            onChanged: (i) => setState(() {
              pestana = i;
              editando = false;
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (actual, anteriores) => Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
              child: KeyedSubtree(
                key: ValueKey(pestana),
                child: switch (pestana) {
                  0 => _Resumen(t, widget.onAbrir),
                  // Al solo mirar, se rehace con cada cambio (cliente, asignado… hechos en otra pestaña);
                  // al editar se conserva, para no perder lo escrito.
                  1 => TareaForm(
                    key: ValueKey(editando ? '${t.id}-edicion' : '${t.id}-${jsonEncode(t.toJson()).hashCode}'),
                    original: t,
                    incrustada: true,
                    soloLectura: !editando,
                    onTerminar: () => setState(() => editando = false),
                  ),
                  2 => _Historico(t),
                  _ => TareaAutomatizaciones(t),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final Tarea t;
  final ValueChanged<String> onAbrir;
  const _Resumen(this.t, this.onAbrir);

  Widget _cifra(String etiqueta, String valor, String nota) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(etiqueta, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
      const SizedBox(height: 4),
      Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8)),
      Text(
        nota,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: P.textoSuave),
      ),
    ],
  );

  /// Cifras y, en la misma tarjeta, a quién está asignado (se puede cambiar desde aquí).
  Widget _resumen() => Tarjeta(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Las cifras a la izquierda; el espacio sobrante las separa del asignado, arriba a la derecha.
        Expanded(
          child: Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [
              _cifra(
                'Próximo',
                t.proximo == null ? '—' : relativo(t.proximo!),
                t.proximo == null ? 'sin fecha' : fecha(t.proximo),
              ),
              _cifra(
                'Último',
                t.ultimo == null ? '—' : relativo(t.ultimo!),
                t.ultimo == null ? 'sin registros' : fecha(t.ultimo),
              ),
              _cifra('Periodicidad', t.periodicidad.etiqueta, t.horario ?? 'sin hora'),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asignado a', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
              const SizedBox(height: 6),
              SelectorTrabajadores(t, () => store.guardarTarea(t), ofrecerSubtrabajos: true),
            ],
          ),
        ),
      ],
    ),
  );

  /// Los subtrabajos, en la misma lista que los trabajos; se entra en cada uno para añadirle más.
  Widget _subtrabajos({bool fija = false}) {
    final hijas = store.hijas(t.id)
      ..sort((a, b) => (a.proximo ?? DateTime(2100)).compareTo(b.proximo ?? DateTime(2100)));
    if (hijas.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Consejo(
          'Un trabajo grande se puede dividir en subtrabajos, cada uno con su fecha, color y equipo. '
          'Pulsa «Subtrabajo» arriba para añadir el primero.',
        ),
      );
    }
    final tabla = TablaTrabajos(hijas, onAbrir: onAbrir, umbralAncho: 760, nombre: 'subtrabajo');
    // En vertical no hay alto que repartir: tanto como filas, hasta un tope.
    return fija ? SizedBox(height: (hijas.length * 52 + 96).clamp(140, 380).toDouble(), child: tabla) : tabla;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth <= 900) {
        return ListView(children: [_resumen(), const SizedBox(height: 16), _subtrabajos(fija: true)]);
      }
      // El resumen, compacto; todo el alto restante para la lista de subtrabajos.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _resumen(),
          const SizedBox(height: 16),
          Expanded(child: _subtrabajos()),
        ],
      );
    },
  );
}

/// Cuándo se ha hecho el trabajo, lo último primero, con un check verde a la derecha, y cuándo toca de nuevo.
/// Ocupa todo el espacio; arriba a la derecha, un menú para decir si es único o se repite.
class _Historico extends StatelessWidget {
  final Tarea t;
  const _Historico(this.t);

  /// Una vez hecho, un trabajo único se queda sin próxima fecha: al hacerlo periódico, la siguiente cuenta desde
  /// la última vez.
  void _periodicidad(Periodicidad p) {
    t.periodicidad = p;
    if (p.repite && t.proximo == null) t.proximo = masDias(t.ultimo ?? hoy(), p.dias);
    store.guardarTarea(t);
  }

  Widget _menuPeriodicidad() => BotonMenu<Periodicidad>(
    tooltip: 'Cada cuánto se repite',
    seleccionado: t.periodicidad,
    onSelected: _periodicidad,
    opciones: [for (final p in Periodicidad.values) (p, Text(p.etiqueta))],
    child: Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: P.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.periodicidad.etiqueta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          Icon(Icons.unfold_more_rounded, size: 16, color: P.textoSuave),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dias = {...t.historial, ?t.ultimo}.toList()..sort((a, b) => b.compareTo(a));
    return LayoutBuilder(
      builder: (context, box) => SeccionTarjeta(
        alto: box.maxHeight,
        titulo: 'Histórico',
        subtitulo: dias.isEmpty ? null : '${dias.length} ${dias.length == 1 ? 'vez' : 'veces'} hecho',
        accion: _menuPeriodicidad(),
        children: [
          if (t.proximo != null)
            FilaLista(
              lider: Icon(Icons.event_outlined, size: 18, color: P.morado),
              titulo: 'Pendiente',
              subtitulo: '${fecha(t.proximo)} · ${relativo(t.proximo!)}',
            ),
          if (dias.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text('Aún no se ha hecho.', style: TextStyle(color: P.textoSuave, fontSize: 13)),
            )
          else
            for (final d in dias)
              FilaLista(
                lider: Icon(Icons.event_outlined, size: 18, color: P.textoSuave),
                titulo: fecha(d),
                subtitulo: relativo(d),
                derecha: Icon(Icons.check_circle_rounded, size: 20, color: P.verde),
              ),
        ],
      ),
    );
  }
}
