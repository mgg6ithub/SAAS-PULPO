import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';
import 'package:pulpo/industrial/plan.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Borrar y deshacer deja todo como estaba, y lo cambiado después a mano no se pisa.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemo();
  });

  test('deshacer un activo vuelve a poner sus componentes, mantenimientos y el enlace de sus OT', () {
    store.guardarActivo(Activo(id: 'a1', nombre: 'Planta'));
    store.guardarActivo(Activo(id: 'a2', nombre: 'Bomba', padreId: 'a1'));
    store.guardarPlan(PlanMantenimiento(id: 'p1', activoId: 'a2', nombre: 'Engrase'));
    final t = store.tareas.firstWhere((t) => !t.esPlantilla)..activoId = 'a2';
    final n = store.tareas.length;

    store.deshacible('Has borrado Planta', () => store.borrarActivo('a1'));
    expect(store.activo('a1'), isNull);
    expect(store.activo('a2'), isNull);
    expect(store.planes.any((p) => p.id == 'p1'), isFalse);
    expect(store.tarea(t.id)!.activoId, isNull);
    expect(store.ultimaAccion.value?.texto, 'Has borrado Planta');

    store.deshacer(store.acciones.first);
    expect(store.activo('a2')?.padreId, 'a1');
    expect(store.planes.firstWhere((p) => p.id == 'p1').activa, isTrue);
    expect(store.tarea(t.id)!.activoId, 'a2');
    expect(store.tareas.length, n);
    expect(store.acciones.first.deshecha, isTrue);
    expect(store.ultimaAccion.value, isNull);
  });

  test('deshacer un trabajador no pisa una OT cambiada después', () {
    final w = store.trabajadores.first;
    final ts = store.tareas.where((t) => t.trabajadorIds.contains(w.id)).toList();
    expect(ts.length, greaterThan(1));
    store.deshacible('Has borrado a ${w.nombre}', () => store.borrarTrabajador(w.id));
    ts.first.nombre = 'Cambiada a mano';
    store.deshacer(store.acciones.first);
    expect(store.trabajador(w.id), isNotNull);
    expect(ts.first.trabajadorIds.contains(w.id), isFalse);
    expect(store.tarea(ts.last.id)!.trabajadorIds.contains(w.id), isTrue);
  });
}
