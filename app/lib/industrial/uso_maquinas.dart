import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../screens/vista_dias.dart' show meses, diasSemana, lunesDe;
import 'activo.dart';
import 'iconos.dart';
import 'planes.dart' show turnosDe, ponerTurnos;

/// Abre el calendario de uso de las máquinas (activos con uso «Planificado por turnos»).
Future<void> abrirUsoMaquinas(BuildContext context) => showDialog(
  context: context,
  builder: (_) => const Dialog(
    insetPadding: EdgeInsets.all(24),
    child: SizedBox(width: 1100, height: 760, child: UsoMaquinas()),
  ),
);

/// Calendario del mes con los activos planificados arriba: se arrastra cada uno a los días en que va a
/// trabajar (un turno); tocarlo en el día pasa a dos turnos y otra vez lo quita. Cada turno suma sus horas
/// al contador del activo, y con ellas se calculan sus mantenimientos por horas.
class UsoMaquinas extends StatefulWidget {
  const UsoMaquinas({super.key});

  @override
  State<UsoMaquinas> createState() => _UsoMaquinasState();
}

class _UsoMaquinasState extends State<UsoMaquinas> {
  DateTime mes = DateTime(hoy().year, hoy().month);

  List<Activo> get _planificados =>
      store.hijosDe(null).where((a) => a.activo && a.usoPlanificado).toList()
        ..sort((a, b) => a.titulo.compareTo(b.titulo));

  void _poner(Activo a, DateTime d, int n) {
    setState(() => ponerTurnos(a, d, n));
    store.guardarActivo(a);
  }

  @override
  Widget build(BuildContext context) {
    final activos = _planificados;
    final inicio = lunesDe(mes);
    final fin = DateTime(mes.year, mes.month + 1, 0);
    final semanas = ((fin.difference(inicio).inDays + 1) / 7).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uso de las máquinas',
                      style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Arrastra cada máquina a los días que trabaja. En el día: tocar = 2 turnos; otra vez = quitar.',
                      style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: () => setState(() => mes = DateTime(mes.year, mes.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${meses[mes.month - 1]} ${mes.year}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: () => setState(() => mes = DateTime(mes.year, mes.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Las máquinas «flotando» arriba, para arrastrarlas a los días.
          if (activos.isEmpty)
            Text(
              'Ninguna máquina tiene el uso «Planificado por turnos». Elígelo en Datos → Contador y uso.',
              style: TextStyle(fontSize: 13, color: P.textoSuave),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in activos)
                  Draggable<String>(
                    data: a.id,
                    feedback: Material(color: Colors.transparent, child: _Ficha(a, elevada: true)),
                    childWhenDragging: Opacity(opacity: .4, child: _Ficha(a)),
                    child: MouseRegion(cursor: SystemMouseCursors.grab, child: _Ficha(a)),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in diasSemana)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 6),
                    child: Text(d.toUpperCase(), style: TextStyle(fontSize: 11, color: P.textoSuave)),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(P.radio),
                border: Border.all(color: P.borde),
              ),
              child: Column(
                children: [
                  for (var s = 0; s < semanas; s++)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < 7; i++) Expanded(child: _dia(masDias(inicio, s * 7 + i), activos)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dia(DateTime d, List<Activo> activos) {
    final delMes = d.month == mes.month;
    final esHoy = DateUtils.isSameDay(d, hoy());
    return DragTarget<String>(
      onAcceptWithDetails: (det) {
        final a = store.activo(det.data);
        if (a != null) _poner(a, d, turnosDe(a, d) == 0 ? 1 : turnosDe(a, d));
      },
      builder: (context, encima, _) => Container(
        decoration: BoxDecoration(
          color: encima.isNotEmpty ? P.morado.withValues(alpha: .08) : (delMes ? P.superficie : P.fondo),
          border: Border(
            right: BorderSide(color: P.borde),
            bottom: BorderSide(color: P.borde),
          ),
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: esHoy ? FontWeight.w800 : FontWeight.w500,
                color: esHoy ? P.morado : (delMes ? P.texto : P.textoSuave),
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final a in activos)
                      if (turnosDe(a, d) case final n when n > 0)
                        Tooltip(
                          message: '${a.titulo}: $n ${n == 1 ? 'turno' : 'turnos'} · tocar para cambiar',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _poner(a, d, n == 1 ? 2 : 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: P.morado.withValues(alpha: n == 2 ? .22 : .1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${a.tag.isEmpty ? a.nombre : a.tag}${n == 2 ? ' ×2' : ''}',
                                style: TextStyle(fontSize: 11, color: P.morado, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una máquina para arrastrar: su icono y su nombre.
class _Ficha extends StatelessWidget {
  final Activo a;
  final bool elevada;
  const _Ficha(this.a, {this.elevada = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(P.radioControl),
      border: Border.all(color: elevada ? P.morado : P.borde),
      boxShadow: elevada ? [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 12)] : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconoActivo(a.icono, size: 18, color: P.textoSuave),
        const SizedBox(width: 8),
        Text(a.titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text('${a.horasTurno.toStringAsFixed(0)} h/turno', style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
      ],
    ),
  );
}
