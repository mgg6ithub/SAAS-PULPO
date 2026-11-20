// Flujo completo de Pultec contra el Supabase REAL (no corre solo: `python3 tool/probar_flujo_pultec.py`, que crea
// las cuentas de prueba y lo borra todo al acabar):
//   administrador → «Activo test» con dos mantenimientos realistas → la base crea sus OT y las asigna →
//   invita al técnico → el técnico entra, ve sus OT, cierra una con su parte y apunta el contador →
//   el administrador la ve hecha, el mantenimiento reiniciado y la siguiente OT creada; el técnico, en su histórico.
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:pultec/industrial/activo.dart';
import 'package:pultec/industrial/estadisticas.dart' show resumenActivo;
import 'package:pultec/industrial/incidencia.dart';
import 'package:pultec/industrial/simulacion_dominion.dart';
import 'package:pultec/industrial/simulacion_historial.dart';
import 'package:pultec/industrial/plan.dart';
import 'package:pultec/informes.dart';
import 'package:pultec/models.dart';
import 'package:pultec/nube.dart';
import 'package:pultec/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _env = Platform.environment;
const _clave = 'prueba-123456';

/// Entra con la cuenta y carga su empresa en el `store` global (como la app).
Future<Nube> _entrar(String correo, {String? invitacion}) async {
  SharedPreferences.setMockInitialValues({'pulpo_invitacion': ?invitacion});
  await Supabase.instance.client.auth.signInWithPassword(email: correo, password: _clave);
  final n = await Nube.abrir();
  await store.cargarDesdeNube(n);
  return n;
}

Future<void> _salir(Nube n) async {
  await n.guardado;
  await Nube.cerrarSesion();
}

/// OT abiertas (pendientes o en curso) de un mantenimiento.
List<Tarea> _abiertas(String planId) => store.tareas
    .where((t) => t.planId == planId && t.activa && t.estado != EstadoTrabajo.realizado)
    .toList();

