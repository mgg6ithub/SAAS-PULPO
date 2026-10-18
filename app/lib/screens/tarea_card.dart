import 'package:flutter/material.dart';

import '../forms.dart';
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
    // Todo lo secundario en una sola línea gris; el color lo ponen la barrita del tipo y el estado.
    final detalle = [
      if (mostrarCliente && !t.esPlantilla) cliente?.nombre ?? '—',
      if (realizada && t.ultimo != null) 'hecha ${relativo(t.ultimo!).toLowerCase()}',
      if (!realizada && !t.esPlantilla && t.proximo != null) relativo(t.proximo!),
      if (!realizada) ?t.horario,
      if (t.esPlantilla) t.periodicidad.etiqueta,
      if (t.ubicacion.isNotEmpty) t.ubicacion,
    ];
    return HoverCard(
      width: width,
      padding: const EdgeInsets.all(12),
      onTap: () => abrirTareaForm(context, t),
      child: Opacity(
        opacity: t.activa ? 1 : .5,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BarraTipo(t.tipo, alto: 34, color: t.colorBloque),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: P.textoSuave, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (realizada) const Pill('Hecha', P.verde, solido: true) else pillEstado(t),
                      if (t.estadoMaquina != EstadoMaquina.operativa)
                        Pill(t.estadoMaquina.etiqueta, t.estadoMaquina.color),
                      if (t.esPlantilla)
                        for (final c in t.competencias) Etiqueta(c, P.morado),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!t.esPlantilla) AvataresTrabajadores(t.trabajadorIds),
                if (botonHecha) ...[
                  const SizedBox(height: 10),
                  Tooltip(
                    message: 'Marcar como hecha hoy',
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => store.marcarHecha(t),
                      child: const Text('Hecha'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
