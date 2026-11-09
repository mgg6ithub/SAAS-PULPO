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

  /// Color de cada máquina según su orden en la lista (estable mientras no cambien las máquinas).
  Color _colorDe(int i) => paletaActivos[i % paletaActivos.length];

  /// Horas planificadas de la máquina en el mes que se ve.
  double _horasMes(Activo a) {
    var t = 0;
    for (var d = DateTime(mes.year, mes.month); d.month == mes.month; d = masDias(d, 1)) {
      t += turnosDe(a, d);
    }
    return t * a.horasTurno;
  }

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
          const Consejo(
            'Arrastra una máquina a un día: 1 turno. Tócala: 2 turnos. Otra vez: quitar. '
            'Recalcula sus mantenimientos por horas.',
          ),
          const SizedBox(height: 12),
          if (activos.isEmpty)
            Text(
              'Ninguna máquina tiene el uso «Planificado por turnos». Elígelo en Datos → Contador y uso.',
              style: TextStyle(fontSize: 13, color: P.textoSuave),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Las máquinas, cada una con su color, para arrastrarlas a los días.
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (i, a) in activos.indexed)
                        Draggable<String>(
                          data: a.id,
                          feedback: Material(
                            color: Colors.transparent,
                            child: _Ficha(a, _colorDe(i), _horasMes(a), elevada: true),
                          ),
                          childWhenDragging: Opacity(opacity: .4, child: _Ficha(a, _colorDe(i), _horasMes(a))),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: _Ficha(a, _colorDe(i), _horasMes(a)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Leyenda: claro = 1 turno, lleno = 2 turnos.
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Muestra(P.textoSuave, 1),
                      const SizedBox(width: 6),
                      Text('1 turno', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                      const SizedBox(width: 14),
                      _Muestra(P.textoSuave, 2),
                      const SizedBox(width: 6),
                      Text('2 turnos', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                    ],
                  ),
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
        ],
      ),
    );
  }

  Widget _dia(DateTime d, List<Activo> activos) {
    final delMes = d.month == mes.month;
    final esHoy = DateUtils.isSameDay(d, hoy());
    final finde = d.weekday >= 6;
    return DragTarget<String>(
      onAcceptWithDetails: (det) {
        final a = store.activo(det.data);
        if (a != null) _poner(a, d, turnosDe(a, d) == 0 ? 1 : turnosDe(a, d));
      },
      builder: (context, encima, _) => Container(
        decoration: BoxDecoration(
          color: encima.isNotEmpty
              ? P.morado.withValues(alpha: .08)
              : !delMes
              ? P.fondo
              : finde
              ? Color.alphaBlend(P.fondo.withValues(alpha: .6), P.superficie)
              : P.superficie,
          border: Border(
            right: BorderSide(color: P.borde),
            bottom: BorderSide(color: P.borde),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hoy, en un círculo del color de la marca.
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: esHoy ? BoxDecoration(color: P.morado, shape: BoxShape.circle) : null,
              child: Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: esHoy ? FontWeight.w700 : FontWeight.w500,
                  color: esHoy ? Colors.white : (delMes ? P.texto : P.textoSuave),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, a) in activos.indexed)
                      if (turnosDe(a, d) case final n when n > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: _Turno(a, _colorDe(i), n, onTap: () => _poner(a, d, n == 1 ? 2 : 0)),
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

/// Una máquina en un día: su color, claro con 1 turno y lleno con 2.
class _Turno extends StatelessWidget {
  final Activo a;
  final Color color;
  final int n;
  final VoidCallback onTap;
  const _Turno(this.a, this.color, this.n, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lleno = n >= 2;
    final tinta = lleno ? Colors.white : color;
    return Tooltip(
      message:
          '${a.titulo}: $n ${n == 1 ? 'turno' : 'turnos'}, ${(n * a.horasTurno).toStringAsFixed(0)} h. Toca para cambiar',
      child: Material(
        color: lleno ? color : color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Row(
              children: [
                IconoActivo(a.icono, size: 13, color: tinta),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    a.tag.isEmpty ? a.nombre : a.tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tinta),
                  ),
                ),
                if (lleno)
                  Text(
                    '×2',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tinta),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra de la leyenda: claro (1 turno) o lleno (2 turnos).
class _Muestra extends StatelessWidget {
  final Color color;
  final int n;
  const _Muestra(this.color, this.n);

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 12,
    decoration: BoxDecoration(
      color: n >= 2 ? color : color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(3),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
  );
}

/// Una máquina para arrastrar: su color, icono, nombre y las horas planificadas del mes.
class _Ficha extends StatelessWidget {
  final Activo a;
  final Color color;
  final double horasMes;
  final bool elevada;
  const _Ficha(this.a, this.color, this.horasMes, {this.elevada = false});

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).width - 34).clamp(0, 440)),
    padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
    decoration: BoxDecoration(
      color: Color.alphaBlend(color.withValues(alpha: .06), P.superficie),
      borderRadius: BorderRadius.circular(P.radioControl),
      border: Border.all(color: elevada ? color : color.withValues(alpha: .35)),
      boxShadow: elevada ? [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 12)] : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconoActivo(a.icono, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                a.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${a.horasTurno.toStringAsFixed(0)} h por turno, ${horasMes.toStringAsFixed(0)} h este mes',
                style: TextStyle(fontSize: 11.5, color: P.textoSuave),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
