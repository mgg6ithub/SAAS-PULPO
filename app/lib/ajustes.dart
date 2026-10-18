import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de la app (no son datos de negocio). Se guardan en el navegador.
class Ajustes extends ChangeNotifier {
  SharedPreferences? _prefs;

  ThemeMode tema = ThemeMode.light;
  bool barraOculta = false;

  /// Vista con la que abre la Agenda: 0 Día, 1 Semana, 2 Mes, 3 Tablero.
  int vistaInicio = 1;

  /// Ancho de la barra lateral, ajustable arrastrando su borde. Por debajo de [anchoTextos]
  /// se queda en solo iconos ([anchoIconos]). El máximo es un 25 % de la ventana.
  static const anchoIconos = 64.0, anchoTextos = 170.0;
  double anchoBarra = 248;

  /// Último ancho expandido, para volver a él al pulsar "expandir".
  double anchoExpandido = 248;

  bool get barraContraida => anchoBarra <= anchoIconos;

  /// Índice en `acentos` (theme.dart); 0 es el morado del logo.
  int acento = 0;

  Future<void> cargar() async {
    _prefs = await SharedPreferences.getInstance();
    tema = ThemeMode.values[_prefs!.getInt('ajustes_tema') ?? ThemeMode.light.index];
    barraOculta = _prefs!.getBool('ajustes_barra_oculta') ?? false;
    vistaInicio = _prefs!.getInt('ajustes_vista_agenda') ?? 1;
    acento = _prefs!.getInt('ajustes_acento') ?? 0;
    anchoBarra = _prefs!.getDouble('ajustes_ancho_barra') ?? 248;
    anchoExpandido = _prefs!.getDouble('ajustes_ancho_expandido') ?? 248;
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

  /// Fija el ancho; si queda por debajo del mínimo con textos, se pliega a solo iconos.
  void ponerAnchoBarra(double a, {double max = 2000}) {
    // Entre solo iconos y el mínimo con textos, se queda en lo más cercano.
    anchoBarra = a < anchoTextos
        ? (a < (anchoIconos + anchoTextos) / 2 ? anchoIconos : anchoTextos)
        : a.clamp(anchoTextos, max);
    if (anchoBarra > anchoIconos) {
      anchoExpandido = anchoBarra;
      _prefs?.setDouble('ajustes_ancho_expandido', anchoExpandido);
    }
    _prefs?.setDouble('ajustes_ancho_barra', anchoBarra);
    notifyListeners();
  }

  void alternarContraida() => ponerAnchoBarra(barraContraida ? anchoExpandido : anchoIconos);

  void ponerAcento(int i) {
    acento = i;
    _prefs?.setInt('ajustes_acento', i);
    notifyListeners();
  }

  void ponerVistaInicio(int v) {
    vistaInicio = v;
    _prefs?.setInt('ajustes_vista_agenda', v);
    notifyListeners();
  }
}

final ajustes = Ajustes();
