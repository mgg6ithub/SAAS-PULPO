import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
  });

  test('quitar los datos de ejemplo devuelve exactamente los datos de antes', () async {
    store.guardarCliente(Cliente(id: 'mio', nombre: 'Mi cliente real'));
    store.cargarDemo();
    expect(store.demo, isTrue);
    expect(store.clientes.length, greaterThan(1));

    await store.quitarDemo();
    expect(store.demo, isFalse);
    expect(store.clientes.map((c) => c.nombre), ['Mi cliente real']);
  });

  test('con la cuenta vacía, quitar los datos de ejemplo la deja limpia', () async {
    store.cargarDemo();
    await store.quitarDemo();
    expect(store.clientes, isEmpty);
    expect(store.trabajadores, isEmpty);
    expect(store.tareas.every((t) => t.esPlantilla), isTrue);
  });

  test('el estado de ejemplo sobrevive a recargar la página', () async {
    store.cargarDemo();
    await store.cargar();
    expect(store.demo, isTrue);
  });

  test('datos de ejemplo antiguos (sin marca) se reconocen y se quitan conservando los reales', () async {
    store.cargarDemo();
    store.demo = false; // como si se hubieran cargado antes de existir la marca
    store.guardarCliente(Cliente(id: '1791535607099000', nombre: 'Real'));
    SharedPreferences.setMockInitialValues({
      'pulpo_v2': (await SharedPreferences.getInstance()).getString('pulpo_v2')!,
    });
    await store.cargar();
    expect(store.demo, isTrue);
    await store.quitarDemo();
    expect(store.clientes.map((c) => c.nombre), ['Real']);
    expect(store.trabajadores, isEmpty);
  });
}
