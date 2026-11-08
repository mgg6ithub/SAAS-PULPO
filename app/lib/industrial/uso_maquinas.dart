import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../screens/vista_dias.dart' show meses, diasSemana, lunesDe;
import 'activo.dart';
import 'iconos.dart';
import 'planes.dart' show turnosDe, ponerTurnos, horasHoy;

/// Abre el calendario de uso de las máquinas (activos con uso «Planificado por turnos»).
Future<void> abrirUsoMaquinas(BuildContext context) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => const Scaffold(body: SafeArea(child: UsoMaquinas())),
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
    final antes = horasHoy(a);
    setState(() => ponerTurnos(a, d, n));
    store.guardarActivo(a);
    if (d.isBefore(hoy())) {
      final cambio = horasHoy(a) - antes;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cambio == 0
                ? 'Turnos actualizados. La lectura real del contador se conserva.'
                : 'Turnos actualizados: ${cambio > 0 ? '+' : ''}${cambio.toStringAsFixed(1)} h estimadas. Fechas estimadas de mantenimiento recalculadas.',
          ),
        ),
      );
    }
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
          BarraVista(
            izquierda: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Volver a Activos',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 6),
                  const Flexible(child: TituloVista('Uso de activos')),
                ],
              ),
            ],
            derecha: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: () => setState(() => mes = DateTime(mes.year, mes.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('${meses[mes.month - 1]} ${mes.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: () => setState(() => mes = DateTime(mes.year, mes.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              TextButton(
                onPressed: () => setState(() => mes = DateTime(hoy().year, hoy().month)),
                child: const Text('Hoy'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Arrastra un activo a un día: 1 turno. Tócalo: 2 turnos. Otra vez: quitar.',
            style: TextStyle(fontSize: 13, color: P.textoSuave),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Pill('1 turno', P.azul, icono: Icons.looks_one_outlined),
              Pill('2 turnos', P.morado, icono: Icons.looks_two_outlined),
            ],
          ),
          const SizedBox(height: 10),
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
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: box.maxWidth < 840 ? 840 : box.maxWidth,
                  height: box.maxHeight,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: box.maxHeight < 420 ? 420 : box.maxHeight,
                      child: Column(
                        children: [
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
                                          for (var i = 0; i < 7; i++)
                                            Expanded(child: _dia(masDias(inicio, s * 7 + i), activos)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los cambios posteriores a la última lectura recalculan las horas estimadas y los mantenimientos por horas. Los turnos anteriores quedan como registro; no cambian una lectura real.',
            style: TextStyle(fontSize: 12, color: P.textoSuave),
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
                          message:
                              '${a.titulo}: $n ${n == 1 ? 'turno' : 'turnos'} · ${n * a.horasTurno} h · tocar para cambiar',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _poner(a, d, n == 1 ? 2 : 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: (n == 2 ? P.morado : P.azul).withValues(alpha: .12),
                                border: Border.all(color: (n == 2 ? P.morado : P.azul).withValues(alpha: .45)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${a.tag.isEmpty ? a.nombre : a.tag} · $n ${n == 1 ? 'turno' : 'turnos'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: n == 2 ? P.morado : P.azul,
                                  fontWeight: FontWeight.w600,
                                ),
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
    constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).width - 34).clamp(0, 440)),
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
        Flexible(
          child: Text(
            a.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        Text('${a.horasTurno.toStringAsFixed(0)} h/turno', style: TextStyle(fontSize: 11.5, color: P.textoSuave)),
      ],
    ),
  );
}
