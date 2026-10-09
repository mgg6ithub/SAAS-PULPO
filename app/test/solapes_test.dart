import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';

void main() {
  final dia = DateTime(2026, 10, 8);
  Tarea t(String id, int ini, int dur) => Tarea(
    id: id,
    clienteId: 'c',
    tipo: 'Ascensor', // margen habitual: 25 min
    proximo: dia,
    inicioMin: ini,
    duracionMin: dur,
    trabajadorIds: id == 'a' ? ['w'] : [],
  );

  setUp(() => store.tareas = [t('a', 12 * 60, 90)]); // 12:00–13:30 (+25 → 13:55)

  test('13:00–14:00 se pisa con 12:00–13:30', () => expect(store.solapes(t('b', 13 * 60, 60), 'w'), hasLength(1)));
  test(
    '13:40 cae dentro del margen de retraso',
    () => expect(store.solapes(t('b', 13 * 60 + 40, 60), 'w'), hasLength(1)),
  );
  test('14:00 ya no choca', () => expect(store.solapes(t('b', 14 * 60, 60), 'w'), isEmpty));
  test('otro trabajador no choca', () => expect(store.solapes(t('b', 13 * 60, 60), 'x'), isEmpty));
  test(
    'sin hora no se puede saber',
    () => expect(store.solapes(Tarea(id: 'b', clienteId: 'c', proximo: dia), 'w'), isEmpty),
  );
}
