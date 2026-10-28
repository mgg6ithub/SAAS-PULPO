import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Invitación para que un trabajador entre con su propia cuenta y vea solo sus trabajos.
Future<void> invitarTrabajador(BuildContext context, Trabajador w) => _ventana(
  context,
  titulo: 'Invitar a ${w.nombre}',
  texto: 'Entrará con su propia cuenta y solo verá sus trabajos.',
  crear: () => store.nube!.crearInvitacion(rol: 'trabajador', trabajadorId: w.id),
);

/// Invitación para un socio: ve y gestiona toda la empresa.
Future<void> invitarAdministrador(BuildContext context) => _ventana(
  context,
  titulo: 'Invitar a un socio',
  texto: 'Verá y gestionará toda la empresa, igual que tú.',
  crear: () => store.nube!.crearInvitacion(rol: 'admin'),
);

Future<void> _ventana(
  BuildContext context, {
  required String titulo,
  required String texto,
  required Future<String> Function() crear,
}) => showDialog<void>(
  context: context,
  builder: (c) => Dialog(
    backgroundColor: P.superficie,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(P.radio),
      side: BorderSide(color: P.borde),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _Enlace(titulo: titulo, texto: texto, crear: crear),
      ),
    ),
  ),
);

class _Enlace extends StatefulWidget {
  final String titulo, texto;
  final Future<String> Function() crear;
  const _Enlace({required this.titulo, required this.texto, required this.crear});

  @override
  State<_Enlace> createState() => _EnlaceState();
}

class _EnlaceState extends State<_Enlace> {
  String? _enlace;
  bool _fallo = false, _copiado = false;

  @override
  void initState() {
    super.initState();
    widget
        .crear()
        .then((c) {
          if (mounted) setState(() => _enlace = Nube.enlace(c));
        })
        .catchError((Object e) {
          debugPrint('Pulpo: no se pudo crear la invitación: $e');
          if (mounted) setState(() => _fallo = true);
        });
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.titulo,
              style: TextStyle(color: P.texto, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, size: 20, color: P.textoSuave),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(widget.texto, style: TextStyle(color: P.textoSuave, fontSize: 13.5, height: 1.4)),
      const SizedBox(height: 16),
      if (_fallo)
        Text('No se pudo crear la invitación. Inténtalo de nuevo.', style: TextStyle(color: P.rojo, fontSize: 13.5))
      else if (_enlace == null)
        const Center(
          child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else ...[
        Tarjeta(
          padding: const EdgeInsets.all(12),
          child: SelectableText(_enlace!, style: TextStyle(color: P.texto, fontSize: 13, height: 1.4)),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: BotonPrimario(
            _copiado ? 'Copiado' : 'Copiar enlace',
            icono: _copiado ? Icons.check_rounded : Icons.copy_rounded,
            conIcono: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _enlace!));
              if (mounted) setState(() => _copiado = true);
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Mándalo por WhatsApp o email. Vale una sola vez y caduca en 7 días.',
          style: TextStyle(color: P.textoSuave, fontSize: 12.5, height: 1.4),
        ),
      ],
    ],
  );
}
