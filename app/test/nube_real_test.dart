// Prueba contra el Supabase REAL: rellena cada tabla y cada columna, recarga desde otra instancia y compara.
// No corre sola: se lanza con `python3 tool/probar_nube.py`, que crea dos cuentas de prueba y las borra al acabar.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulpo/informes.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/nube.dart';
import 'package:pulpo/store.dart';
import 'package:pulpo/theme.dart' show P;
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

/// El JSON sin la foto: en la base la foto pasa a ser una ruta de Storage (se compara aparte con [_mismaFoto]).
String _sinFoto(Map<String, dynamic> m) => _j({...m}..remove('foto'));

/// La foto guardada en Storage es la misma que se subió en base64.
Future<void> _mismaFoto(Nube n, String guardada, String original) async {
  expect(guardada, endsWith('.png'), reason: 'la foto va a Storage');
  expect(await n.foto(guardada), base64Decode(original));
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

        // ── En vivo: otra sesión de la misma empresa cambia un trabajo y aquí aparece solo ──
        final db0 = Supabase.instance.client;
        final otra = SupabaseClient(supabaseUrl, supabasePublicable);
        await otra.auth.signInWithPassword(email: _env['SB_CORREO_A']!, password: 'prueba-123456');
        await Future<void>.delayed(const Duration(seconds: 2)); // que la suscripción esté lista
        final enVivo = s.tareas.first;
        await otra.from('trabajos').update({'nombre': 'Cambiado en otra sesión'}).eq('id', enVivo.id);
        for (var i = 0; i < 40 && s.tarea(enVivo.id)?.nombre != 'Cambiado en otra sesión'; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        expect(s.tarea(enVivo.id)?.nombre, 'Cambiado en otra sesión', reason: 'llega por Realtime');
        await otra.dispose();

        // ── Sin conexión: lo pendiente se apunta en el dispositivo y se borra al subirlo ──
        final prefs = await SharedPreferences.getInstance();
        s.guardarTarea(s.tarea(enVivo.id)!..notas = 'Apuntado antes de subir');
        await Future<void>.delayed(Duration.zero);
        expect(prefs.getString('pulpo_pendiente_${n.empresaId}'), contains('Apuntado antes de subir'));
        await n.guardado;
        expect(prefs.getString('pulpo_pendiente_${n.empresaId}'), isNull);
        // Lo que quedó apuntado al cerrar sin conexión se sube al volver a entrar.
        final fila = await db0.from('trabajos').select().eq('id', enVivo.id).single();
        await prefs.setString(
          'pulpo_pendiente_${n.empresaId}',
          jsonEncode({
            'subir': {
              'trabajos': [
                {...fila, 'notas': 'Hecho sin conexión'},
              ],
            },
            'borrar': {},
          }),
        );
        await n.subirPendiente();
        expect(
          (await db0.from('trabajos').select('notas').eq('id', enVivo.id).single())['notas'],
          'Hecho sin conexión',
        );
        expect(prefs.getString('pulpo_pendiente_${n.empresaId}'), isNull);
        await Future<void>.delayed(const Duration(seconds: 2)); // el eco en vivo lo trae al Store

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
          email: 'pinos@prueba.invalid',
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
          email: 'ana@prueba.invalid',
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
          precio: 120.5,
          iva: 10,
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
              extras: ['uno@prueba.invalid', 'dos@prueba.invalid'],
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
        expect(await n.envios(trabajo.id), isEmpty, reason: 'el registro de envíos se puede leer');
        expect(_j(r.etiquetas.single.toJson()), _j(etiqueta.toJson()), reason: 'etiqueta');
        expect(_sinFoto(r.clientes.single.toJson()), _sinFoto(cliente.toJson()), reason: 'cliente');
        await _mismaFoto(n, r.clientes.single.foto, cliente.foto);
        final rAna = r.trabajadores.firstWhere((w) => w.id == ana.id);
        expect(_sinFoto(rAna.toJson()), _sinFoto(ana.toJson()), reason: 'trabajador');
        await _mismaFoto(n, rAna.foto, ana.foto);
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
        expect(_sinFoto(r.clientes.single.toJson()), _sinFoto(cliente.toJson()), reason: 'cliente editado');
        expect(_tarea(r.tarea(trabajo.id)!), _tarea(trabajo), reason: 'trabajo editado');
        expect(r.etiquetas, isEmpty);
        expect(r.tarea(subsub.id), isNull);
        expect(await _filas('trabajo_trabajadores'), 1);
        expect(await _filas('trabajo_historial'), 1);
        expect(await _filas('automatizaciones'), 1);

        // ── Equipo del cliente: su vencimiento, un documento y el trabajo enlazado ──
        final equipo = Equipo(
          id: s.nuevoId(),
          clienteId: cliente.id,
          tipo: 'Ascensor',
          nombre: 'Ascensor 1',
          marca: 'Orona',
          modelo: '3G',
          numeroSerie: 'S-1',
          ubicacion: 'Portal',
          notas: 'Llave en conserjería',
          instalacion: DateTime(2015, 3, 2),
          estado: EstadoMaquina.revision,
        );
        s.guardarEquipo(equipo);
        final oca = Vencimiento(
          id: s.nuevoId(),
          equipoId: equipo.id,
          nombre: 'Inspección OCA',
          vence: DateTime(2026, 12, 1),
          avisarDias: 60,
        );
        s.guardarVencimiento(oca);
        s.guardarTarea(trabajo..equipoId = equipo.id);
        final pdf = Uint8List.fromList('%PDF-1.4'.codeUnits);
        final ruta = await n.subirDocumentoEquipo(equipo.id, 'certificado.pdf', pdf);
        s.guardarEquipo(equipo..documentos = [ruta]);
        await n.guardado;
        expect(Nube.error.value, isNull);
        r = await _recargar();
        expect(_j(r.equipos.single.toJson()), _j(equipo.toJson()), reason: 'equipo');
        expect(_j(r.vencimientos.single.toJson()), _j(oca.toJson()), reason: 'vencimiento');
        expect(r.tarea(trabajo.id)!.equipoId, equipo.id, reason: 'trabajo enlazado al equipo');
        expect(await n.documentoEquipo(ruta), pdf, reason: 'documento en Storage');
        await n.borrarDocumentoEquipo(ruta);
        s.borrarEquipo(equipo.id);
        await n.guardado;
        expect(Nube.error.value, isNull);
        r = await _recargar();
        expect(r.equipos, isEmpty);
        expect(r.vencimientos, isEmpty);
        expect(r.tarea(trabajo.id)!.equipoId, isNull, reason: 'el trabajo se queda sin equipo');

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
        // ── Invitaciones y roles: trabajador (C) y socio administrador (D) ──
        final pepe = Trabajador(id: limpio.nuevoId(), nombre: 'Pepe', competencias: ['Calderas (RITE)']);
        final cli1 = Cliente(id: limpio.nuevoId(), nombre: 'Cliente de Pepe');
        final cli2 = Cliente(id: limpio.nuevoId(), nombre: 'Cliente ajeno a Pepe');
        limpio
          ..guardarTrabajador(pepe)
          ..guardarCliente(cli1)
          ..guardarCliente(cli2);
        final trabajoP = Tarea(
          id: limpio.nuevoId(),
          clienteId: cli1.id,
          nombre: 'Trabajo de Pepe',
          proximo: hoy(),
          trabajadorIds: [pepe.id],
          precio: 80,
          // Puntual con aviso al completarse: al marcarlo hecho ya no tiene próxima fecha (salía «—» en el email).
          periodicidad: Periodicidad.unica,
          automatizaciones: [
            Automatizacion(
              id: limpio.nuevoId(),
              nombre: 'Hecho',
              disparador: Disparador.alCompletar,
              aTrabajadores: false,
              cuerpo: 'Hecho el {fecha}.',
              extras: ['aviso@prueba.invalid'],
            ),
          ],
        );
        final trabajoQ = Tarea(id: limpio.nuevoId(), clienteId: cli2.id, nombre: 'Trabajo de otro', proximo: hoy());
        limpio
          ..guardarTarea(trabajoP)
          ..guardarTarea(trabajoQ);
        await n2.guardado;
        // Presupuestos y proformas: la base numera cada tipo por separado.
        final f1 = await n2.guardarDocumento({'tipo': 'proforma', 'cliente_id': cli1.id, 'lineas': []});
        final f2 = await n2.guardarDocumento({'tipo': 'proforma', 'cliente_id': cli1.id, 'lineas': []});
        final p1 = await n2.guardarDocumento({'tipo': 'presupuesto', 'lineas': []});
        expect((f1['numero'], f2['numero'], p1['numero']), (1, 2, 1));
        await n2.guardarDocumento({...f1, 'cobrada_el': '2026-10-28'});
        expect((await n2.documentos()).length, 3);
        final codigoW = await n2.crearInvitacion(rol: 'trabajador', trabajadorId: pepe.id);
        final codigoA = await n2.crearInvitacion(rol: 'admin');
        expect(Nube.enlace(codigoW), contains('invitacion=$codigoW'));
        await Nube.cerrarSesion();

        // Sin sesión, la pantalla de acceso ve a qué empresa y con qué rol une cada invitación (DEV-019).
        Nube.invitacion = codigoW;
        final verW = await Nube.verInvitacion();
        expect((verW?.rol, verW?.trabajador), ('trabajador', pepe.nombre));
        expect(verW?.empresa, isNotEmpty);
        Nube.invitacion = codigoA;
        expect((await Nube.verInvitacion())?.rol, 'admin');
        Nube.invitacion = 'no-existe';
        expect(await Nube.verInvitacion(), isNull);

        // Trabajador: acepta, entra con su ficha y ve solo lo suyo. Como al confirmar el correo: el código va en
        // la cuenta (se guarda al crearla) y dos pestañas entran a la vez, una con el código y otra sin él;
        // ninguna le crea una empresa propia (BUG del enlace de trabajador que entraba como administrador).
        await auth.signInWithPassword(email: _env['SB_CORREO_C']!, password: 'prueba-123456');
        await auth.updateUser(UserAttributes(data: {'invitacion': codigoW}));
        final pestanas = await Future.wait([
          Supabase.instance.client.rpc('entrar', params: {'p_codigo': codigoW}),
          Supabase.instance.client.rpc('entrar', params: {'p_codigo': null}),
        ]);
        expect(pestanas.map((r) => (r as List).single['creada']), [false, false]);
        Nube.invitacion = null;
        Nube.creadaAlEntrar = false;
        final nC = await Nube.abrir();
        expect(nC.rol, 'trabajador');
        expect(nC.trabajadorId, pepe.id);
        expect(nC.empresaId, n2.empresaId);
        expect(Nube.invitacion, isNull);
        expect(Nube.creadaAlEntrar, isFalse);
        expect(await _filas('empresas'), 1, reason: 'solo la de su invitación, sin empresa propia');
        final sC = Store();
        await sC.cargarDesdeNube(nC);
        expect(sC.tareas.map((t) => t.id), [trabajoP.id], reason: 'solo su trabajo');
        expect(sC.clientes.map((c) => c.id), [cli1.id], reason: 'solo el cliente de su trabajo');
        expect(sC.trabajadores.map((w) => w.id), [pepe.id], reason: 'solo su ficha');
        expect(sC.tarea(trabajoP.id)!.precio, 0, reason: 'el trabajador no ve precios');
        expect(await nC.documentos(), isEmpty, reason: 'ni facturas');
        // Marca su trabajo como hecho; se guarda (estado, fechas e histórico).
        sC.marcarHecha(sC.tarea(trabajoP.id)!);
        await nC.guardado;
        expect(Nube.error.value, isNull);
        // Deja el parte de su trabajo con foto y firma; en un trabajo que no es suyo, no puede.
        final jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
        final png = Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));
        final parte = await nC.crearInforme(
          Informe(
            trabajoId: trabajoP.id,
            trabajadorId: pepe.id,
            resultado: 1,
            notas: 'Correa cambiada',
            material: 'Correa',
            minutos: 45,
            firmante: 'Ana',
          ),
          [jpg],
          png,
        );
        expect(parte.fotos.single, endsWith('/0.jpg'));
        // Reintento de un parte que se hizo sin conexión (mismo id): no falla ni lo duplica.
        final otraVez = await nC.crearInforme(
          Informe(trabajoId: trabajoP.id, trabajadorId: pepe.id, resultado: 1, notas: 'Correa cambiada'),
          [jpg],
          png,
          id: parte.id,
        );
        expect(otraVez.fotos, parte.fotos);
        await expectLater(
          nC.crearInforme(Informe(trabajoId: trabajoQ.id, trabajadorId: pepe.id, resultado: 0, notas: 'x'), [], null),
          throwsA(anything),
        );
        expect((await nC.informes(trabajoP.id)).single.id, parte.id);
        // No puede cambiar nada más del trabajo, ni crear, ni ver lo de otros.
        final db = Supabase.instance.client;
        await expectLater(db.from('trabajos').update({'nombre': 'cambiado'}).eq('id', trabajoP.id), throwsA(anything));
        expect(await _filas('automatizaciones'), 0);
        expect(await _filas('etiquetas'), 0);
        expect(await _filas('invitaciones'), 0);
        // La invitación ya está gastada: con otra cuenta no vale.
        await Nube.cerrarSesion();
        await auth.signInWithPassword(email: _env['SB_CORREO_B']!, password: 'prueba-123456');
        expect(await _filas('informes'), 0, reason: 'otra empresa no ve los partes');
        expect(await _filas('documentos'), 0, reason: 'ni sus facturas');
        expect(await db.storage.from('fotos').list(path: '${n2.empresaId}/informes/${parte.id}'), isEmpty);
        Nube.invitacion = codigoW;
        expect(await Nube.verInvitacion(), isNull, reason: 'ya usada');
        await expectLater(Nube.abrir(), throwsA(isA<InvitacionNoValida>()));
        await Nube.cerrarSesion();

        // Socio: acepta la de administrador y ve y edita todo.
        await auth.signInWithPassword(email: _env['SB_CORREO_D']!, password: 'prueba-123456');
        // Dos pestañas con el mismo código a la vez: las dos entran (la segunda ve que ya es suya).
        Nube.invitacion = codigoA;
        final dos = await Future.wait([
          Supabase.instance.client.rpc('entrar', params: {'p_codigo': codigoA}),
          Supabase.instance.client.rpc('entrar', params: {'p_codigo': codigoA}),
        ]);
        expect(dos.map((r) => (r as List).single['empresa']), [n2.empresaId, n2.empresaId]);
        final nD = await Nube.abrir();
        expect(nD.rol, 'admin');
        expect(await _filas('empresas'), 1, reason: 'el socio sin empresa propia');
        final aviso = (await db.from('envios_automatizacion').select('cuerpo')).single['cuerpo'] as String;
        final d = hoy();
        final dia = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        expect(aviso, startsWith('Hecho el $dia.'), reason: 'el email lleva el día hecho, no «—»');
        expect(aviso, contains('\n-- \n'), reason: 'pie como firma');
        expect(nD.empresaId, n2.empresaId);
        final sD = Store();
        await sD.cargarDesdeNube(nD);
        expect(sD.tareas.length, 2);
        expect(sD.clientes.length, 2);
        expect(sD.tarea(trabajoP.id)!.historial, isNotEmpty, reason: 'el socio ve lo que marcó el trabajador');
        expect(sD.tarea(trabajoP.id)!.ultimo, isNotNull);
        expect(sD.tarea(trabajoP.id)!.precio, 80, reason: 'el socio administrador sí ve precios');
        final leido = (await nD.informes(trabajoP.id)).single;
        expect((leido.material, leido.minutos, leido.firmante, leido.resultado), ('Correa', 45, 'Ana', 1));
        expect(await nD.foto(leido.fotos.single), jpg);
        expect(await nD.foto(leido.firma!), png);
        sD.tarea(trabajoQ.id)!.nombre = 'Editado por el socio';
        sD.guardarTarea(sD.tarea(trabajoQ.id)!);
        await nD.guardado;
        expect(Nube.error.value, isNull);
        expect(await _filas('miembros'), 3);
        await Nube.cerrarSesion();

        // Vuelve el administrador: ve lo del trabajador y lo del socio.
        await auth.signInWithPassword(email: _env['SB_CORREO_A']!, password: 'prueba-123456');
        final nA3 = await Nube.abrir();
        final sA3 = Store();
        await sA3.cargarDesdeNube(nA3);
        expect(sA3.tarea(trabajoQ.id)!.nombre, 'Editado por el socio');
        expect(sA3.tarea(trabajoP.id)!.historial, isNotEmpty);
        expect(await _filas('invitaciones'), 2);
        expect(await _filas('miembros'), 3);
        // «Tiene acceso» en la ficha del trabajador: la cuenta de C se reconoce desde la ficha de Pepe.
        expect((await nA3.accesos()).where((a) => nA3.esFicha(pepe.id, a.trabajadorId)).map((a) => a.rol), [
          'trabajador',
        ]);
        await db.storage.from('fotos').remove([...parte.fotos, parte.firma!]);
        await sA3.vaciarNube();
        // ── El botón de borrar la deja solo con las cuentas ──
        expect(Nube.error.value, isNull);
        expect(await _filas('clientes'), 0);
        expect(await _filas('trabajadores'), 0);
        expect(await _filas('etiquetas'), 0);
        expect(await _filas('trabajos'), 0);
        expect(await _filas('automatizaciones'), 0);
        expect(await _filas('trabajo_trabajadores'), 0);
        expect(await _filas('trabajo_historial'), 0);
        expect(await _filas('informes'), 0);
        expect(await _filas('trabajo_precios'), 0);
        expect(await _filas('documentos'), 0);
        r = await _recargar();
        expect(r.tareas, isEmpty);
        expect(r.clientes, isEmpty);
        await Nube.cerrarSesion();

        // ── DEV-018: perfil, varias empresas con sus datos y tipo, borrar empresa y cuenta ──
        // El socio (D) pone su perfil: lo ve el administrador de su empresa (A), no alguien de fuera (B).
        await auth.signInWithPassword(email: _env['SB_CORREO_D']!, password: 'prueba-123456');
        await Nube.guardarPerfil(nombre: 'Socio Prueba', foto: null);
        expect((await Nube.perfil()).nombre, 'Socio Prueba');
        final idD = auth.currentUser!.id;
        await Nube.cerrarSesion();
        await auth.signInWithPassword(email: _env['SB_CORREO_A']!, password: 'prueba-123456');
        expect((await db.from('perfiles').select().eq('usuario_id', idD)).length, 1);

        // ── DEV-020: accesos de la empresa ──
        final nA4 = await Nube.abrir();
        final idA = auth.currentUser!.id;
        var accesos = await nA4.accesos();
        expect(accesos.map((a) => a.rol), ['admin', 'admin', 'trabajador'], reason: 'A, D y C');
        expect(accesos.firstWhere((a) => a.usuarioId == idD).nombre, 'Socio Prueba');
        expect(accesos.firstWhere((a) => a.usuarioId == idA).correo, _env['SB_CORREO_A']);
        // D pasa a trabajador: A queda como único administrador y no se puede quitar ni degradar.
        await nA4.cambiarRol(idD, 'trabajador');
        await expectLater(nA4.quitarAcceso(idA), throwsA(isA<UltimoAdministrador>()));
        await expectLater(nA4.cambiarRol(idA, 'trabajador'), throwsA(isA<UltimoAdministrador>()));
        await expectLater(Nube.borrarCuenta(), throwsA(isA<UltimoAdministrador>()));
        expect(auth.currentUser, isNotNull, reason: 'no se ha borrado nada');
        // Vuelve a administrador; a C se le quita el acceso.
        await nA4.cambiarRol(idD, 'admin');
        final idC = accesos.firstWhere((a) => a.rol == 'trabajador').usuarioId;
        await nA4.quitarAcceso(idC);
        accesos = await nA4.accesos();
        expect(accesos.map((a) => a.usuarioId), isNot(contains(idC)));
        // Invitaciones pendientes: la nueva sale; las usadas no; anularla la quita.
        await nA4.crearInvitacion(rol: 'admin');
        var pendientes = await nA4.invitacionesPendientes();
        expect(pendientes.length, 1);
        await nA4.anularInvitacion(pendientes.single.id);
        pendientes = await nA4.invitacionesPendientes();
        expect(pendientes, isEmpty);
        await Nube.cerrarSesion();

        // B: su primera empresa y otra de ascensores, que arranca solo con la plantilla de ascensor.
        await auth.signInWithPassword(email: _env['SB_CORREO_B']!, password: 'prueba-123456');
        expect((await db.from('perfiles').select().eq('usuario_id', idD)), isEmpty, reason: 'perfil ajeno');
        final nB = await Nube.abrir();
        final sB = Store();
        await sB.cargarDesdeNube(nB);
        await nB.guardado;
        final antes = Nube.reabrir.value;
        await Nube.crearEmpresa('Ascensores Prueba', 'Ascensores');
        expect(Nube.reabrir.value, antes + 1, reason: 'la app vuelve a abrir la empresa');
        final nB2 = await Nube.abrir();
        expect(nB2.empresaId, isNot(nB.empresaId), reason: 'entra en la recién creada');
        expect(nB2.nueva, isTrue);
        expect(nB2.tipo, 'Ascensores');
        final sB2 = Store();
        await sB2.cargarDesdeNube(nB2);
        await nB2.guardado;
        expect(sB2.tareas.map((t) => t.tipo), ['Ascensor']);
        expect((await Nube.empresas()).map((e) => e.nombre), ['Ascensores Prueba', 'Mi empresa']);
        await Nube.guardarEmpresa(nB2.empresaId, {
          'cif': 'B12345678',
          'telefono': '944000000',
          'direccion': 'Calle Prueba 1',
        });
        expect((await Nube.datosEmpresa(nB2.empresaId))['cif'], 'B12345678');
        // Icono y color: sin elegir, el de su tipo y el morado; se pueden editar los de otra empresa de la cuenta.
        final asc = (await Nube.empresas()).first;
        expect((asc.icono, asc.color), ('ascensor', P.morado));
        await Nube.guardarEmpresa(nB.empresaId, {'icono': 'jardin', 'color': 0xFF16A34A});
        final mia = (await Nube.empresas()).last;
        expect((mia.id, mia.icono, mia.color.toARGB32()), (nB.empresaId, 'jardin', 0xFF16A34A));
        // Cambiar de empresa y volver: se recuerda la elegida.
        await Nube.entrarEn(nB.empresaId);
        expect((await Nube.abrir()).empresaId, nB.empresaId);
        await Nube.entrarEn(nB2.empresaId);
        expect((await Nube.abrir()).empresaId, nB2.empresaId);
        // Borrar la de ascensores: se va con sus trabajos y queda la otra.
        await nB2.borrarEmpresa();
        expect((await Nube.empresas()).map((e) => e.id), [nB.empresaId]);
        expect((await Nube.abrir()).empresaId, nB.empresaId);
        // Borrar la cuenta (función borrar-cuenta): se va su empresa y ya no puede entrar.
        await Nube.borrarCuenta();
        await expectLater(
          auth.signInWithPassword(email: _env['SB_CORREO_B']!, password: 'prueba-123456'),
          throwsA(isA<AuthException>()),
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: _env['SB_CORREO_A'] == null, // se lanza con tool/probar_nube.py
  );
}
