import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cuenta.dart';
import 'importar_exportar.dart';
import 'tipos_competencias.dart';
import '../marca.dart';

/// Ajustes de la app, como los Ajustes del Mac: a la izquierda tu cuenta y las secciones (con su icono de color);
/// a la derecha, la sección elegida con su cabecera y sus filas en tarjetas. Simplificados (2026-11-19): sin color
/// (siempre el morado de Pultec), sin tema del sistema, sin vista de agenda ni lado de la barra lateral.
Future<void> abrirAjustes(BuildContext context) => showDialog(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: P.fondo,
    clipBehavior: Clip.antiAlias,
    insetPadding: const EdgeInsets.all(24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: const _Ajustes(),
  ),
);

/// Sección de los ajustes: icono y color (cuadradito redondeado, como en el Mac), nombre y frase de su cabecera.
typedef _Seccion = (IconData, Color, String, String);

class _Ajustes extends StatefulWidget {
  const _Ajustes();

  @override
  State<_Ajustes> createState() => _AjustesState();
}

class _AjustesState extends State<_Ajustes> {
  int elegida = 0;

  List<_Seccion> get _secciones => [
    if (store.nube != null) (Icons.person_rounded, P.morado, 'Cuenta', 'Tu perfil, el correo y la contraseña, las sesiones abiertas y borrar la cuenta.'),
    (Icons.contrast_rounded, P.azul, 'Apariencia', 'Tema claro u oscuro, y el tamaño y el tipo de letra de toda la app.'),
    (Icons.business_rounded, P.ambar, 'Empresa', m('Los tipos de trabajo y las competencias de tus trabajadores.')),
    if (!(store.nube?.esTrabajador ?? false))
      (Icons.swap_vert_rounded, P.verde, 'Datos', m('Importar y exportar clientes, trabajadores y trabajos en CSV (Excel).')),
  ];

  Widget _cuadro(IconData icono, Color color, {double tam = 28}) => Container(
    width: tam,
    height: tam,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(tam * .26)),
    child: Icon(icono, size: tam * .62, color: Colors.white),
  );

  List<Widget> _contenido(String seccion) => switch (seccion) {
    'Cuenta' => [
      _Grupo(null, [
        _Fila(
          titulo: Nube.correo ?? 'Tu cuenta',
          subtitulo: 'Perfil, correo, contraseña, sesiones y borrar la cuenta',
          child: Enlace('Editar', onTap: () => abrirCuenta(context)),
        ),
      ]),
    ],
    'Apariencia' => [
      _Grupo(null, [
        _Fila(
          titulo: 'Tema',
          subtitulo: 'Claro u oscuro',
          child: Pestanas(
            opciones: const ['Claro', 'Oscuro'],
            seleccion: ajustes.tema == ThemeMode.dark ? 1 : 0,
            onChanged: (i) => ajustes.ponerTema(i == 1 ? ThemeMode.dark : ThemeMode.light),
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
            compactas: true,
            onChanged: ajustes.ponerTamanoLetra,
          ),
        ),
        _Fila(
          titulo: 'Tipo de letra',
          subtitulo: 'Atkinson se lee mejor con poca vista',
          child: Pestanas(
            opciones: const ['Geist', 'Inter', 'Atkinson'],
            seleccion: ajustes.fuente,
            compactas: true,
            onChanged: ajustes.ponerFuente,
          ),
        ),
      ]),
    ],
    'Empresa' => [
      _Grupo(null, [
        _Fila(
          titulo: m('Tipos de trabajo'),
          subtitulo: '${tipos.length} tipos, con su icono, color y competencia',
          child: Enlace('Editar', onTap: () => abrirTipos(context)),
        ),
        _Fila(
          titulo: 'Competencias',
          subtitulo: m('${competencias.length} competencias para trabajadores y trabajos'),
          child: Enlace('Editar', onTap: () => abrirCompetencias(context)),
        ),
      ]),
    ],
    _ => [
      _Grupo(null, [
        _Fila(
          titulo: 'Importar y exportar',
          subtitulo: m('Clientes, trabajadores y trabajos en CSV (Excel)'),
          child: Enlace('Abrir', onTap: () => abrirImportarExportar(context)),
        ),
        if (store.nube == null)
          _Fila(
            titulo: 'En este navegador',
            subtitulo: m('Tus clientes, trabajadores y trabajos'),
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: P.rojo),
              onPressed: () async {
                if (await confirmar(context, '¿Borrar todos los datos y empezar de cero?', accion: 'Borrar todo')) {
                  store.restablecer();
                }
              },
              child: const Text('Borrar todo'),
            ),
          ),
      ]),
    ],
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ajustes,
    builder: (context, _) {
      final secciones = _secciones;
      final (icono, color, nombre, frase) = secciones[elegida.clamp(0, secciones.length - 1)];
      final correo = Nube.correo;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 560),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra lateral: tu cuenta arriba y las secciones.
            Container(
              width: 220,
              decoration: BoxDecoration(
                color: P.barra,
                border: Border(right: BorderSide(color: P.borde)),
              ),
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (correo != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: P.morado,
                            child: Text(
                              correo.characters.first.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  correo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  store.nube?.nombre ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: P.textoSuave),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  for (final (i, (ic, c, n, _)) in secciones.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Material(
                        color: i == elegida ? P.morado : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          hoverColor: P.hover,
                          onTap: () => setState(() => elegida = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                            child: Row(
                              children: [
                                _cuadro(ic, i == elegida ? Colors.white.withValues(alpha: .22) : c, tam: 24),
                                const SizedBox(width: 10),
                                Text(
                                  n,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: i == elegida ? Colors.white : P.texto,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // La sección: cabecera centrada (icono, nombre, frase) y sus filas.
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: P.superficie,
                            borderRadius: BorderRadius.circular(P.radio),
                            border: Border.all(color: P.borde),
                          ),
                          child: Column(
                            children: [
                              _cuadro(icono, color, tam: 48),
                              const SizedBox(height: 10),
                              Text(
                                nombre,
                                style: TextStyle(
                                  fontFamily: P.titulos,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                frase,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: P.textoSuave, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        ..._contenido(nombre),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(CupertinoIcons.xmark, size: 17, color: P.textoSuave),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Grupo de ajustes: título pequeño encima y una tarjeta blanca con sus filas separadas por líneas.
class _Grupo extends StatelessWidget {
  final String? titulo;
  final List<Widget> filas;
  const _Grupo(this.titulo, this.filas);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titulo != null)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titulo!,
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
    // El control (Editar, Abrir, pestañas) arriba a la derecha, a la altura del título.
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.topRight,
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topRight, child: child),
          ),
        ),
      ],
    ),
  );
}