void main() {
  testWidgets('Pultec de punta a punta: activo, mantenimientos, OT, técnico y cierre', (tester) async {
    await tester.runAsync(() async {
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublicable,
        authOptions: FlutterAuthClientOptions(localStorage: const EmptyLocalStorage(), detectSessionInUri: false),
      );
      final db = Supabase.instance.client;
      final h = hoy();

      // ── 1. Administrador: técnico, «Activo test» y dos mantenimientos ──
      var n = await _entrar(_env['SB_ADMIN']!);
      expect(n.esTrabajador, isFalse);
      final tecnico = Trabajador(
        id: store.nuevoId(),
        nombre: 'Técnico',
        apellidos: 'Test',
        email: _env['SB_TECNICO']!,
        competencias: ['Mecánica'],
      );
      store.guardarTrabajador(tecnico);
      // Compresor con 2.950 h y 8 h de uso al día: le faltan 50 h para la revisión de 3.000 h (7 días).
      final activo = Activo(
        id: store.nuevoId(),
        nombre: 'Activo test',
        tag: 'AT-01',
        icono: 'compresor',
        horas: 2950,
        horasUso: 8,
        fechaLectura: h,
      );
      store.guardarActivo(activo);
      final revision = PlanMantenimiento(
        id: store.nuevoId(),
        activoId: activo.id,
        nombre: 'Revisión 3.000 h',
        cadaHoras: 3000,
        ultimoHoras: 0,
        duracionMin: 120,
        categoria: 'Mecánica',
        trabajadorId: tecnico.id,
      );
      // Engrase cada 30 días, el último hace 30: toca hoy.
      final engrase = PlanMantenimiento(
        id: store.nuevoId(),
        activoId: activo.id,
        nombre: 'Engrase mensual',
        cadaDias: 30,
        ultimo: masDias(h, -30),
        duracionMin: 30,
        categoria: 'Mecánica',
        trabajadorId: tecnico.id,
      );
      store.guardarPlan(revision);
      store.guardarPlan(engrase);
      await n.guardado;
      expect(Nube.error.value, isNull, reason: 'se guarda sin errores');

      // La base crea una OT por mantenimiento, con su fecha estimada y el técnico del mantenimiento.
      await store.cargarDesdeNube(n);
      final otRevision = _abiertas(revision.id);
      final otEngrase = _abiertas(engrase.id);
      expect(otRevision, hasLength(1), reason: 'OT automática de la revisión');
      expect(otEngrase, hasLength(1), reason: 'OT automática del engrase');
      expect(otRevision.single.proximo, masDias(h, 7), reason: '50 h a 8 h/día → dentro de 7 días');
      expect(otEngrase.single.proximo, h, reason: 'último hace 30 días → hoy');
      for (final t in [...otRevision, ...otEngrase]) {
        expect(t.trabajadorIds, [tecnico.id], reason: 'asignada al técnico del mantenimiento');
        expect(t.activoId, activo.id);
        expect(t.tipoMantenimiento, TipoMantenimiento.preventivo);
      }

      final codigo = await n.crearInvitacion(rol: 'trabajador', trabajadorId: tecnico.id);
      await _salir(n);

      // ── 2. Técnico: entra con la invitación, ve sus OT y cierra la de hoy ──
      n = await _entrar(_env['SB_TECNICO']!, invitacion: codigo);
      expect(n.esTrabajador, isTrue, reason: 'entra como técnico');
      final mias = store.tareas.where((t) => t.trabajadorIds.contains(tecnico.id) && !t.esPlantilla).toList();
      expect(mias.map((t) => t.nombre).toSet(), {'Revisión 3.000 h', 'Engrase mensual'});
      final ot = store.tarea(otEngrase.single.id)!;
      // Lo mismo que hace el parte (FormularioInforme) al cerrar la OT.
      expect(
        await informes.crear(
          Informe(trabajoId: ot.id, trabajadorId: tecnico.id, resultado: 0, notas: 'Engrasados los rodamientos'),
        ),
        isTrue,
      );
      ot
        ..resultado = 0
        ..resultadoResuelto = false;
      final raiz = store.activo(activo.id)!
        ..horas = 2958
        ..fechaLectura = h;
      store.guardarActivo(raiz);
      await n.apuntarContador(activo.id, 2958);
      store.marcarHecha(ot);
      await n.guardado;
      expect(Nube.error.value, isNull, reason: 'el técnico guarda el cierre sin errores');
      final historial = await informes.delTecnico(tecnico.id);
      expect(historial.map((i) => i.notas), contains('Engrasados los rodamientos'), reason: 'su histórico');
      await _salir(n);

      // ── 3. Administrador: OT hecha, mantenimiento reiniciado y la siguiente OT ──
      n = await _entrar(_env['SB_ADMIN']!);
      final cerrada = store.tarea(otEngrase.single.id)!;
      expect(cerrada.estado, EstadoTrabajo.realizado, reason: 'el admin la ve hecha');
      final plan = store.planes.firstWhere((p) => p.id == engrase.id);
      expect(plan.ultimo, h, reason: 'el engrase se reinicia hoy');
      expect(plan.proximo, masDias(h, 30), reason: 'el próximo engrase, dentro de 30 días');
      final siguiente = _abiertas(engrase.id);
      expect(siguiente, hasLength(1), reason: 'la base crea la siguiente OT del engrase');
      expect(siguiente.single.proximo, masDias(h, 30));
      expect(siguiente.single.trabajadorIds, [tecnico.id]);
      expect(_abiertas(revision.id).single.id, otRevision.single.id, reason: 'la revisión no se toca');
      final partes = await db.from('informes').select('resultado, notas').eq('trabajo_id', cerrada.id);
      expect(partes, [
        {'resultado': 0, 'notas': 'Engrasados los rodamientos'},
      ], reason: 'el admin ve el parte');
      // La lectura del contador que apuntó el técnico llega al activo.
      expect(store.activo(activo.id)!.horas, 2958, reason: 'contador apuntado por el técnico');
      await _salir(n);

      // ── 4. Técnico: un parte con incidencia y una incidencia comunicada ──
      n = await _entrar(_env['SB_TECNICO']!);
      expect(
        await informes.crear(
          Informe(trabajoId: otRevision.single.id, trabajadorId: tecnico.id, resultado: 1, notas: 'Ruido en el rodamiento'),
        ),
        isTrue,
      );
      final aviso = Incidencia(id: store.nuevoId(), activoId: activo.id, tecnicoId: tecnico.id, descripcion: 'Fuga de aceite');
      await n.crearIncidencia(aviso, '', const []);
      await store.cargarDesdeNube(n);
      // Abierta: quien la comunicó la corrige entera.
      final suyaAbierta = store.incidencias.firstWhere((i) => i.id == aviso.id);
      await n.editarIncidencia(suyaAbierta.copia()..descripcion = 'Fuga de aceite en la junta', const [], const []);
      await store.cargarDesdeNube(n);
      expect(store.incidencias.firstWhere((i) => i.id == aviso.id).descripcion, 'Fuga de aceite en la junta');
      expect(store.incidencias.firstWhere((i) => i.id == aviso.id).editadaEl, isNotNull, reason: 'avisa de la corrección');
      await _salir(n);

      // ── 5. Administrador: las dos abiertas; OT para la fuga vinculada a la revisión; desestima la otra ──
      n = await _entrar(_env['SB_ADMIN']!);
      final delParte = store.incidencias.firstWhere((i) => i.origenTrabajoId == otRevision.single.id);
      expect(delParte.descripcion, contains('Ruido en el rodamiento'), reason: 'el parte deja su incidencia');
      expect(store.estadoIncidencia(delParte), EstadoIncidencia.abierta);
      expect(store.estadoIncidencia(store.incidencias.firstWhere((i) => i.id == aviso.id)), EstadoIncidencia.abierta);
      final arreglo = Tarea(
        id: store.nuevoId(),
        nombre: 'Reparar Activo test',
        descripcion: 'Fuga de aceite',
        activoId: activo.id,
        plantilla: false,
        tipoMantenimiento: TipoMantenimiento.correctivoNoCritico,
        proximo: h,
        periodicidad: Periodicidad.unica,
        criticidad: Criticidad.rutinaria,
        repuestos: 'Junta 40 mm',
        procedimiento: 'Cambiar la junta',
        trabajadorIds: [tecnico.id],
      );
      store.guardarTarea(arreglo);
      store.guardarIncidencia(store.incidencias.firstWhere((i) => i.id == aviso.id).copia()
        ..trabajoId = arreglo.id
        ..planId = revision.id
        ..estado = EstadoIncidencia.conOt);
      store.guardarIncidencia(delParte.copia()..estado = EstadoIncidencia.desestimada);
      await n.guardado;
      expect(Nube.error.value, isNull, reason: 'OT de la incidencia guardada');
      await _salir(n);

      // ── 6. Técnico: ve la OT con su incidencia y la cierra ──
      n = await _entrar(_env['SB_TECNICO']!);
      final suya = store.tarea(arreglo.id)!;
      expect(suya.repuestos, 'Junta 40 mm');
      expect(store.incidenciaDeOt(suya.id)?.descripcion, 'Fuga de aceite en la junta', reason: 've la incidencia original');
      // Con OT ya no se puede cambiar.
      await expectLater(
        n.editarIncidencia(store.incidenciaDeOt(suya.id)!.copia()..descripcion = 'Otra cosa', const [], const []),
        throwsA(anything),
      );
      store.marcarHecha(suya);
      await n.guardado;
      expect(Nube.error.value, isNull, reason: 'el técnico cierra la OT de la incidencia');
      // Los activos en los que trabaja van con su cuenta, no con el dispositivo.
      await n.guardarActivosElegidos(tecnico.id, [activo.id]);
      await _salir(n);
      n = await _entrar(_env['SB_TECNICO']!);
      expect(store.trabajador(tecnico.id)!.activosElegidos, [activo.id], reason: 'otro dispositivo ve lo mismo');
      await _salir(n);

      // ── 7. Administrador: la incidencia, completada sola; la revisión, reiniciada; la otra, desestimada ──
      n = await _entrar(_env['SB_ADMIN']!);
      final hecha = store.incidencias.firstWhere((i) => i.id == aviso.id);
      expect(hecha.estado, EstadoIncidencia.completada, reason: 'la base la completa al cerrar su OT');
      expect(hecha.cerradaEl, isNotNull);
      expect(store.planes.firstWhere((p) => p.id == revision.id).ultimo, h, reason: 'la revisión vuelve a contar');
      expect(store.incidencias.firstWhere((i) => i.id == delParte.id).estado, EstadoIncidencia.desestimada);

      // ── 8. Producción simulada: tres meses de trabajo sobre la planta de Dominion ──
      crearSimulacionDominion();
      final resumen = await simularHistorial(meses: 3);
      debugPrint('Simulación: $resumen');
      final estados = {for (final x in store.incidencias) store.estadoIncidencia(x)};
      expect(estados, containsAll(EstadoIncidencia.values), reason: 'incidencias en los cuatro estados');
      final conMedicion = store.planes.where((p) => p.conMedicion).toList();
      expect(conMedicion, isNotEmpty, reason: 'mantenimientos con medición');
      final medidas = await informes.mediciones(conMedicion.first.id);
      expect(medidas, isNotEmpty, reason: 'mediciones subidas con sus partes');
      expect(medidas.first.$1.isBefore(masDias(h, -7)), isTrue, reason: 'con la fecha del parte, no la de hoy');
      final planta = store.hijosDe(null).firstWhere((a) => a.tag == 'PST-02');
      final r = resumenActivo(planta, masDias(h, -91));
      expect(r.hechas, greaterThan(10), reason: 'la planta tiene historial de OT hechas');
      expect(r.planes.every((x) => x.$2 > 0 || x.$1.cadaDias == null || x.$1.cadaDias! > 91), isTrue,
        reason: 'cada mantenimiento frecuente cuenta sus hechos');
      // Una OT de un mantenimiento con medición para el técnico, que medirá fuera de límites.
      final medido = conMedicion.firstWhere((p) => p.medicionMax != null);
      final otMedida = medido.ot(store.nuevoId())
        ..proximo = h
        ..trabajadorIds = [tecnico.id];
      store.guardarTarea(otMedida);
      await n.guardado;
      expect(Nube.error.value, isNull, reason: 'la simulación se guarda sin errores');
      await _salir(n);

      // ── 9. Técnico: hace la OT y mide por encima del máximo ──
      n = await _entrar(_env['SB_TECNICO']!);
      final paraMedir = store.tarea(otMedida.id)!;
      expect(
        await informes.crear(Informe(trabajoId: paraMedir.id, trabajadorId: tecnico.id, resultado: 0,
          notas: 'Medido', valor: medido.medicionMax! + 5)),
        isTrue,
      );
      store.marcarHecha(paraMedir);
      await n.guardado;
      expect(Nube.error.value, isNull);
      await _salir(n);

      // ── 10. Administrador: la medición fuera de límites ha abierto una incidencia ──
      n = await _entrar(_env['SB_ADMIN']!);
      final fuera = store.incidencias.where((x) => x.origenTrabajoId == otMedida.id).toList();
      expect(fuera, hasLength(1), reason: 'incidencia por medición fuera de límites');
      expect(fuera.single.descripcion, contains('fuera de límites'));
      expect(store.estadoIncidencia(fuera.single), EstadoIncidencia.abierta);
      expect(store.tarea(otMedida.id)!.estado, EstadoTrabajo.realizado);
      await _salir(n);
    });
  },
    timeout: const Timeout(Duration(minutes: 10)),
    // Solo con las cuentas que crea tool/probar_flujo_pultec.py: en la suite normal no hay Supabase.
    skip: _env['SB_ADMIN'] == null,
  );
}
