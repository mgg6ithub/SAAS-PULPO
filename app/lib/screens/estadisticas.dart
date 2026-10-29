import 'dart:math';

import 'package:flutter/material.dart';

import '../estadisticas.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Estadísticas de Inicio: lo hecho cada mes, cada tipo de trabajo (cuántos, cuánto tardan, averías) y los
/// clientes con más averías. En dos columnas si cabe.
class Estadisticas extends StatelessWidget {
  final bool dosCol;
  final ValueChanged<String> onCliente;
  const Estadisticas({super.key, required this.dosCol, required this.onCliente});

  @override
  Widget build(BuildContext context) {
    final meses = hechosPorMes(store);
    final maxMes = max(1, meses.map((m) => m.$2).reduce(max));
    final tipos = porTipo(store).take(6).toList();
    final maxTipo = max(1, tipos.isEmpty ? 1 : tipos.first.trabajos);
    final averias = clientesConAverias(store).take(5).toList();

    final hechos = SeccionTarjeta(
      titulo: 'Mantenimientos hechos',
      subtitulo: 'Últimos 6 meses',
      sinFilas: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (m, n) in meses)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Container(
                            height: 80 * n / maxMes + 2,
                            decoration: BoxDecoration(
                              color: n == 0 ? P.hover : P.morado,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_mesesCortos[m.month - 1], style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    final porTipos = SeccionTarjeta(
      titulo: 'Por tipo de trabajo',
      subtitulo: 'Trabajos, duración media y averías',
      sinFilas: true,
      children: [
        for (final t in tipos)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                BarraTipo(t.tipo, alto: 22),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: Text(
                    t.tipo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: t.trabajos / maxTipo,
                      minHeight: 6,
                      color: tipoDe(t.tipo).color,
                      backgroundColor: P.hover,
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    ['${t.trabajos}', '${t.minutosMedios} min', if (t.averias > 0) '${t.averias} av.'].join(' · '),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12.5, color: t.averias > 0 ? P.texto : P.textoSuave),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );

    final clientes = SeccionTarjeta(
      titulo: 'Clientes con más averías',
      subtitulo: 'Equipos averiados o en revisión y avisos urgentes',
      children: averias.isEmpty
          ? [
              const SizedBox(
                height: 120,
                child: Vacio(icono: Icons.task_alt_rounded, texto: 'Ninguna avería registrada'),
              ),
            ]
          : [
              for (final (c, n) in averias)
                FilaLista(
                  lider: Avatar(c.iniciales, colorPaleta(c.color), size: 26, cuadrado: true),
                  titulo: c.nombre,
                  derecha: Pill('$n', P.rojo),
                  onTap: () => onCliente(c.id),
                ),
            ],
    );

    Widget par(Widget a, Widget b) => dosCol
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: a),
                const SizedBox(width: 16),
                Expanded(child: b),
              ],
            ),
          )
        : Column(children: [a, const SizedBox(height: 16), b]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Estadísticas',
          style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
        ),
        const SizedBox(height: 14),
        par(hechos, clientes),
        const SizedBox(height: 16),
        porTipos,
      ],
    );
  }
}
