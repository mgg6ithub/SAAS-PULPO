import 'package:flutter/material.dart';

import '../forms.dart';
import '../industrial/tipo_mantenimiento.dart';
import '../marca.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class TareaCard extends StatelessWidget {
  final Tarea tarea;
  final bool mostrarCliente;
  final bool realizada;
  final bool botonHecha;
  final double? width;
  const TareaCard(
    this.tarea, {
    super.key,
    this.mostrarCliente = true,
    this.realizada = false,
    this.botonHecha = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final t = tarea;
    final cliente = store.cliente(t.clienteId);
    // Como los cuadraditos de la landing: nombre en negrita, una línea gris con hora · cliente · tipo
    // y, arriba a la derecha, quién lo hace. El punto del color del tipo es la única marca de color.
    final detalle = [
      if (realizada && t.ultimo != null) 'hecho ${relativo(t.ultimo!).toLowerCase()}',
      if (!realizada && !t.esPlantilla && t.proximo != null) relativo(t.proximo!),
      if (!realizada) ?t.horario,
      if (t.esPlantilla) t.periodicidad.etiqueta,
      if (mostrarCliente && !t.esPlantilla) cliente?.nombre ?? '—',
      if (t.ubicacion.isNotEmpty) t.ubicacion,
      t.tipo,
    ];
    final averiada = t.estadoMaquina != EstadoMaquina.operativa;
    return HoverCard(
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: () => abrirTareaForm(context, t),
      child: Opacity(
        opacity: t.activa ? 1 : .5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    t.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, letterSpacing: -.2),
                  ),
                ),
                const SizedBox(width: 8),
                if (!t.esPlantilla)
                  SelectorTrabajadores(t, () => store.guardarTarea(t), compacto: true, ofrecerSubtrabajos: true),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: t.colorBloque, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    detalle.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: P.textoSuave, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (realizada)
                        const Pill('Hecho', P.verde, punto: true)
                      else if (t.esPlantilla)
                        pillEstado(t)
                      else
                        SelectorEstado(t),
                      if (industrial && t.tipoMantenimiento != null) PillTipo(t.tipoMantenimiento!),
                      if (averiada) Pill(t.estadoMaquina.etiqueta, t.estadoMaquina.color),
                      if (t.esPlantilla)
                        for (final c in t.competencias) Etiqueta(c, P.morado),
                    ],
                  ),
                ),
                if (botonHecha)
                  Tooltip(
                    message: 'Marcar como hecho hoy',
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => store.marcarHecha(t),
                      child: const Text('Hecho'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
