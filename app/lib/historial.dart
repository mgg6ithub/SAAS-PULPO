import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué se hizo.
enum Hecho { creado, cambiado, borrado, completado }

/// Una línea del historial: qué se hizo, con qué y cuándo.
class Registro {
  final Hecho hecho;

  /// 'activo', 'componente', 'mantenimiento', 'tecnico', 'orden', 'incidencia' o 'grupo'.
  final String que;
  String nombre;
  final String? id;
  DateTime cuando;

  /// Frase propia (los borrados y cambios que se pueden deshacer ya traen la suya).
  final String? texto;

  /// La acción que permite «Deshacer» (un borrado o un deshacer, con cómo estaba todo). Se guarda con el historial.
  Object? accion;

  /// Cambios: cómo estaba la fila antes (JSON), para devolverla a ese punto con «Deshacer».
  final String? antes;
  bool deshecho;
  Registro(
    this.hecho,
    this.que,
    this.nombre, {
    this.id,
    this.texto,
    this.accion,
    this.antes,
    this.deshecho = false,
    DateTime? cuando,
  }) : cuando = cuando ?? DateTime.now();

  /// Cómo guardar y leer [accion] (la pone la tienda: aquí no se conoce su tipo).
  static Map<String, dynamic>? Function(Object accion)? accionAJson;
  static Object? Function(Map<String, dynamic> j)? accionDeJson;

  static const _cosas = {
    'activo': 'el activo',
    'componente': 'el componente',
    'mantenimiento': 'el mantenimiento',
    'tecnico': 'el técnico',
    'orden': 'la orden',
    'incidencia': 'la incidencia',
    'grupo': 'el grupo',
  };

  static const _verbos = {
    Hecho.creado: 'Has creado',
    Hecho.cambiado: 'Has cambiado',
    Hecho.borrado: 'Has borrado',
    Hecho.completado: 'Has completado',
  };

  String get titulo => texto ?? '${_verbos[hecho]} ${_cosas[que] ?? que}${nombre.isEmpty ? '' : ' «$nombre»'}';

  Map<String, dynamic> toJson() => {
    'hecho': hecho.name,
    'que': que,
    'nombre': nombre,
    if (id != null) 'id': id,
    if (texto != null) 'texto': texto,
    if (deshecho) 'deshecho': true,
    'cuando': cuando.toIso8601String(),
    if (antes != null) 'antes': antes,
    if (accion == null ? null : accionAJson?.call(accion!) case final a?) 'accion': a,
  };

  factory Registro.fromJson(Map<String, dynamic> j) => Registro(
    Hecho.values.asNameMap()[j['hecho']] ?? Hecho.cambiado,
    j['que'] as String? ?? '',
    j['nombre'] as String? ?? '',
    id: j['id'] as String?,
    texto: j['texto'] as String?,
    deshecho: j['deshecho'] == true,
    cuando: DateTime.tryParse(j['cuando'] as String? ?? ''),
    antes: j['antes'] as String?,
    accion: j['accion'] is Map ? accionDeJson?.call(Map<String, dynamic>.from(j['accion'] as Map)) : null,
  );
}

/// Lo que se ha ido haciendo con esta empresa en este dispositivo, lo último primero. Se guarda entre sesiones.
class Historial extends ChangeNotifier {
  static const _maximo = 300;

  /// Lo más antiguo que se guarda: un mes.
  static const dias = 30;
  static bool _viejo(Registro r) => DateTime.now().difference(r.cuando).inDays >= dias;

  /// Los cambios seguidos de lo mismo (una ficha que se guarda sola al escribir) cuentan como uno.
  static const _juntar = Duration(minutes: 10);

  final registros = <Registro>[];

  /// Lo último que se ha creado, para enseñarlo en grande y verlo entrar en la campana.
  final creado = ValueNotifier<Registro?>(null);

  /// Sube cada vez que se guarda un cambio (para el aviso efímero de «Cambios guardados»).
  final guardados = ValueNotifier<int>(0);
  String? _clave;
  Future<void> _leido = Future.value();

  /// Pone el historial de [empresa] (si no es el que ya está).
  void usar(String empresa) {
    final clave = 'historial_$empresa';
    if (clave == _clave) return;
    _clave = clave;
    registros.clear();
    _leido = _leer(clave);
  }

  Future<void> _leer(String clave) async {
    try {
      final texto = (await SharedPreferences.getInstance()).getString(clave);
      if (texto == null || clave != _clave) return;
      // Detrás de lo que se haya apuntado mientras se leía.
      registros.addAll([
        for (final x in jsonDecode(texto) as List) Registro.fromJson(Map<String, dynamic>.from(x as Map)),
      ]..removeWhere(_viejo));
      notifyListeners();
    } catch (e) {
      debugPrint('Pultec: no se pudo leer el historial: $e');
    }
  }

  void apuntar(Registro r) {
    if (r.hecho == Hecho.cambiado) guardados.value++;
    if (r.hecho == Hecho.cambiado && r.id != null) {
      final antes = registros
          .where((x) => x.id == r.id && x.que == r.que && r.cuando.difference(x.cuando) < _juntar)
          .firstOrNull;
      // Recién creado o recién cambiado: no se repite la línea, solo se pone al día.
      if (antes != null && (antes.hecho == Hecho.creado || antes.hecho == Hecho.cambiado) && antes.texto == null) {
        antes
          ..nombre = r.nombre
          ..cuando = r.cuando;
        registros
          ..remove(antes)
          ..insert(0, antes);
        return _guardar();
      }
    }
    registros.insert(0, r);
    if (r.hecho == Hecho.creado) creado.value = r;
    registros.removeWhere(_viejo);
    if (registros.length > _maximo) registros.removeRange(_maximo, registros.length);
    _guardar();
  }

  /// Se ha deshecho la línea [r] (una creación o un cambio).
  void marcarDeshecho(Registro r) {
    r.deshecho = true;
    _guardar();
  }

  /// Se ha deshecho [accion].
  void deshecha(Object accion) {
    for (final r in registros.where((r) => r.accion == accion)) {
      r.deshecho = true;
    }
    _guardar();
  }

  void _guardar() {
    notifyListeners();
    final clave = _clave;
    if (clave == null) return;
    _leido.then((_) async {
      if (clave != _clave) return;
      try {
        await (await SharedPreferences.getInstance()).setString(clave, jsonEncode([for (final r in registros) r.toJson()]));
      } catch (e) {
        debugPrint('Pultec: no se pudo guardar el historial: $e');
      }
    });
  }
}

final historial = Historial();
