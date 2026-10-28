import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ficha de un trabajo con pestañas, como la de un cliente: Resumen (cifras, subtrabajos e histórico)
/// y Datos (el formulario del trabajo, editable directamente).
class TareaDetalle extends StatefulWidget {
  final String tareaId;
  final VoidCallback onVolver;
  const TareaDetalle({super.key, required this.tareaId, required this.onVolver});

  @override
  State<TareaDetalle> createState() => _TareaDetalleState();
}

class _TareaDetalleState extends State<TareaDetalle> {
  int pestana = 0;

  Future<void> _nuevoSubtrabajo(Tarea t) async {
    final nombre = await showDialog<String>(context: context, builder: (_) => const _NombreSubtrabajo());
    if (nombre == null || nombre.isEmpty) return;
    t.subtrabajos.add(Subtrabajo(id: store.nuevoId(), nombre: nombre));
    store.guardarTarea(t);
    setState(() => pestana = 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = store.tareas.where((x) => x.id == widget.tareaId).firstOrNull;
    if (t == null) {
      // Se acaba de borrar: volvemos a la lista.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVolver());
      return const SizedBox();
    }
    final cliente = store.cliente(t.clienteId);

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
                  tooltip: 'Volver a Trabajos',
                  onPressed: widget.onVolver,
                  icon: Icon(Icons.arrow_back_rounded, size: 20, color: P.textoSuave),
                ),
                const SizedBox(width: 4),
                BarraTipo(t.tipo, alto: 40, color: t.colorBloque),
              ],
            ),
            titulo: t.nombre.isEmpty ? 'Sin nombre' : t.nombre,
            subtitulo: [t.tipo, cliente?.nombre ?? (t.esPlantilla ? 'Plantilla' : 'Sin cliente')].join(' · '),
            acciones: [pillEstado(t)],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PestanasOscuras(
                opciones: const ['Resumen', 'Datos'],
                seleccion: pestana,
                onChanged: (i) => setState(() => pestana = i),
              ),
              BotonAccion('Subtrabajo', icono: Icons.add_rounded, onPressed: () => _nuevoSubtrabajo(t)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (actual, anteriores) => Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
              child: KeyedSubtree(
                key: ValueKey(pestana),
                child: pestana == 0
                    ? _Resumen(t)
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
  const _Resumen(this.t);

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
      spacing: 48,
      runSpacing: 14,
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
          width: 280,
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

  Widget _subtrabajos() {
    if (t.subtrabajos.isEmpty) {
      return const Consejo(
        'Un trabajo grande se puede dividir en partes. Pulsa «Subtrabajo» arriba para añadir la primera.',
      );
    }
    return SeccionTarjeta(
      titulo: 'Subtrabajos',
      subtitulo: '${t.subtrabajos.where((x) => x.hecho).length} de ${t.subtrabajos.length} hechos',
      children: [
        for (final x in t.subtrabajos)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
            child: Row(
              children: [
                Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: x.hecho,
                  onChanged: (v) {
                    x.hecho = v ?? false;
                    store.guardarTarea(t);
                  },
                ),
                Expanded(
                  child: Text(
                    x.nombre,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: x.hecho ? P.textoSuave : P.texto,
                      decoration: x.hecho ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar subtrabajo',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    t.subtrabajos.remove(x);
                    store.guardarTarea(t);
                  },
                  icon: Icon(Icons.close_rounded, size: 16, color: P.textoSuave),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth <= 900) {
        return ListView(
          children: [_resumen(), const SizedBox(height: 16), _subtrabajos(), const SizedBox(height: 16), _Historico(t)],
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
                Expanded(child: SingleChildScrollView(child: _subtrabajos())),
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

/// Pide el nombre del subtrabajo nuevo.
class _NombreSubtrabajo extends StatefulWidget {
  const _NombreSubtrabajo();

  @override
  State<_NombreSubtrabajo> createState() => _NombreSubtrabajoState();
}

class _NombreSubtrabajoState extends State<_NombreSubtrabajo> {
  final nombre = TextEditingController();

  @override
  void dispose() {
    nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nuevo subtrabajo',
              style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nombre,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Caldera 3, extintor del pasillo…'),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: BotonPrimario('Añadir', onPressed: () => Navigator.pop(context, nombre.text.trim())),
            ),
          ],
        ),
      ),
    ),
  );
}
