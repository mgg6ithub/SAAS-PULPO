import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ajustes.dart';
import 'shell.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ajustes.cargar();
  // ?oscuro=1 / ?oscuro=0 fuerza el tema sin guardarlo (útil para capturas).
  final oscuro = Uri.base.queryParameters['oscuro'];
  if (oscuro != null) ajustes.tema = oscuro == '1' ? ThemeMode.dark : ThemeMode.light;
  await store.cargar();
  // ?demo=1 carga la empresa de ejemplo si la cuenta está vacía (útil para capturas).
  if (Uri.base.queryParameters['demo'] == '1' && store.clientes.isEmpty) store.cargarDemo();
  runApp(const PulpoApp());
}

class PulpoApp extends StatefulWidget {
  const PulpoApp({super.key});

  @override
  State<PulpoApp> createState() => _PulpoAppState();
}

class _PulpoAppState extends State<PulpoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    ajustes.addListener(_repintar);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    ajustes.removeListener(_repintar);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // El modo "Sistema" sigue al navegador si cambia en caliente.
  @override
  void didChangePlatformBrightness() => _repintar();

  /// Los colores de P se leen al construir: hay que reconstruir todo el árbol, no solo el tema.
  void _repintar() {
    setState(() {});
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    (context as Element).visitChildren(marcar);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pulpo',
    debugShowCheckedModeBanner: false,
    theme: temaPulpo(),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // Arrastrar con el ratón para el scroll horizontal de la vista principal.
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
    ),
    home: const Shell(),
  );
}
