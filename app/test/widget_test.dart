import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';

void main() {
  test('el trabajador apto es el que tiene todas las competencias', () {
    final s = Store();
    final t = Tarea(id: 't', clienteId: 'c', competencias: ['Ascensores', 'Electricidad']);
    final si = Trabajador(id: 'a', competencias: ['Ascensores', 'Electricidad', 'PRL']);
    final no = Trabajador(id: 'b', competencias: ['Ascensores']);
    s.trabajadores = [no, si];
    expect(s.esApto(si, t), isTrue);
    expect(s.faltan(no, t), ['Electricidad']);
    expect(s.mejorPara(t)?.id, 'a');
  });

  test('marcar como hecha calcula el siguiente mantenimiento', () {
    final s = Store();
    final t = Tarea(id: 't', clienteId: 'c', periodicidad: Periodicidad.mensual);
    s.tareas = [t];
    s.marcarHecha(t);
    expect(diasHasta(t.ultimo!), 0);
    expect(diasHasta(t.proximo!), 30);
  });
}
