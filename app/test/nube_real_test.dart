// Prueba contra el Supabase REAL: rellena cada tabla y cada columna, recarga desde otra instancia y compara.
// No corre sola: se lanza con `python3 tool/probar_nube.py`, que crea dos cuentas de prueba y las borra al acabar.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/nube.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _env = Platform.environment;

String _j(Object o) => jsonEncode(o);

/// Tarea con sus listas ordenadas, para comparar sin depender del orden de la base.
String _tarea(Tarea t) {
  final m = t.toJson();
  m['trabajadorIds'] = [...t.trabajadorIds]..sort();
  m['automatizaciones'] = [
    for (final a in [...t.automatizaciones]..sort((x, y) => x.id.compareTo(y.id))) a.toJson(),
  ];
  return _j(m);
}

Future<int> _filas(String tabla) async => (await Supabase.instance.client.from(tabla).select()).length;

Future<Store> _recargar() async {
  final s = Store();
  await s.cargarDesdeNube(await Nube.abrir());
  return s;
}

void main() {
  testWidgets(
    'cada tabla y columna: guardar, recargar, editar, borrar, simulaciones y limpiar',
    (tester) async {
      await tester.runAsync(() async {
        HttpOverrides.global = null;
        SharedPreferences.setMockInitialValues({});
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabasePublicable,
          authOptions: FlutterAuthClientOptions(localStorage: const EmptyLocalStorage(), detectSessionInUri: false),
        );
        final auth = Supabase.instance.client.auth;
        await auth.signInWithPassword(email: _env['SB_CORREO_A']!, password: 'prueba-123456');

        final s = Store();
        final n = await Nube.abrir();
        expect(n.nueva, isTrue, reason: 'la cuenta de prueba tiene que ser nueva');
        await s.cargarDesdeNube(n);
        await n.guardado;
        expect(Nube.error.value, isNull);
        expect(await _filas('trabajos'), 4, reason: 'plantillas iniciales');

        // ── Una fila con TODAS las columnas rellenas en cada tabla ──
        final etiqueta = EtiquetaTrabajo(id: s.nuevoId(), nombre: 'Urgente', color: 0xFFE5484D);
        s.guardarEtiqueta(etiqueta);

        final cliente = Cliente(
          id: s.nuevoId(),
          nombre: 'Comunidad Los Pinos',
          cif: 'H48123456',
          direccion: 'Calle Mayor 12',
          ciudad: 'Bilbao',
          cp: '48001',
          provincia: 'Bizkaia',
          telefono: '944111222',
          email: 'pinos@example.com',
          contacto: 'Marta',
          telefonoContacto: '600111222',
          notas: 'Portero: Ángel — "puerta azul"\nsegunda línea',
          foto: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
          activa: false,
          fechaAlta: DateTime(2026, 1, 15, 10, 30, 45, 123, 456),
          color: 0xFF8B6CEF,
          lat: 43.2630,
          lng: -2.9350,
        );
        s.guardarCliente(cliente);

        final ana = Trabajador(
          id: s.nuevoId(),
          nombre: 'Ana',
          apellidos: 'Etxeberria Ruiz',
          telefono: '600000001',
          email: 'ana@example.com',
          info: 'Turno de mañana',
          titulos: 'FP Electricidad',
          foto: 'iVBORw0KGgo=',
          competencias: ['Ascensores', 'Electricidad'],
          activo: false,
          estadoHoy: EstadoHoy.ausente,
          color: 0xFF0F9F8F,
        );
        final luis = Trabajador(id: s.nuevoId(), nombre: 'Luis', competencias: []);
        s.guardarTrabajador(ana);
        s.guardarTrabajador(luis);

        final plantilla = Tarea(id: s.nuevoId(), nombre: 'Plantilla propia', tipo: 'Ascensor', notas: 'modelo');
        s.guardarTarea(plantilla);
        expect(plantilla.esPlantilla, isTrue);

        final trabajo = Tarea(
          id: s.nuevoId(),
          clienteId: cliente.id,
          plantillaId: plantilla.id,
          nombre: 'Mantenimiento ascensor',
          tipo: 'Ascensor',
          marca: 'Otis',
          modelo: 'Gen2',
          numeroSerie: 'SN-001',
          ubicacion: 'Portal A',
          notas: 'Llevar llave',
          color: 0xFF2563EB,
          instalacion: DateTime(2020, 5, 1),
          ultimo: DateTime(2026, 9, 30),
          proximo: DateTime(2026, 11, 3),
          solicitud: DateTime(2026, 10, 20),
          inicioMin: 9 * 60 + 30,
          ventanaDesdeMin: 9 * 60,
          ventanaHastaMin: 11 * 60,
          duracionMin: 90,
          estadoMaquina: EstadoMaquina.averiada,
          estado: EstadoTrabajo.enCurso,
          criticidad: Criticidad.critica,
          periodicidad: Periodicidad.anual,
          activa: false,
          competencias: ['Ascensores', 'Electricidad'],
          trabajadorIds: [ana.id, luis.id],
          historial: [DateTime(2026, 7, 1), DateTime(2026, 8, 1), DateTime(2026, 9, 1)],
          automatizaciones: [
            Automatizacion(
              id: s.nuevoId(),
              nombre: 'Aviso previo',
              asunto: 'Mañana toca revisión',
              cuerpo: 'Hola,\nmañana pasamos. Gracias.',
              activa: false,
              aTrabajadores: false,
              aCliente: true,
              disparador: Disparador.antes,
              cantidad: 2,
              enHoras: true,
              extras: ['uno@example.com', 'dos@example.com'],
            ),
            Automatizacion(id: s.nuevoId(), nombre: 'Tras completar', disparador: Disparador.alCompletar),
            Automatizacion(id: s.nuevoId(), nombre: 'No hecho', disparador: Disparador.noHecho, cantidad: 3),
            Automatizacion(id: s.nuevoId(), nombre: 'Al asignar', disparador: Disparador.alAsignar),
          ],
        );
        s.guardarTarea(trabajo);

        // Subtrabajo y sub-subtrabajo (cada uno con su padre, color y hora).
        final sub = Tarea(
          id: s.nuevoId(),
          clienteId: cliente.id,
          padreId: trabajo.id,
          nombre: 'Revisar puertas',
          color: 0xFF16A34A,
          proximo: DateTime(2026, 11, 4),
          inicioMin: 600,
          duracionMin: 30,
        );
        final subsub = Tarea(id: s.nuevoId(), clienteId: cliente.id, padreId: sub.id, nombre: 'Lubricar guías');
        s.guardarTarea(sub);
        s.guardarTarea(subsub);
        await n.guardado;
        expect(Nube.error.value, isNull);

        // ── Otra instancia lo lee y es idéntico ──
        var r = await _recargar();
        expect(_j(r.etiquetas.single.toJson()), _j(etiqueta.toJson()), reason: 'etiqueta');
        expect(_j(r.clientes.single.toJson()), _j(cliente.toJson()), reason: 'cliente');
        expect(_j(r.trabajadores.firstWhere((w) => w.id == ana.id).toJson()), _j(ana.toJson()), reason: 'trabajador');
        expect(
          _j(r.trabajadores.firstWhere((w) => w.id == luis.id).toJson()),
          _j(luis.toJson()),
          reason: 'trabajador 2',
        );
        expect(_tarea(r.tarea(plantilla.id)!), _tarea(plantilla), reason: 'plantilla propia');
        expect(_tarea(r.tarea(trabajo.id)!), _tarea(trabajo), reason: 'trabajo con todos los campos');
        expect(_tarea(r.tarea(sub.id)!), _tarea(sub), reason: 'subtrabajo');
        expect(_tarea(r.tarea(subsub.id)!), _tarea(subsub), reason: 'sub-subtrabajo');
        expect(r.subtareas.length, 2);
        expect(r.tareas.length, 6, reason: '4 plantillas iniciales + plantilla propia + trabajo');
        expect(r.tarea(trabajo.id)!.automatizaciones.map((a) => a.disparador).toSet(), Disparador.values.toSet());

        // ── Editar y quitar cosas hijas ──
        cliente
          ..nombre = 'Comunidad Los Pinos 2'
          ..lat = null
          ..lng = null;
        s.guardarCliente(cliente);
        trabajo
          ..trabajadorIds = [luis.id]
          ..historial = [DateTime(2026, 9, 1)]
          ..estado = EstadoTrabajo.realizado
          ..automatizaciones = trabajo.automatizaciones.sublist(0, 1)
          ..plantillaId = null;
        s.guardarTarea(trabajo);
        s.borrarEtiqueta(etiqueta.id);
        s.borrarTarea(subsub.id);
        await n.guardado;
        expect(Nube.error.value, isNull);
        r = await _recargar();
        expect(_j(r.clientes.single.toJson()), _j(cliente.toJson()), reason: 'cliente editado');
        expect(_tarea(r.tarea(trabajo.id)!), _tarea(trabajo), reason: 'trabajo editado');
        expect(r.etiquetas, isEmpty);
        expect(r.tarea(subsub.id), isNull);
        expect(await _filas('trabajo_trabajadores'), 1);
        expect(await _filas('trabajo_historial'), 1);
        expect(await _filas('automatizaciones'), 1);

        // ── Simulaciones: ids no uuid (c1, d5, w2…) también se guardan y se recargan ──
        s.cargarSimulacion(
          equipo: 3,
          cuentas: 5,
          cantidadTareas: 12,
          desde: DateTime(2026, 11, 2),
          hasta: DateTime(2026, 11, 4),
          conSubtrabajos: true,
          cadaTantosConSubtrabajos: 2,
        );
        await n.guardado;
        expect(Nube.error.value, isNull);
        r = await _recargar();
        expect(r.clientes.length, 5);
        expect(r.trabajadores.length, 3);
        expect(r.tareas.where((t) => !t.esPlantilla).length, 12);
        expect(r.subtareas.length, s.subtareas.length);
        for (final t in [...r.tareas, ...r.subtareas]) {
          if (t.clienteId != null) expect(r.cliente(t.clienteId), isNotNull, reason: 'cliente de ${t.nombre}');
          for (final w in t.trabajadorIds) {
            expect(r.trabajador(w), isNotNull, reason: 'trabajador de ${t.nombre}');
          }
          if (t.padreId != null) expect(r.tarea(t.padreId), isNotNull, reason: 'padre de ${t.nombre}');
        }
        s.cargarDemo();
        await n.guardado;
        expect(Nube.error.value, isNull);
        r = await _recargar();
        expect(r.clientes.length, s.clientes.length);
        expect(r.tareas.length + r.subtareas.length, s.tareas.length + s.subtareas.length);
        s.cargarDemoRutas();
        await n.guardado;
        expect(Nube.error.value, isNull);
        r = await _recargar();
        expect(r.tareas.length + r.subtareas.length, s.tareas.length + s.subtareas.length);

        // ── Otra cuenta no ve nada de esto ──
        await Nube.cerrarSesion();
        await auth.signInWithPassword(email: _env['SB_CORREO_B']!, password: 'prueba-123456');
        final b = Store();
        final nb = await Nube.abrir();
        expect(nb.empresaId, isNot(n.empresaId));
        await b.cargarDesdeNube(nb);
        await nb.guardado;
        expect(b.clientes, isEmpty);
        expect(b.trabajadores, isEmpty);
        expect(await _filas('trabajos'), 4, reason: 'solo sus plantillas');
        await Nube.cerrarSesion();

        // ── Botón «Borrar datos de la base de datos» ──
        await auth.signInWithPassword(email: _env['SB_CORREO_A']!, password: 'prueba-123456');
        final n2 = await Nube.abrir();
        final limpio = Store();
        await limpio.cargarDesdeNube(n2);
        expect(limpio.clientes, isNotEmpty);
        await limpio.vaciarNube();
        expect(Nube.error.value, isNull);
        expect(await _filas('clientes'), 0);
        expect(await _filas('trabajadores'), 0);
        expect(await _filas('etiquetas'), 0);
        expect(await _filas('trabajos'), 0);
        expect(await _filas('automatizaciones'), 0);
        expect(await _filas('trabajo_trabajadores'), 0);
        expect(await _filas('trabajo_historial'), 0);
        r = await _recargar();
        expect(r.tareas, isEmpty);
        expect(r.clientes, isEmpty);
        await Nube.cerrarSesion();
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: _env['SB_CORREO_A'] == null, // se lanza con tool/probar_nube.py
  );
}
