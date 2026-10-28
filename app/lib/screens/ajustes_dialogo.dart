import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ajustes de la app, agrupados en tarjetas como los ajustes de iOS: apariencia, letra, agenda,
/// barra lateral y datos.
Future<void> abrirAjustes(BuildContext context) => showDialog(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: P.fondo,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: ListenableBuilder(
        listenable: ajustes,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 22, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONFIGURACIÓN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                            color: P.morado,
                          ),
                        ),
                        Text(
                          'Ajustes',
                          style: TextStyle(
                            fontFamily: P.titulos,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(CupertinoIcons.xmark, size: 19, color: P.textoSuave),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _Grupo('Apariencia', [
                _Fila(
                  titulo: 'Tema',
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
                  titulo: 'Color',
                  subtitulo: acentos[ajustes.acento].nombre,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
              ]),
              _Grupo('Letra', [
                _Fila(
                  titulo: 'Tamaño',
                  subtitulo: 'Para toda la interfaz y las ventanas',
                  child: Pestanas(
                    opciones: const ['Normal', 'Grande', 'Más grande', 'Máxima'],
                    seleccion: ajustes.tamanoLetra,
                    onChanged: ajustes.ponerTamanoLetra,
                  ),
                ),
                _Fila(
                  titulo: 'Tipo de letra',
                  subtitulo: 'Atkinson se lee mejor con poca vista',
                  child: Pestanas(
                    opciones: const ['Geist', 'Inter', 'Atkinson'],
                    seleccion: ajustes.fuente,
                    onChanged: ajustes.ponerFuente,
                  ),
                ),
              ]),
              _Grupo('Agenda', [
                _Fila(
                  titulo: 'Vista al abrir',
                  subtitulo: 'Con la que se abre el itinerario',
                  child: Pestanas(
                    opciones: const ['Pulpo', 'Calendario'],
                    seleccion: ajustes.vistaInicio,
                    onChanged: ajustes.ponerVistaInicio,
                  ),
                ),
              ]),
              _Grupo('Barra lateral', [
                _Fila(
                  titulo: 'Lado',
                  subtitulo: 'Dónde va la barra lateral',
                  child: Pestanas(
                    opciones: const ['Izquierda', 'Derecha'],
                    seleccion: ajustes.barraDerecha ? 1 : 0,
                    onChanged: (i) => ajustes.ponerBarraDerecha(i == 1),
                  ),
                ),
              ]),
              if (store.nube == null)
                _Grupo('Datos', [
                  _Fila(
                    titulo: 'En este navegador',
                    subtitulo: 'Tus clientes, trabajadores y trabajos',
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: P.rojo),
                      onPressed: () async {
                        if (await confirmar(context, '¿Borrar todos los datos y empezar de cero?')) store.restablecer();
                      },
                      child: const Text('Borrar todo'),
                    ),
                  ),
                ]),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// Grupo de ajustes: título pequeño encima y una tarjeta blanca con sus filas separadas por líneas.
class _Grupo extends StatelessWidget {
  final String titulo;
  final List<Widget> filas;
  const _Grupo(this.titulo, this.filas);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titulo,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.textoSuave),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: P.superficie,
            borderRadius: BorderRadius.circular(P.radio),
            border: Border.all(color: P.borde),
          ),
          child: Column(
            children: [
              for (final (i, f) in filas.indexed) ...[if (i > 0) Divider(height: 1, color: P.borde, indent: 16), f],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Fila extends StatelessWidget {
  final String titulo, subtitulo;
  final Widget child;
  const _Fila({required this.titulo, required this.subtitulo, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              Text(subtitulo, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Con letra grande, el control se encoge en vez de salirse.
        Flexible(
          flex: 2,
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: child),
        ),
      ],
    ),
  );
}
