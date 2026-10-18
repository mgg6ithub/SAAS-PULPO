import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ajustes básicos de la app: apariencia, vista de inicio y datos.
Future<void> abrirAjustes(BuildContext context) => showDialog(
  context: context,
  builder: (_) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListenableBuilder(
        listenable: ajustes,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONFIGURACIÓN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: P.morado),
                      ),
                      const Text('Ajustes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              _Fila(
                icono: Icons.dark_mode_outlined,
                titulo: 'Apariencia',
                subtitulo: 'Claro, oscuro o el del sistema',
                child: Pestanas(
                  opciones: const ['Claro', 'Oscuro', 'Sistema'],
                  seleccion: switch (ajustes.tema) {
                    ThemeMode.light => 0,
                    ThemeMode.dark => 1,
                    ThemeMode.system => 2,
                  },
                  onChanged: (i) => ajustes.ponerTema([ThemeMode.light, ThemeMode.dark, ThemeMode.system][i]),
                ),
              ),
              _Fila(
                icono: Icons.palette_outlined,
                titulo: 'Color',
                subtitulo: acentos[ajustes.acento].nombre,
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final (i, a) in acentos.indexed)
                      Tooltip(
                        message: a.nombre,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => ajustes.ponerAcento(i),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: a.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: i == ajustes.acento ? P.texto : Colors.transparent, width: 2),
                            ),
                            child: i == ajustes.acento
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _Fila(
                icono: Icons.space_dashboard_outlined,
                titulo: 'Vista de la agenda',
                subtitulo: 'Con la que se abre la Agenda',
                child: Pestanas(
                  opciones: const ['Día', 'Semana', 'Mes', 'Tablero', 'Línea'],
                  seleccion: ajustes.vistaInicio,
                  onChanged: ajustes.ponerVistaInicio,
                ),
              ),
              _Fila(
                icono: Icons.view_sidebar_outlined,
                titulo: 'Barra lateral',
                subtitulo: 'Mostrarla u ocultarla',
                child: Switch(value: !ajustes.barraOculta, onChanged: (_) => ajustes.alternarBarra()),
              ),
              const SizedBox(height: 8),
              Divider(color: P.borde),
              const SizedBox(height: 8),
              _Fila(
                icono: Icons.storage_outlined,
                titulo: 'Datos',
                subtitulo: 'Se guardan en este navegador',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: P.rojo),
                      onPressed: () async {
                        if (await confirmar(context, '¿Borrar todos los datos y empezar de cero?')) store.restablecer();
                      },
                      child: const Text('Borrar todo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

class _Fila extends StatelessWidget {
  final IconData icono;
  final String titulo, subtitulo;
  final Widget child;
  const _Fila({required this.icono, required this.titulo, required this.subtitulo, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitulo, style: TextStyle(fontSize: 12, color: P.textoSuave)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        child,
      ],
    ),
  );
}
