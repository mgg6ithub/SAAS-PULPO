import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/industrial/activo.dart';

void main() {
  test('5000 horas a 7 horas diarias estiman 715 días sin cambiar el contador', () {
    final a = Activo(
      id: 'camion',
      frecuencia: FrecuenciaActivo.horas,
      cadaHoras: 5000,
      horasUso: 7,
      fechaLectura: DateTime(2026, 10, 30),
    );
    expect(a.horasRestantes, 5000);
    expect(a.proximoMantenimiento, DateTime(2026, 10, 30 + 715));
    expect(a.horas, 0);
    expect(a.proximoMantenimiento, a.copia().proximoMantenimiento);
  });
  test('descuenta las horas desde el último mantenimiento y usa la fecha real de lectura', () {
    final a = Activo(
      id: 'motor',
      frecuencia: FrecuenciaActivo.horas,
      cadaHoras: 5000,
      horas: 1300,
      horasUltimoMantenimiento: 300,
      horasUso: 7,
      fechaLectura: DateTime(2026, 1, 1),
    );
    expect(a.horasDesdeMantenimiento, 1000);
    expect(a.horasRestantes, 4000);
    expect(a.proximoMantenimiento, DateTime(2026, 1, 1 + 572));
  });
  test('35 horas semanales estiman 1000 días para 5000 horas', () {
    final a = Activo(
      id: 'bomba',
      frecuencia: FrecuenciaActivo.horas,
      cadaHoras: 5000,
      horasUso: 35,
      usoSemanal: true,
      fechaLectura: DateTime(2026, 1, 1),
    );
    expect(a.proximoMantenimiento, DateTime(2026, 1, 1001));
  });
  test('meses naturales respetan el fin de mes y los años bisiestos', () {
    final a = Activo(
      id: 'prensa',
      frecuencia: FrecuenciaActivo.meses,
      cadaMeses: 1,
      ultimoMantenimiento: DateTime(2027, 1, 31),
    );
    expect(a.proximoMantenimiento, DateTime(2027, 2, 28));
    a.ultimoMantenimiento = DateTime(2028, 1, 31);
    expect(a.proximoMantenimiento, DateTime(2028, 2, 29));
    a.cadaMeses = 3;
    expect(a.proximoMantenimiento, DateTime(2028, 4, 30));
  });
  test('cada componente mantiene su intervalo al guardar y recargar', () {
    final padre = Activo(
      id: 'camion',
      frecuencia: FrecuenciaActivo.meses,
      cadaMeses: 12,
      ultimoMantenimiento: DateTime(2026, 1, 1),
    );
    final hijo = Activo(
      id: 'motor',
      padreId: padre.id,
      frecuencia: FrecuenciaActivo.horas,
      cadaHoras: 5000,
      horas: 200,
      horasUltimoMantenimiento: 100,
      horasUso: 7,
      fechaLectura: DateTime(2026, 10, 30),
    );
    final recargado = Activo.fromJson(hijo.toJson());
    expect(recargado.toJson(), hijo.toJson());
    expect(recargado.frecuencia, FrecuenciaActivo.horas);
    expect(padre.frecuencia, FrecuenciaActivo.meses);
    expect(padre.proximoMantenimiento, DateTime(2027, 1, 1));
  });
  test('una fecha concreta y la falta de ritmo no inventan una lectura', () {
    final a = Activo(id: 'a', frecuencia: FrecuenciaActivo.fecha, fechaMantenimiento: DateTime(2027, 3, 1));
    expect(a.proximoMantenimiento, DateTime(2027, 3, 1));
    a
      ..frecuencia = FrecuenciaActivo.horas
      ..cadaHoras = 5000;
    expect(a.proximoMantenimiento, isNull);
    a.horas = 5100;
    expect(a.horasRestantes, -100);
    expect(a.proximoMantenimiento, a.fechaLectura);
  });
}
