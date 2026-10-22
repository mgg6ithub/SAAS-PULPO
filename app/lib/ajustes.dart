import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de la app (no son datos de negocio). Se guardan en el navegador.
class Ajustes extends ChangeNotifier {
  SharedPreferences? _prefs;

  ThemeMode tema = ThemeMode.light;

  /// La barra lateral a la derecha en vez de a la izquierda.
  bool barraDerecha = false;

  /// Tamaño de la letra de toda la interfaz (accesibilidad): índice en [escalas].
  static const escalas = [1.0, 1.12, 1.25, 1.4];
  int tamanoLetra = 0;
  double get escalaTexto => escalas[tamanoLetra.clamp(0, escalas.length - 1)];

  /// Tipo de letra: índice en `fuentes` (theme.dart).
  int fuente = 0;

  /// Vista con la que abre la Agenda: 0 Día, 1 Semana, 2 Mes, 3 Tablero.
  int vistaInicio = 1;

  /// Ancho de la barra lateral, ajustable arrastrando su borde. Por debajo de [anchoTextos]
  /// se queda en solo iconos ([anchoIconos]). El máximo es un 25 % de la ventana.
  static const anchoIconos = 64.0, anchoTextos = 170.0;
  double anchoBarra = 248;

  /// Último ancho expandido, para volver a él al pulsar "expandir".
  double anchoExpandido = 248;

  bool get barraContraida => anchoBarra <= anchoIconos;

  /// Aviso propio del ancho de la barra: solo repinta la barra, no toda la app (como [notifyListeners]).
  final cambioBarra = ValueNotifier<int>(0);

  /// Índice en `acentos` (theme.dart); 0 es el morado del logo.
  int acento = 0;

  Future<void> cargar() async {
    _prefs = await SharedPreferences.getInstance();
    tema = ThemeMode.values[_prefs!.getInt('ajustes_tema') ?? ThemeMode.light.index];
    barraDerecha = _prefs!.getBool('ajustes_barra_derecha') ?? false;
    tamanoLetra = _prefs!.getInt('ajustes_tamano_letra') ?? 0;
    fuente = _prefs!.getInt('ajustes_fuente') ?? 0;
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

  void ponerBarraDerecha(bool v) {
    barraDerecha = v;
    _prefs?.setBool('ajustes_barra_derecha', v);
    notifyListeners();
  }

  void ponerTamanoLetra(int i) {
    tamanoLetra = i;
    _prefs?.setInt('ajustes_tamano_letra', i);
    notifyListeners();
  }

  void ponerFuente(int i) {
    fuente = i;
    _prefs?.setInt('ajustes_fuente', i);
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
    cambioBarra.value++;
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
