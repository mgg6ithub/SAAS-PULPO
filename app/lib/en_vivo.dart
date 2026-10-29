import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tablas de la empresa que se escuchan en vivo (publicadas en `supabase_realtime`).
const tablasEnVivo = [
  'clientes',
  'trabajadores',
  'etiquetas',
  'tipos_trabajo',
  'competencias',
  'equipos',
  'vencimientos',
  'trabajos',
  'trabajo_trabajadores',
  'trabajo_historial',
  'automatizaciones',
  'trabajo_precios',
  'informes',
  'documentos',
];

/// Escucha en Supabase Realtime los cambios de la empresa y avisa una sola vez por ráfaga (tras [espera]
/// sin cambios), para recargar sin hacerlo por cada fila. Cada cuenta solo recibe lo que su RLS le deja ver.
class EnVivo {
  EnVivo(this.empresaId, this.alCambiar, {this.espera = const Duration(milliseconds: 800)});

  final String empresaId;

  /// Qué tablas han cambiado en la última ráfaga.
  final void Function(Set<String> tablas) alCambiar;
  final Duration espera;

  RealtimeChannel? _canal;
  Timer? _timer;
  final _tablas = <String>{};

  void empezar() {
    if (_canal != null) return;
    final c = Supabase.instance.client.channel('empresa:$empresaId');
    for (final t in tablasEnVivo) {
      c.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: t,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'empresa_id', value: empresaId),
        callback: (_) => cambio(t),
      );
      c.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: t,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'empresa_id', value: empresaId),
        callback: (_) => cambio(t),
      );
      // Los borrados no se pueden filtrar (solo traen la clave): llegan todos y se recarga igual.
      c.onPostgresChanges(event: PostgresChangeEvent.delete, schema: 'public', table: t, callback: (_) => cambio(t));
    }
    _canal = c..subscribe((estado, [error]) {
      if (error != null) debugPrint('Pulpo: en vivo $estado: $error');
    });
  }

  /// Llega un cambio de [tabla]: se espera a que pare la ráfaga y se avisa una vez con todas las tablas.
  @visibleForTesting
  void cambio(String tabla) {
    _tablas.add(tabla);
    _timer?.cancel();
    _timer = Timer(espera, () {
      final t = {..._tablas};
      _tablas.clear();
      alCambiar(t);
    });
  }

  Future<void> parar() async {
    _timer?.cancel();
    _tablas.clear();
    final c = _canal;
    _canal = null;
    if (c != null) await Supabase.instance.client.removeChannel(c);
  }
}

/// Filas que se han cambiado aquí (sin subir todavía) y que otra persona también cambió: las claves
/// `tabla|clave` de [cambiadasAqui] cuya versión en la base ya no es la que se vio al leer.
Set<String> choques(Map<String, String> visto, Map<String, String> enLaBase, Iterable<String> cambiadasAqui) => {
  for (final k in cambiadasAqui)
    if (visto.containsKey(k) && enLaBase[k] != visto[k]) k,
};
