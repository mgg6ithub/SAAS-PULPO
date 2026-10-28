import 'package:flutter/material.dart';

import '../informes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Punto del color del resultado: sustituye al icono en las filas de informes.
Widget puntoResultado(int resultado) => Container(
  width: 10,
  height: 10,
  decoration: BoxDecoration(color: coloresResultado[resultado], shape: BoxShape.circle),
);

/// Fila de un informe; al pulsarla se abre entero.
class FilaInforme extends StatelessWidget {
  final Informe i;
  final Tarea t;
  const FilaInforme(this.i, this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
    return FilaLista(
      lider: puntoResultado(i.resultado),
      titulo: resultadosInforme[i.resultado],
      subtitulo: [
        if (w != null) w.nombreCompleto,
        if (i.fotos.isNotEmpty) '${i.fotos.length} ${i.fotos.length == 1 ? 'foto' : 'fotos'}',
        i.notas,
      ].join(' · '),
      derecha: Text(
        '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}',
        style: TextStyle(fontSize: 12.5, color: P.textoSuave),
      ),
      onTap: () => verInforme(context, i, t),
    );
  }
}

/// Filas de los informes de un trabajo (nada si no tiene), para el histórico del administrador.
class InformesDelTrabajo extends StatelessWidget {
  final Tarea t;
  const InformesDelTrabajo(this.t, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: informes,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final i in informes.de(t.id) ?? const <Informe>[]) FilaInforme(i, t)],
    ),
  );
}

/// El informe entero: resultado, quién y cuándo, notas, fotos y descarga en PDF.
Future<void> verInforme(BuildContext context, Informe i, Tarea t) => showDialog(
  context: context,
  builder: (c) => Dialog(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _Informe(i, t)),
  ),
);

class _Informe extends StatefulWidget {
  final Informe i;
  final Tarea t;
  const _Informe(this.i, this.t);

  @override
  State<_Informe> createState() => _InformeState();
}

class _InformeState extends State<_Informe> {
  bool descargando = false;

  Future<void> _pdf() async {
    setState(() => descargando = true);
    try {
      await descargarInformePdf(widget.i, widget.t);
    } catch (e) {
      debugPrint('Pulpo: no se pudo crear el PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text('No se pudo crear el PDF')),
        );
      }
    }
    if (mounted) setState(() => descargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.i;
    final w = store.trabajadores.where((x) => x.id == i.trabajadorId).firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORME',
            style: TextStyle(color: P.morado, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            widget.t.nombre,
            style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(resultadosInforme[i.resultado], coloresResultado[i.resultado], punto: true),
              Text(
                [
                  '${fecha(i.cuando)} ${hhmm(i.cuando.hour * 60 + i.cuando.minute)}',
                  if (w != null) w.nombreCompleto,
                ].join(' · '),
                style: TextStyle(color: P.textoSuave, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(i.notas, style: const TextStyle(fontSize: 14, height: 1.45)),
          if (i.fotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in i.fotos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(P.radio),
                    child: FotoGuardada(f, width: 160, height: 120),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              const SizedBox(width: 8),
              BotonAccion(
                descargando ? 'Creando PDF…' : 'Descargar PDF',
                icono: Icons.download_rounded,
                onPressed: () => descargando ? null : _pdf(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
