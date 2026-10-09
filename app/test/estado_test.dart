import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';

void main() {
  test('una tarea de la semana que viene nunca sale completada', () {
    final semanaQueViene = masDias(hoy(), 7);
    final t = Tarea(id: 'a', clienteId: 'c', ultimo: semanaQueViene, proximo: semanaQueViene);
    expect(t.hechaEl(semanaQueViene), isFalse);
  });

  test('hecha hoy sí sale completada hoy', () {
    final t = Tarea(id: 'a', clienteId: 'c', ultimo: hoy());
    expect(t.hechaEl(hoy()), isTrue);
  });
}
