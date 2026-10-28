import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/planificador.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('planifica las 10 tareas de datos 2 en dos rutas que caben en la jornada', () async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemoRutas();
    final plan = planificar(hoy());
    final paradas = plan.rutas.expand((r) => r.paradas).toList();
    expect(paradas.length + plan.sinProgramar.length, 10);
    for (final r in plan.rutas) {
      for (final p in r.paradas) {
        expect(p.fin <= finJornada, isTrue);
        if (p.tarea.ventanaHastaMin != null) expect(p.inicio <= p.tarea.ventanaHastaMin!, isTrue);
      }
    }
    aplicar(plan);
    deshacer();
    expect(store.tareas.firstWhere((t) => t.id == 'd100').inicioMin, 480);
  });

  test('un trabajo fijado conserva su técnico y su hora', () async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemoRutas();
    final dia = hoy();
    final w = store.trabajadores.where((w) => w.activo).last;
    final t = store.tareasDelDia(dia).firstWhere((t) => store.cliente(t.clienteId)?.ubicado == true);
    store.guardarTarea(
      t.copia()
        ..fijado = true
        ..inicioMin = 11 * 60
        ..trabajadorIds = [w.id],
    );
    final plan = planificar(dia);
    final ruta = plan.rutas.firstWhere((r) => r.paradas.any((p) => p.tarea.id == t.id));
    expect(ruta.trabajador.id, w.id);
    expect(ruta.paradas.firstWhere((p) => p.tarea.id == t.id).inicio, 11 * 60);
  });

  test('cada técnico sale de su punto de salida si lo tiene', () async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemoRutas();
    final dia = hoy();
    for (final w in store.trabajadores) {
      store.guardarTrabajador(
        w.copia()
          ..salida = 'Getxo'
          ..salidaLat = 43.35
          ..salidaLng = -3.01,
      );
    }
    final plan = planificar(dia);
    final ruta = plan.rutas.firstWhere((r) => r.paradas.isNotEmpty);
    final primera = ruta.paradas.first;
    expect(salidaDe(ruta.trabajador).latitude, 43.35);
    expect(primera.km, closeTo(kmEntre(salidaDe(ruta.trabajador), primera.punto), .001));
  });

  test('una ruta a mano va en el orden elegido y se puede deshacer', () async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.cargarDemoRutas();
    final dia = hoy();
    final w = store.trabajadores.firstWhere((w) => w.activo);
    final orden = store
        .tareasDelDia(dia)
        .where((t) => store.cliente(t.clienteId)?.ubicado == true && !t.conFranja)
        .take(3)
        .toList();
    final antes = orden.first.copia();
    final plan = rutaManual(dia, w, orden.reversed.toList());
    expect(plan.rutas.single.paradas.map((p) => p.tarea.id), orden.reversed.map((t) => t.id));
    aplicar(plan);
    expect(store.tareas.firstWhere((t) => t.id == orden.last.id).trabajadorIds, [w.id]);
    deshacer();
    expect(store.tareas.firstWhere((t) => t.id == antes.id).trabajadorIds, antes.trabajadorIds);
  });
}
