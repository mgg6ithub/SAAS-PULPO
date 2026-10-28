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
}
