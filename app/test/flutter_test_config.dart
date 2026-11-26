import 'dart:async';

import 'package:pultec/screens/resumen.dart' show animacionesGuia;

/// Configuración de todas las pruebas. «Primeros pasos» tiene animaciones sin fin y `pumpAndSettle` no
/// terminaría nunca: aquí se dejan fijas.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  animacionesGuia = false;
  await testMain();
}
