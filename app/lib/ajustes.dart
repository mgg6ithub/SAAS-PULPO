import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de la app (no son datos de negocio). Se guardan en el navegador.
class Ajustes extends ChangeNotifier {
  SharedPreferences? _prefs;

  ThemeMode tema = ThemeMode.light;
  bool barraOculta = false;

  /// Vista con la que abre Inicio: 0 Días, 1 Calendario, 2 Tablero.
  int vistaInicio = 0;

  /// Índice en `acentos` (theme.dart); 0 es el morado del logo.
  int acento = 0;

  Future<void> cargar() async {
    _prefs = await SharedPreferences.getInstance();
    tema = ThemeMode.values[_prefs!.getInt('ajustes_tema') ?? ThemeMode.light.index];
    barraOculta = _prefs!.getBool('ajustes_barra_oculta') ?? false;
    vistaInicio = _prefs!.getInt('ajustes_vista_inicio') ?? 0;
    acento = _prefs!.getInt('ajustes_acento') ?? 0;
  }

  /// Si la app se pinta en oscuro ahora mismo (el modo sistema mira el del navegador).
  bool get oscuro => switch (tema) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
  };

  void ponerTema(ThemeMode t) {
    tema = t;
    _prefs?.setInt('ajustes_tema', t.index);
    notifyListeners();
  }

  void alternarBarra() {
    barraOculta = !barraOculta;
    _prefs?.setBool('ajustes_barra_oculta', barraOculta);
    notifyListeners();
  }

  void ponerAcento(int i) {
    acento = i;
    _prefs?.setInt('ajustes_acento', i);
    notifyListeners();
  }

  void ponerVistaInicio(int v) {
    vistaInicio = v;
    _prefs?.setInt('ajustes_vista_inicio', v);
    notifyListeners();
  }
}

final ajustes = Ajustes();
