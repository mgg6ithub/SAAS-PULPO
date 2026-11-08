import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/plan.dart';
import 'package:pulpo/models.dart';

void main() {
  test('prioridad conserva los valores anteriores sin generar correctivos', () {
    for (var i = 0; i < 3; i++) {
      final p = PlanMantenimiento.fromJson({'id': 'p', 'activoId': 'a', 'tipo': i});
      expect(p.prioridad, PrioridadMantenimiento.values[i]);
      expect(p.ot('ot').tipoMantenimiento, TipoMantenimiento.preventivo);
      expect(p.copia().prioridad, p.prioridad);
      expect(p.toJson()['tipo'], 0);
    }
  });
  test('cambiar prioridad se conserva al guardar y copiar', () {
    final p = PlanMantenimiento(id: 'p', activoId: 'a');
    p.prioridad = PrioridadMantenimiento.critica;
    expect(p.copia().prioridad, PrioridadMantenimiento.critica);
    expect(p.ot('ot').tipoMantenimiento, TipoMantenimiento.preventivo);
  });
  test('el color del mantenimiento se conserva sin alterar su tipo', () {
    final plan = PlanMantenimiento(id: 'p', activoId: 'a', color: 0xFF0D9488);
    expect(plan.copia().color, 0xFF0D9488);
    expect(plan.ot('ot').tipoMantenimiento, TipoMantenimiento.preventivo);
    expect(PlanMantenimiento.fromJson({'id': 'p', 'activoId': 'a'}).color, isNull);
  });
}
