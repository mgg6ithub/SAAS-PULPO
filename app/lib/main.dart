import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ajustes.dart';
import 'columnas.dart';
import 'marca.dart';
import 'nube.dart';
import 'plataforma_io.dart' if (dart.library.js_interop) 'plataforma_web.dart';
import 'screens/acceso.dart';
import 'shell.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ajustes.cargar();
  // ?oscuro=1 / ?oscuro=0 fuerza el tema sin guardarlo (útil para capturas).
  // ?barra=64 / ?barra=600 fija el ancho de la barra lateral (capturas).
  final barra = double.tryParse(Uri.base.queryParameters['barra'] ?? '');
  if (barra != null) ajustes.anchoBarra = barra;
  final oscuro = Uri.base.queryParameters['oscuro'];
  if (oscuro != null) ajustes.tema = oscuro == '1' ? ThemeMode.dark : ThemeMode.light;
  // ?tema=oscuro / ?tema=claro: el tema de la landing al pulsar Entrar o crear cuenta. Se guarda y se quita de la
  // dirección, así el acceso, el nombre de la empresa y la app siguen con el aspecto de la landing.
  final tema = Uri.base.queryParameters['tema'];
  if (tema == 'oscuro' || tema == 'claro') {
    ajustes.ponerTema(tema == 'oscuro' ? ThemeMode.dark : ThemeMode.light);
    quitarDeLaDireccion('tema');
  }
  // Por defecto, con Supabase. ?local=1 abre la versión de pruebas con datos en el navegador.
  final local = Uri.base.queryParameters['local'] == '1';
  if (local) {
    await store.cargar();
    await columnasTablas.abrir('local');
    // La rama de revisión abre con veinte trabajos simultáneos; ?calendarioDemo=0 los desactiva.
    if (Uri.base.queryParameters['calendarioDemo'] != '0') {
      store.cargarSimulacion(
        equipo: 1,
        cuentas: 20,
        cantidadTareas: 20,
        desde: DateTime(2026, 10, 28),
        hasta: DateTime(2026, 10, 28),
        permitirSolapes: true,
        trabajosSimultaneos: 20,
      );
    }
    // ?demo=1 carga la empresa de ejemplo si la cuenta está vacía (útil para capturas).
    if (Uri.base.queryParameters['demo'] == '1' && store.clientes.isEmpty) store.cargarDemo();
  } else {
    await Nube.iniciar();
    await Nube.recordarInvitacion(Uri.base.queryParameters['invitacion']);
    await Nube.recordarPlan(Uri.base.queryParameters);
  }
  if (industrial) ponerPestana('favicon.png', Marca.nombre);
  runApp(PultecApp(local: local));
}

class PultecApp extends StatefulWidget {
  /// Sin Supabase: datos en el navegador (pruebas y capturas).
  final bool local;
  const PultecApp({super.key, this.local = true});

  @override
  State<PultecApp> createState() => _PultecAppState();
}

class _PultecAppState extends State<PultecApp> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Cambio de claro a oscuro con un fundido: una foto de la pantalla con el tema anterior se desvanece encima del
  // nuevo (la app se repinta una sola vez, debajo).
  final _raiz = GlobalKey();
  late final _fundido = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  ui.Image? _foto;
  late bool _oscuro = ajustes.oscuro;

  @override
  void initState() {
    super.initState();
    ajustes.addListener(_repintar);
    WidgetsBinding.instance.addObserver(this);
    _fundido.addStatusListener((e) {
      if (e == AnimationStatus.completed && _foto != null) {
        final f = _foto;
        setState(() => _foto = null);
        f!.dispose();
      }
    });
  }

  @override
  void dispose() {
    ajustes.removeListener(_repintar);
    WidgetsBinding.instance.removeObserver(this);
    _fundido.dispose();
    _foto?.dispose();
    super.dispose();
  }

  // El modo "Sistema" sigue al navegador si cambia en caliente.
  @override
  void didChangePlatformBrightness() => _repintar();

  /// Los colores de P se leen al construir: hay que reconstruir todo el árbol, no solo el tema. Si cambia de claro
  /// a oscuro, antes se fotografía la pantalla para fundir un tema con el otro.
  Future<void> _repintar() async {
    if (ajustes.oscuro != _oscuro) {
      _oscuro = ajustes.oscuro;
      final caja = _raiz.currentContext?.findRenderObject();
      if (caja is RenderRepaintBoundary && !caja.debugNeedsPaint) {
        try {
          final foto = await caja.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
          if (!mounted) return foto.dispose();
          _foto?.dispose();
          _foto = foto;
          _fundido.forward(from: 0);
        } catch (_) {
          // Sin foto (p. ej. el renderizador no la admite): el cambio sale de golpe, como antes.
        }
      }
    }
    if (!mounted) return;
    setState(() {});
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    (context as Element).visitChildren(marcar);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _raiz, child: _app()),
        if (_foto case final foto?)
          IgnorePointer(
            child: FadeTransition(
              opacity: ReverseAnimation(CurvedAnimation(parent: _fundido, curve: Curves.easeOutCubic)),
              child: RawImage(image: foto, fit: BoxFit.fill),
            ),
          ),
      ],
    ),
  );

  Widget _app() => MaterialApp(
    title: Marca.nombre,
    debugShowCheckedModeBanner: false,
    theme: temaPultec(),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // Arrastrar con el ratón para el scroll horizontal de la vista principal. Sin rebote: en el Mac la web
    // rebotaba y dejaba "desplazar" vistas que ya caben enteras.
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
      physics: const ClampingScrollPhysics(),
    ),
    // Tamaño de letra de Ajustes (accesibilidad): escala todo el texto, ventanas incluidas.
    // El Scaffold de fuera envuelve al navegador: los avisos (SnackBar) salen en él, por encima de las ventanas
    // emergentes y su fondo oscuro, aunque se lancen desde una de ellas.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(ajustes.escalaTexto)),
      child: Scaffold(backgroundColor: P.fondo, resizeToAvoidBottomInset: false, body: child!),
    ),
    home: widget.local ? const Shell() : const PuertaNube(),
  );
}
