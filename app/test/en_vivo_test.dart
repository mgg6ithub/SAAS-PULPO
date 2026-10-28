import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/en_vivo.dart';

void main() {
  test('una ráfaga de cambios avisa una sola vez con todas las tablas', () {
    fakeAsync((t) {
      final avisos = <Set<String>>[];
      final v = EnVivo('e1', avisos.add);
      v
        ..cambio('trabajos')
        ..cambio('trabajo_historial');
      t.elapse(const Duration(milliseconds: 500));
      v.cambio('trabajos');
      t.elapse(const Duration(milliseconds: 500));
      expect(avisos, isEmpty, reason: 'sigue llegando: aún no avisa');
      t.elapse(const Duration(milliseconds: 400));
      expect(avisos, [
        {'trabajos', 'trabajo_historial'},
      ]);
      v.cambio('clientes');
      t.elapse(const Duration(seconds: 1));
      expect(avisos.last, {'clientes'});
    });
  });

  test('choque: lo cambiado aquí que otra persona cambió después de leerlo', () {
    const visto = {'trabajos|a': '2026-10-28T10:00:00Z', 'trabajos|b': '2026-10-28T10:00:00Z'};
    const base = {'trabajos|a': '2026-10-28T10:05:00Z', 'trabajos|b': '2026-10-28T10:00:00Z'};
    expect(choques(visto, base, ['trabajos|a', 'trabajos|b', 'trabajos|nuevo']), {'trabajos|a'});
  });
}
