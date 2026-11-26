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
import '../plataforma_io.dart' if (dart.library.js_interop) '../plataforma_web.dart';

/// Ajustes de la app: a la izquierda tu cuenta y las secciones (como la barra lateral de Pultec); a la derecha,
/// la sección elegida con su título y sus filas en tarjetas. Simplificados (2026-11-19): sin color
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

/// Sección de los ajustes: icono de línea y su color al elegirla, nombre y frase de su cabecera.
typedef _Seccion = (IconData, Color, String, String);

class _Ajustes extends StatefulWidget {
  const _Ajustes();

  @override
  State<_Ajustes> createState() => _AjustesState();
}

/// Versión que se enseña en Ajustes (la de pubspec.yaml).
const versionApp = '0.1.1';

class _AjustesState extends State<_Ajustes> {
  static const _altoFila = 40.0, _huecoFila = 4.0;
  int elegida = 0;

  List<_Seccion> get _secciones => [
    if (store.nube != null)
      (
        Icons.person_outline_rounded,
        P.morado,
        'Cuenta',
        'Tu perfil, el correo y la contraseña, las sesiones abiertas y borrar la cuenta.',
      ),
    if (industrial && (store.nube?.esAdmin ?? false))
      (
        Icons.workspace_premium_outlined,
        P.morado,
        'Plan',
        'El plan de tu empresa, el pago con tarjeta y las facturas.',
      ),
    if (industrial && (store.nube?.esAdmin ?? false))
      (
        Icons.bolt_rounded,
        P.ambar,
        'Automatizaciones',
        'Correos que salen solos: a quién avisar cuando hay una incidencia o vence una orden.',
      ),
    (
      Icons.contrast_rounded,
      P.morado,
      'Apariencia',
      'Tema claro u oscuro, y el tamaño y el tipo de letra de toda la app.',
    ),
    (Icons.business_outlined, P.morado, 'Empresa', m('Los tipos de trabajo y las competencias de tus trabajadores.')),
    (Icons.keyboard_outlined, P.morado, 'Atajos', 'Atajos de teclado para moverte por la app sin el ratón.'),
    if (!(store.nube?.esTrabajador ?? false))
      (
        Icons.swap_vert_rounded,
        P.morado,
        'Datos',
        m('Importar y exportar clientes, trabajadores y trabajos en CSV (Excel).'),
      ),
  ];

