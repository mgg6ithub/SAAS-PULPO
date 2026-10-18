import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'agenda_herramientas.dart';
import 'agenda_vistas.dart';
import 'vista_dias.dart';

/// Calendario de mes por bloques: en cada día, los clientes que tienen mantenimiento.
class VistaCalendario extends StatefulWidget {
  final ValueChanged<DateTime> onDia;
  final DateTime? inicial;

  /// Sin cabecera propia (mes y flechas) cuando la pone la Agenda.
  final bool conCabecera;
  const VistaCalendario({super.key, required this.onDia, this.inicial, this.conCabecera = true});

  @override
  State<VistaCalendario> createState() => _VistaCalendarioState();
}

class _VistaCalendarioState extends State<VistaCalendario> {
  late DateTime mes = DateTime((widget.inicial ?? hoy()).year, (widget.inicial ?? hoy()).month);

  void mover(int n) => setState(() => mes = DateTime(mes.year, mes.month + n));

  @override
  Widget build(BuildContext context) {
    final primero = masDias(mes, -(mes.weekday - 1)); // lunes de la primera semana
    return Column(
      children: [
        if (widget.conCabecera) ...[
          Row(
            children: [
              Text(
                '${meses[mes.month - 1]} ${mes.year}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              NavegadorFecha(
                anterior: 'Mes anterior',
                siguiente: 'Mes siguiente',
                onAnterior: () => mover(-1),
                onHoy: () => setState(() => mes = DateTime(hoy().year, hoy().month)),
                onSiguiente: () => mover(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            for (final d in diasSemana)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 6),
                  child: Text(
                    d.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6, color: P.textoSuave),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => ValueListenableBuilder(
              valueListenable: altoFilaMes,
              builder: (context, zoom, _) {
                final ajustado = box.maxHeight / 6;
                final fila = zoom == null ? ajustado : max(ajustado, zoom);
                return ConZoom(
                  onZoom: (f) => zoomMes(f, ajustado),
                  child: SingleChildScrollView(
                    key: const PageStorageKey('itinerario-mes'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: P.superficie,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: P.borde),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var semana = 0; semana < 6; semana++)
                            SizedBox(
                              height: fila,
                              child: Row(
                                children: [
                                  for (var d = 0; d < 7; d++)
                                    Expanded(child: _celda(masDias(primero, semana * 7 + d), semana, d)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _celda(DateTime dia, int semana, int col) {
    final delMes = dia.month == mes.month;
    final n = diasHasta(dia);
    final porCliente = <String, int>{};
    for (final t in store.tareasDelDia(dia).where((t) => filtroAgenda.pasa(t, dia))) {
      if (t.clienteId == null) continue;
      porCliente[t.clienteId!] = (porCliente[t.clienteId!] ?? 0) + 1;
    }
    final clientes = porCliente.keys.map(store.cliente).whereType<Cliente>().toList();
    return InkWell(
      onTap: () => widget.onDia(dia),
      hoverColor: P.moradoSuave.withValues(alpha: .5),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: n == 0 ? P.moradoSuave.withValues(alpha: .6) : (delMes ? null : P.columna),
          border: Border(
            top: semana == 0 ? BorderSide.none : BorderSide(color: P.borde),
            left: col == 0 ? BorderSide.none : BorderSide(color: P.borde),
          ),
        ),
        child: Opacity(
          opacity: n < 0 || !delMes ? .55 : 1,
          child: LayoutBuilder(
            builder: (context, box) {
              // Cuántos bloques caben; el resto se resume en "+N".
              final caben = ((box.maxHeight - 30) / 22).floor().clamp(0, 99);
              final visibles = clientes.length > caben ? (caben - 1).clamp(0, 99) : clientes.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: n == 0 ? BoxDecoration(color: P.morado, shape: BoxShape.circle) : null,
                      child: Text(
                        '${dia.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: n == 0 ? FontWeight.w800 : FontWeight.w600,
                          color: n == 0 ? Colors.white : (delMes ? P.texto : P.textoSuave),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final c in clientes.take(visibles)) _bloque(c, porCliente[c.id]!),
                  if (clientes.length > visibles)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Text(
                        '+${clientes.length - visibles} más',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: P.textoSuave),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bloque(Cliente c, int n) {
    final color = colorPaleta(c.color);
    return Container(
      height: 20,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              c.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: P.texto),
            ),
          ),
          if (n > 1)
            Text(
              '$n',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
        ],
      ),
    );
  }
}
