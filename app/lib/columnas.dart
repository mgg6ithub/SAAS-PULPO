import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo ha dejado cada cuenta las columnas de cada tabla: en qué orden y cuáles ha quitado o añadido. Se guarda en
/// la cuenta (`perfiles.columnas`), así al volver a entrar —en este equipo o en otro— las tablas salen igual; en el
/// navegador queda una copia por si no hay conexión.
///
/// Avisa a quien escucha cuando cambia qué columnas se ven; mover una no avisa (la tabla ya se pinta sola).
class ColumnasTablas extends ChangeNotifier {
  final _orden = <String, List<String>>{};

  /// Solo las que el usuario ha marcado o desmarcado: las demás siguen como vienen de serie (así una columna nueva
  /// de la app aparece sola).
  final _elegidas = <String, Map<String, bool>>{};

  String? _usuario;
  Future<void> Function(Map<String, dynamic>)? _subir;

  /// Cuenta los cambios, para saber si lo que se acaba de subir sigue siendo lo último.
  int _cambios = 0;
  Future<void> _cola = Future.value();

  /// Termina cuando se ha guardado lo último (antes de cerrar la sesión).
  Future<void> get guardado => _cola;

  /// Títulos de las columnas de [tabla] en el orden del usuario (vacío = el de serie). La tabla escribe en ella.
  List<String> orden(String tabla) => _orden.putIfAbsent(tabla, () => []);

  bool ve(String tabla, String columna, {bool porDefecto = true}) => _elegidas[tabla]?[columna] ?? porDefecto;

  void poner(String tabla, String columna, bool visible) {
    (_elegidas[tabla] ??= {})[columna] = visible;
    guardar();
    notifyListeners();
  }

  /// Las columnas de [tabla], como vienen de serie y en su orden.
  void restablecer(String tabla) {
    orden(tabla).clear();
    _elegidas[tabla]?.clear();
    guardar();
    notifyListeners();
  }

  static String _clave(String usuario) => 'pultec_columnas_$usuario';

  /// Carga las de [usuario] al entrar. [leer] y [subir] son las de su cuenta (sin ellas, solo el navegador). Si no
  /// responde, vale la copia del navegador: nunca impide entrar.
  Future<void> abrir(
    String usuario, {
    Future<Map<String, dynamic>?> Function()? leer,
    Future<void> Function(Map<String, dynamic>)? subir,
  }) async {
    await _cola;
    _vaciar();
    _usuario = usuario;
    _subir = subir;
    var pendiente = false;
    Map<String, dynamic> local = {};
    try {
      final texto = (await SharedPreferences.getInstance()).getString(_clave(usuario));
      if (texto != null) {
        final j = jsonDecode(texto) as Map<String, dynamic>;
        local = Map<String, dynamic>.from(j['tablas'] as Map);
        pendiente = j['pendiente'] == true;
      }
    } catch (_) {
      // Copia ilegible: como si no hubiera.
    }
    Map<String, dynamic>? cuenta;
    try {
      cuenta = await leer?.call().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Sin conexión (o la base aún sin la columna).
    }
    // Manda la cuenta, salvo que aquí quede algo sin subir o ella no tenga nada guardado.
    final subirLocal = local.isNotEmpty && (pendiente || (cuenta != null && cuenta.isEmpty));
    _poner(subirLocal || cuenta == null || cuenta.isEmpty ? local : cuenta);
    if (subirLocal) {
      guardar();
    } else if (cuenta != null && cuenta.isNotEmpty) {
      await _copiar(usuario, cuenta, pendiente: false);
    }
    notifyListeners();
  }

  /// Al salir de la cuenta: las tablas vuelven a las de serie (la siguiente cuenta trae las suyas).
  void cerrar() {
    if (_usuario == null && _orden.values.every((o) => o.isEmpty) && _elegidas.isEmpty) return;
    _usuario = null;
    _subir = null;
    _vaciar();
    notifyListeners();
  }

  void _vaciar() {
    // Las listas se vacían sin cambiarlas por otras: puede haber tablas usándolas.
    for (final o in _orden.values) {
      o.clear();
    }
    _elegidas.clear();
  }

  void _poner(Map<String, dynamic> tablas) {
    for (final e in tablas.entries) {
      final t = e.value;
      if (t is! Map) continue;
      if (t['orden'] case final List o) orden(e.key).addAll(o.whereType<String>());
      if (t['ver'] case final Map v) {
        _elegidas[e.key] = {
          for (final x in v.entries)
            if (x.value is bool) '${x.key}': x.value as bool,
        };
      }
    }
  }

  /// Todo lo guardado. Una tabla restablecida sigue apareciendo (vacía): así se distingue de «nunca se ha guardado».
  Map<String, dynamic> aJson() => {
    for (final t in {..._orden.keys, ..._elegidas.keys})
      t: {'orden': [...?_orden[t]], 'ver': {...?_elegidas[t]}},
  };

  Future<void> _copiar(String usuario, Map<String, dynamic> tablas, {required bool pendiente}) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _clave(usuario),
        jsonEncode({'tablas': tablas, 'pendiente': pendiente}),
      );
    } catch (_) {
      // Sin sitio en el navegador: queda la de la cuenta.
    }
  }

  /// Guarda lo que hay ahora, en el navegador y en la cuenta. Sin sesión no hace nada.
  void guardar() {
    final usuario = _usuario, subir = _subir;
    if (usuario == null) return;
    final tablas = aJson();
    final cambio = ++_cambios;
    _cola = _cola.then((_) async {
      await _copiar(usuario, tablas, pendiente: subir != null);
      if (subir == null || cambio != _cambios) return; // hay otro cambio detrás, que ya lo sube todo
      try {
        await subir(tablas).timeout(const Duration(seconds: 10));
        await _copiar(usuario, tablas, pendiente: false);
      } catch (_) {
        // Queda pendiente: se sube con el siguiente cambio o al volver a entrar.
      }
    });
  }
}

final columnasTablas = ColumnasTablas();
