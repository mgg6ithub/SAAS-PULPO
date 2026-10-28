import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tabla_trabajos.dart';

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
            acciones: [
              pillEstado(t),
              const SizedBox(width: 4),
              BotonPrimario(
                'Subtrabajo',
                conIcono: true,
                icono: Icons.add_rounded,
                tecla: 'N',
                onPressed: () => abrirSubtrabajoRapido(context, t),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PestanasOscuras(
            opciones: const ['Resumen', 'Datos'],
            seleccion: pestana,
            onChanged: (i) => setState(() => pestana = i),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (actual, anteriores) => Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
              child: KeyedSubtree(
                key: ValueKey(pestana),
                child: pestana == 0
                    ? _Resumen(t, widget.onAbrir)
                    : Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: TareaForm(key: ValueKey(t.id), original: t, incrustada: true),
                        ),
                      ),
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
    child: Wrap(
      spacing: 28,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
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
        SizedBox(
          width: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asignado a', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
              const SizedBox(height: 6),
              SelectorTrabajadores(t, () => store.guardarTarea(t)),
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
    final tabla = TablaTrabajos(hijas, onAbrir: onAbrir, conCliente: false, nombre: 'subtrabajo');
    // En vertical no hay alto que repartir: tanto como filas, hasta un tope.
    return fija ? SizedBox(height: (hijas.length * 52 + 96).clamp(140, 380).toDouble(), child: tabla) : tabla;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth <= 900) {
        return ListView(
          children: [
            _resumen(),
            const SizedBox(height: 16),
            _subtrabajos(fija: true),
            const SizedBox(height: 16),
            _Historico(t),
          ],
        );
      }
      // El resumen, compacto; todo el alto restante para la lista de subtrabajos y el histórico.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _resumen(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _subtrabajos()),
                const SizedBox(width: 16),
                SizedBox(width: 340, child: SingleChildScrollView(child: _Historico(t))),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Cuándo se ha hecho el trabajo, lo último primero, y cuándo toca de nuevo.
class _Historico extends StatelessWidget {
  final Tarea t;
  const _Historico(this.t);

  @override
  Widget build(BuildContext context) {
    final dias = {...t.historial, ?t.ultimo}.toList()..sort((a, b) => b.compareTo(a));
    return SeccionTarjeta(
      titulo: 'Histórico',
      subtitulo: dias.isEmpty ? null : '${dias.length} ${dias.length == 1 ? 'vez' : 'veces'} hecho',
      children: [
        if (t.proximo != null)
          FilaLista(
            lider: Icon(Icons.event_outlined, size: 18, color: P.morado),
            titulo: 'Próximo',
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
              lider: Icon(Icons.check_circle_rounded, size: 18, color: P.verde),
              titulo: fecha(d),
              subtitulo: relativo(d),
            ),
      ],
    );
  }
}