  List<Widget> _contenido(String seccion) => switch (seccion) {
    'Cuenta' => [
      _Grupo(null, [
        _Fila(
          titulo: Nube.correo ?? 'Tu cuenta',
          subtitulo: 'Perfil, correo, contraseña, sesiones y borrar la cuenta',
          child: Enlace('Editar', onTap: () => abrirCuenta(context)),
        ),
      ]),
      if (industrial)
        _Grupo('Pultec', [
          _Fila(
            titulo: 'Web de Pultec',
            subtitulo: 'Planes, precios y preguntas frecuentes',
            child: Enlace('Abrir', onTap: () => abrirEnlace(_landingConTema())),
          ),
        ]),
    ],
    'Plan' => [const _PlanEmpresa()],
    'Automatizaciones' => [const _Automatizaciones()],
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
        if (!industrial)
          _Fila(
            titulo: 'Competencias',
            subtitulo: m('${competencias.length} competencias para trabajadores y trabajos'),
            child: Enlace('Editar', onTap: () => abrirCompetencias(context)),
          ),
      ]),
    ],
    'Atajos' => [
      _Grupo('General', [
        _Atajo('Crear algo nuevo en la sección en la que estás', ['N']),
        _Atajo('Abrir o cerrar el menú Crear', ['T']),
        _Atajo('Ir a una sección de la barra lateral (1 Inicio, 2 ${industrial ? 'Planificación' : 'Itinerario'}…)', [
          '1',
          '…',
          '9',
        ]),
        _Atajo('Cerrar una ventana o un menú', ['Esc']),
      ]),
      _Grupo(
        m(
          'Listas (${industrial ? 'activos, órdenes de trabajo, incidencias, técnicos…' : 'clientes, trabajos, trabajadores…'})',
        ),
        [
          _Atajo('Marcar la primera fila', ['Espacio']),
          _Atajo('Bajar o subir a la fila siguiente', ['↓', '↑']),
          _Atajo('Abrir la fila marcada', ['Espacio', 'Intro']),
          _Atajo('Moverse por las celdas de la fila', ['←', '→']),
          _Atajo('Quitar la marca', ['Esc']),
        ],
      ),
      _Grupo(industrial ? 'Planificación' : 'Itinerario', [
        if (industrial) _Atajo('Ver el siguiente mantenimiento en el calendario', ['Espacio']),
        _Atajo('Acercar o alejar el calendario', ['Ctrl', '+', '−']),
        _Atajo('Acercar o alejar con la rueda', ['Ctrl', 'Rueda']),
      ]),
      _Grupo('Fotos', [
        _Atajo('Foto anterior o siguiente', ['←', '→']),
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
      final (_, _, nombre, frase) = secciones[elegida.clamp(0, secciones.length - 1)];
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
                  // Como la barra lateral de la app: un único fondo blanco que se desliza a la elegida; las filas,
                  // sin onda, solo cambian de color.
                  Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        top: elegida * (_altoFila + _huecoFila),
                        left: 0,
                        right: 0,
                        height: _altoFila,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: P.seleccionBarra,
                            borderRadius: BorderRadius.circular(P.radioControl),
                            boxShadow: P.sombraSeleccionBarra,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          for (final (i, (ic, _, n, _)) in secciones.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: _huecoFila),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(P.radioControl),
                                mouseCursor: SystemMouseCursors.click,
                                splashFactory: NoSplash.splashFactory,
                                highlightColor: Colors.transparent,
                                hoverColor: P.hoverBarra,
                                onTap: () => setState(() => elegida = i),
                                child: SizedBox(
                                  height: _altoFila,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      children: [
                                        TweenAnimationBuilder<Color?>(
                                          tween: ColorTween(
                                            end: i == elegida ? P.iconoBarraElegido : P.textoBarraSuave,
                                          ),
                                          duration: const Duration(milliseconds: 200),
                                          builder: (_, c, _) => Icon(ic, size: 20, color: c),
                                        ),
                                        const SizedBox(width: 12),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 200),
                                          style: TextStyle(
                                            fontFamily: P.titulos,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: i == elegida ? P.textoBarraElegido : P.textoBarra,
                                          ),
                                          child: Text(n),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Abajo del todo: la app y su versión.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        // Logo y nombre llevan a la web de Pultec (la landing).
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => abrirEnlace(_landingConTema()),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const LogoPultec(size: 26),
                                const SizedBox(width: 8),
                                Text(
                                  Marca.nombre,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: P.textoSuave),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text('versión $versionApp', style: TextStyle(fontSize: 12, color: P.textoSuave)),
                      ],
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
                        // Título de la sección y su frase, como las cabeceras de las vistas.
                        Padding(
                          padding: const EdgeInsets.only(right: 32, bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: TextStyle(
                                  fontFamily: P.titulos,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(frase, style: TextStyle(fontSize: 13.5, color: P.textoSuave, height: 1.4)),
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

/// Fila de la pestaña Atajos: qué hace a la izquierda y sus teclas a la derecha.
class _Atajo extends StatelessWidget {
  final String texto;
  final List<String> teclas;
  const _Atajo(this.texto, this.teclas);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(
      children: [
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
        const SizedBox(width: 12),
        for (final (i, t) in teclas.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          t == '…'
              ? Text('…', style: TextStyle(color: P.textoSuave))
              : Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: P.fondo,
                    borderRadius: BorderRadius.circular(6),
                    border: Border(
                      top: BorderSide(color: P.borde),
                      left: BorderSide(color: P.borde),
                      right: BorderSide(color: P.borde),
                      bottom: BorderSide(color: P.borde, width: 2),
                    ),
                  ),
                  child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
        ],
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

/// Automatizaciones de la empresa (solo el admin): por cada ocasión (incidencia nueva u OT vencida), los correos a
/// los que se avisa. Cada uno se puede pausar o quitar; abajo, uno nuevo.
class _Automatizaciones extends StatefulWidget {
  const _Automatizaciones();

  @override
  State<_Automatizaciones> createState() => _AutomatizacionesState();
}

class _AutomatizacionesState extends State<_Automatizaciones> {
  static const _eventos = [
    (
      'incidencia',
      'Cuando hay una incidencia',
      'Cualquier incidencia nueva, de cualquier gravedad, la avise un técnico o la oficina.',
    ),
    ('ot_vencida', 'Cuando vence una orden de trabajo', 'Cuando pasa su fecha sin completarse. Un correo por orden.'),
  ];

  List<AvisoCorreo>? _avisos;
  bool _error = false;
  final _nuevos = {for (final e in _eventos) e.$1: TextEditingController()};
  final _avisoCampo = <String, String?>{};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _nuevos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await store.nube!.avisosCorreo();
      if (mounted) {
        setState(() {
          _avisos = r;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  static final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _anadir(String evento) async {
    final c = _nuevos[evento]!;
    final correo = c.text.trim().toLowerCase();
    if (!_correoValido.hasMatch(correo)) {
      setState(() => _avisoCampo[evento] = 'Escribe un correo válido (nombre@empresa.com).');
      return;
    }
    if (_avisos!.any((a) => a.evento == evento && a.correo == correo)) {
      setState(() => _avisoCampo[evento] = 'Ese correo ya está.');
      return;
    }
    try {
      await store.nube!.crearAvisoCorreo(evento, correo);
      c.clear();
      _avisoCampo[evento] = null;
      await _cargar();
    } catch (_) {
      if (mounted) setState(() => _avisoCampo[evento] = 'No se pudo guardar. Vuelve a intentarlo.');
    }
  }

  Future<void> _cambiar(Future<void> Function() accion) async {
    try {
      await accion();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(const SnackBar(content: Text('No se pudo guardar el cambio.')));
      }
    }
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return _Grupo(null, [
        _Fila(
          titulo: 'No se pudieron cargar',
          subtitulo: 'Comprueba la conexión',
          child: Enlace('Reintentar', onTap: _cargar),
        ),
      ]);
    }
    final avisos = _avisos;
    if (avisos == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: P.morado)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (evento, titulo, detalle) in _eventos)
          _Grupo(titulo, [
            for (final a in avisos.where((a) => a.evento == evento))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline_rounded, size: 18, color: a.activa ? P.ambar : P.textoSuave),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.correo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: a.activa ? P.texto : P.textoSuave),
                      ),
                    ),
                    Tooltip(
                      message: a.activa ? 'Pausar' : 'Reanudar',
                      child: Switch(
                        value: a.activa,
                        onChanged: (v) => _cambiar(() => store.nube!.activarAvisoCorreo(a.id, v)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      onPressed: () => _cambiar(() => store.nube!.borrarAvisoCorreo(a.id)),
                      icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                    ),
                  ],
                ),
              ),
            // Añadir un correo a esta ocasión (Intro o «Añadir»).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detalle, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nuevos[evento],
                          keyboardType: TextInputType.emailAddress,
                          onSubmitted: (_) => _anadir(evento),
                          onChanged: (_) {
                            if (_avisoCampo[evento] != null) setState(() => _avisoCampo[evento] = null);
                          },
                          decoration: InputDecoration(
                            hintText: 'correo@empresa.com',
                            isDense: true,
                            errorText: _avisoCampo[evento],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      BotonAccion('Añadir', icono: Icons.add_rounded, onPressed: () => _anadir(evento)),
                    ],
                  ),
                ],
              ),
            ),
          ]),
      ],
    );
  }
}

