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
}
