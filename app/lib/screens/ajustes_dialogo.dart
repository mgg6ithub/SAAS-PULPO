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

/// Ajustes de la app, agrupados en tarjetas como los ajustes de iOS: cuenta, tema, letra, empresa y datos.
/// Simplificados (2026-11-19): sin color (siempre el morado de Pultec), sin tema del sistema, sin vista de
/// agenda ni lado de la barra lateral.
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
              // Tu cuenta: perfil, correo, contraseña, sesiones y borrarla (en su propia ventana).
              if (store.nube != null)
                _Grupo('Cuenta', [
                  _Fila(
                    titulo: Nube.correo ?? 'Tu cuenta',
                    subtitulo: 'Perfil, correo, contraseña, sesiones y borrar la cuenta',
                    child: Enlace('Editar', onTap: () => abrirCuenta(context)),
                  ),
                ]),
              _Grupo('Apariencia', [
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
              _Grupo('Empresa', [
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
              if (!(store.nube?.esTrabajador ?? false))
                _Grupo('Datos', [
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
                          if (await confirmar(
                            context,
                            '¿Borrar todos los datos y empezar de cero?',
                            accion: 'Borrar todo',
                          )) {
                            store.restablecer();
                          }
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