/// Plan de la empresa (solo el admin): el actual con su estado y, según el caso, pasar a Premium o gestionarlo en
/// el portal de Stripe. El pago y las facturas los pone Stripe; aquí solo se enseña y se lleva allí.
class _PlanEmpresa extends StatefulWidget {
  const _PlanEmpresa();

  @override
  State<_PlanEmpresa> createState() => _PlanEmpresaState();
}

class _PlanEmpresaState extends State<_PlanEmpresa> {
  late Future<PlanEmpresa> _plan = store.nube!.planEmpresa();
  bool _yendo = false;

  static String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Lleva a Stripe (pago o portal) en esta misma pestaña; Stripe devuelve a la app al terminar.
  Future<void> _ir(Future<String> Function() url) async {
    setState(() => _yendo = true);
    try {
      irA(await url());
    } on YaPremium {
      irA(await store.nube!.urlPortal());
    } catch (_) {
      if (!mounted) return;
      setState(() => _yendo = false);
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('No se pudo abrir Stripe. Vuelve a intentarlo en un momento.')));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PlanEmpresa>(
    future: _plan,
    builder: (context, s) {
      if (s.hasError) {
        return _Grupo(null, [
          _Fila(
            titulo: 'No se pudo cargar el plan',
            subtitulo: 'Comprueba la conexión',
            child: Enlace('Reintentar', onTap: () => setState(() => _plan = store.nube!.planEmpresa())),
          ),
        ]);
      }
      if (!s.hasData || _yendo) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: P.morado)),
              const SizedBox(width: 12),
              Text(_yendo ? 'Abriendo Stripe…' : 'Cargando el plan…'),
            ],
          ),
        );
      }
      final p = s.data!;
      final pagina = nube.urlPago;
      final (estado, color) = switch (p) {
        PlanEmpresa(premium: false) => ('Gratis', P.morado),
        PlanEmpresa(pagoPendiente: true) => ('Pago pendiente', P.rojo),
        PlanEmpresa(cancelaAlFinal: true) => ('Cancelado', P.ambar),
        _ => ('Activo', P.verde),
      };
      final detalle = switch (p) {
        PlanEmpresa(premium: false) => '1 planta, hasta 15 activos y 2 técnicos',
        PlanEmpresa(pagoPendiente: true) => 'Falló el último cobro: actualiza la tarjeta para no perder Premium',
        PlanEmpresa(cancelaAlFinal: true, fin: final f?) => 'Sigue activo hasta el ${_fecha(f)}; después pasa a Básico',
        PlanEmpresa(periodo: 'anual', fin: final f?) => '468 € al año + IVA · se renueva el ${_fecha(f)}',
        PlanEmpresa(fin: final f?) => '49 € al mes + IVA · se renueva el ${_fecha(f)}',
        _ => 'Activo',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Grupo(null, [
            _Fila(titulo: p.premium ? 'Premium' : 'Básico', subtitulo: detalle, child: Etiqueta(estado, color)),
          ]),
          if (!p.premium)
            _Grupo('Pasar a Premium', [
              _Fila(
                titulo: 'Mensual',
                subtitulo: '49 € al mes + IVA',
                child: Enlace('Elegir', onTap: () => _ir(() => pagina('mensual'))),
              ),
              _Fila(
                titulo: 'Anual',
                subtitulo: '39 € al mes (468 € al año) + IVA · ahorras 120 € al año',
                child: Enlace('Elegir', onTap: () => _ir(() => pagina('anual'))),
              ),
            ]),
          if (p.conCliente)
            _Grupo('Facturación', [
              _Fila(
                titulo: 'Gestionar en Stripe',
                subtitulo: 'Tarjeta, mensual o anual, facturas y cancelar',
                child: Enlace('Abrir', onTap: () => _ir(store.nube!.urlPortal)),
              ),
            ]),
        ],
      );
    },
  );

  Nube get nube => store.nube!;
}

/// La landing con el tema de la app, para que se abra igual (claro u oscuro).
String _landingConTema() {
  final u = Uri.parse(landingUrl);
  return u.replace(queryParameters: {...u.queryParameters, 'tema': ajustes.oscuro ? 'oscuro' : 'claro'}).toString();
}
