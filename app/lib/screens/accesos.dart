import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../informes.dart' show FotoGuardada;
import 'invitar.dart';
import '../marca.dart';

/// Quién tiene acceso a la empresa (DEV-020): cuentas con su rol y ficha, invitaciones pendientes y
/// trabajadores que aún no tienen cuenta. Solo para administradores.
Future<void> abrirAccesos(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => Dialog(
    backgroundColor: P.superficie,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(P.radio),
      side: BorderSide(color: P.borde),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.sizeOf(c).height * .85),
      child: const Accesos(),
    ),
  ),
);

class Accesos extends StatefulWidget {
  const Accesos({super.key});

  @override
  State<Accesos> createState() => _AccesosState();
}

class _AccesosState extends State<Accesos> {
  List<Acceso>? _accesos;
  List<InvitacionPendiente> _invitaciones = [];
  bool _fallo = false;

  Nube get _nube => store.nube!;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await Future.wait([_nube.accesos(), _nube.invitacionesPendientes()]);
      if (!mounted) return;
      setState(() {
        _accesos = r[0] as List<Acceso>;
        _invitaciones = r[1] as List<InvitacionPendiente>;
        _fallo = false;
      });
    } catch (e) {
      debugPrint('Pultec: no se pudieron leer los accesos: $e');
      if (mounted) setState(() => _fallo = true);
    }
  }

  /// Hace algo en la base y vuelve a leer la lista; los fallos conocidos, en lenguaje de persona.
  Future<void> _hacer(Future<void> Function() accion) async {
    try {
      await accion();
    } on UltimoAdministrador {
      _avisar('La empresa tiene que tener al menos un administrador.');
    } catch (e) {
      debugPrint('Pultec: fallo en accesos: $e');
      _avisar('No se pudo hacer. Comprueba la conexión.');
    }
    await _cargar();
  }

  void _avisar(String texto) {
    if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(texto)));
  }

  Trabajador? _ficha(String? idBase) => store.trabajadores.where((w) => _nube.esFicha(w.id, idBase)).firstOrNull;

  /// Fichas sin cuenta ligada (a las que se puede pasar a alguien o invitar).
  List<Trabajador> get _sinCuenta =>
      store.trabajadores.where((w) => w.activo && !_accesos!.any((a) => _nube.esFicha(w.id, a.trabajadorId))).toList();

  bool _invitado(Trabajador w) => _invitaciones.any((i) => _nube.esFicha(w.id, i.trabajadorId));

  @override
  Widget build(BuildContext context) {
    final sinCuenta = _accesos == null ? <Trabajador>[] : _sinCuenta.where((w) => !_invitado(w)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accesos',
                      style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, color: P.texto),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quién entra en ${_nube.nombre} con su cuenta y qué puede hacer.',
                      style: TextStyle(color: P.textoSuave, fontSize: 13.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: Icon(CupertinoIcons.xmark, size: 18, color: P.textoSuave),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_fallo)
            Text('No se pudieron leer los accesos. Comprueba la conexión.', style: TextStyle(color: P.rojo))
          else if (_accesos == null)
            const Center(
              child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _seccion('Con acceso', [for (final a in _accesos!) _filaAcceso(a)]),
                    if (_invitaciones.isNotEmpty)
                      _seccion('Invitaciones pendientes', [..._invitaciones.map(_filaInvitacion)]),
                    if (sinCuenta.isNotEmpty)
                      _seccion(m('Trabajadores sin cuenta'), [for (final w in sinCuenta) _filaSinCuenta(w)]),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: BotonAccion(
                'Invitar a un socio',
                icono: Icons.person_add_alt_1_rounded,
                tooltip: 'Otra persona que lo gestiona todo contigo',
                onPressed: () async {
                  await invitarAdministrador(context);
                  await _cargar();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Un bloque: título con cuántos y sus filas en una tarjeta de borde fino, separadas por líneas.
  Widget _seccion(String titulo, List<Widget> filas) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              Text(titulo, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: P.texto)),
              const SizedBox(width: 6),
              Text('${filas.length}', style: TextStyle(fontSize: 13, color: P.textoSuave)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(P.radio),
            border: Border.all(color: P.borde),
          ),
          child: Column(
            children: [
              for (final (i, f) in filas.indexed) ...[
                if (i > 0) Divider(height: 1, color: P.borde),
                f,
              ],
            ],
          ),
        ),
      ],
    ),
  );

  /// Foto del técnico si la tiene; si no, sus iniciales en su color.
  Widget _cara(Trabajador? w, String nombre, Color color) => w != null && w.foto.isNotEmpty
      ? ClipOval(child: FotoGuardada(w.foto, width: 36, height: 36))
      : Avatar(inicialesDe(nombre), w == null ? color : colorPaleta(w.color), size: 36);

  Widget _fila({
    required Widget lider,
    required String titulo,
    required String subtitulo,
    Widget? etiqueta,
    required Widget accion,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
    child: Row(
      children: [
        lider,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: P.texto, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (subtitulo.isNotEmpty)
                Text(
                  subtitulo,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: P.textoSuave, fontSize: 12.5),
                ),
            ],
          ),
        ),
        if (etiqueta != null) ...[etiqueta, const SizedBox(width: 6)],
        accion,
      ],
    ),
  );

  Widget _filaAcceso(Acceso a) {
    final yo = a.usuarioId == Supabase.instance.client.auth.currentUser?.id;
    final ficha = _ficha(a.trabajadorId);
    final nombre = ficha?.nombreCompleto ?? (a.nombre.isEmpty ? a.correo : a.nombre);
    final admin = a.rol == 'admin';
    return _fila(
      lider: _cara(ficha, nombre, admin ? P.morado : P.textoSuave),
      titulo: yo ? '$nombre (tú)' : nombre,
      subtitulo: nombre == a.correo ? '' : a.correo,
      etiqueta: Pill(admin ? 'Administrador' : m('Trabajador'), admin ? P.morado : P.gris),
      accion: BotonMenu<String>(
        tooltip: '¿Qué puede hacer?',
        seleccionado: admin ? 'admin' : 'tb:${ficha?.id}',
        onSelected: (v) => switch (v) {
          'admin' => _hacer(() => _nube.cambiarRol(a.usuarioId, 'admin', trabajadorId: ficha?.id)),
          'quitar' => _quitar(a, nombre),
          _ => _hacer(() => _nube.cambiarRol(a.usuarioId, 'trabajador', trabajadorId: v.substring(3))),
        },
        opciones: [
          ('admin', const Text('Administrador: ve y gestiona todo')),
          // Para pasar a trabajador hay que ligarlo a una ficha libre (o a la suya).
          for (final w in [?ficha, ..._sinCuenta.where((w) => w != ficha)])
            ('tb:${w.id}', Text(m('Trabajador: ${w.nombreCompleto}'))),
          ('quitar', Text('Quitar acceso', style: TextStyle(color: P.rojo))),
        ],
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.more_horiz_rounded, size: 20, color: P.textoSuave),
        ),
      ),
    );
  }

  Future<void> _quitar(Acceso a, String nombre) async {
    if (!await confirmar(context, '¿Quitar el acceso a $nombre?', accion: 'Quitar acceso')) return;
    await _hacer(() => _nube.quitarAcceso(a.usuarioId));
  }

  Widget _filaInvitacion(InvitacionPendiente i) {
    final ficha = _ficha(i.trabajadorId);
    final dias = i.caduca.difference(DateTime.now()).inDays;
    final nombre = i.rol == 'admin' ? 'Socio' : ficha?.nombreCompleto ?? m('Trabajador');
    return _fila(
      lider: _cara(ficha, nombre, P.textoSuave),
      titulo: nombre,
      subtitulo: dias < 1 ? 'El enlace caduca hoy' : 'El enlace caduca en $dias ${dias == 1 ? 'día' : 'días'}',
      etiqueta: const Pill('Invitado', P.ambar, punto: true),
      accion: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Copiar el enlace para reenviarlo',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: Nube.enlace(i.codigo)));
              _avisar('Enlace copiado.');
            },
            icon: Icon(Icons.link_rounded, size: 18, color: P.textoSuave),
          ),
          IconButton(
            tooltip: 'Anular la invitación',
            onPressed: () => _hacer(() => _nube.anularInvitacion(i.id)),
            icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
          ),
        ],
      ),
    );
  }

  Widget _filaSinCuenta(Trabajador w) => _fila(
    lider: _cara(w, w.nombreCompleto, P.textoSuave),
    titulo: w.nombreCompleto,
    subtitulo: w.email.isEmpty ? 'Aún no entra en ${Marca.nombre}' : w.email,
    accion: Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Enlace(
        'Invitar',
        onTap: () async {
          await invitarTrabajador(context, w);
          await _cargar();
        },
      ),
    ),
  );
}
