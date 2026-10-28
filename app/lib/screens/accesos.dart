import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'invitar.dart';

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
      constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(c).height * .85),
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
      debugPrint('Pulpo: no se pudieron leer los accesos: $e');
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
      debugPrint('Pulpo: fallo en accesos: $e');
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Accesos de ${_nube.nombre}',
                style: TextStyle(color: P.texto, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, size: 20, color: P.textoSuave),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Quién entra con su propia cuenta y qué puede hacer.',
          style: TextStyle(color: P.textoSuave, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (_fallo)
          Text('No se pudieron leer los accesos. Comprueba la conexión.', style: TextStyle(color: P.rojo))
        else if (_accesos == null)
          const Center(
            child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _titulo('Con acceso'),
                for (final a in _accesos!) _filaAcceso(a),
                if (_invitaciones.isNotEmpty) ...[
                  _titulo('Invitaciones pendientes'),
                  ..._invitaciones.map(_filaInvitacion),
                ],
                if (_sinCuenta.where((w) => !_invitado(w)).isNotEmpty) ...[
                  _titulo('Trabajadores sin cuenta'),
                  for (final w in _sinCuenta.where((w) => !_invitado(w))) _filaSinCuenta(w),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: () async {
              await invitarAdministrador(context);
              await _cargar();
            },
            child: const Text('Invitar a un socio'),
          ),
        ),
      ],
    ),
  );

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: P.textoSuave),
    ),
  );

  Widget _fila({required Widget lider, required String titulo, required String subtitulo, required Widget accion}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
                  Text(
                    subtitulo,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: P.textoSuave, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            accion,
          ],
        ),
      );

  Widget _filaAcceso(Acceso a) {
    final yo = a.usuarioId == Supabase.instance.client.auth.currentUser?.id;
    final ficha = _ficha(a.trabajadorId);
    final nombre = a.nombre.isEmpty ? a.correo : a.nombre;
    final rol = a.rol == 'admin' ? 'Administrador' : 'Trabajador${ficha == null ? '' : ' · ${ficha.nombre}'}';
    return _fila(
      lider: Avatar(inicialesDe(nombre), a.rol == 'admin' ? P.morado : P.textoSuave, size: 32),
      titulo: yo ? '$nombre (tú)' : nombre,
      subtitulo: a.nombre.isEmpty ? rol : '$rol · ${a.correo}',
      accion: BotonMenu<String>(
        tooltip: '¿Qué puede hacer?',
        seleccionado: a.rol == 'admin' ? 'admin' : 'tb:${ficha?.id}',
        onSelected: (v) => switch (v) {
          'admin' => _hacer(() => _nube.cambiarRol(a.usuarioId, 'admin', trabajadorId: ficha?.id)),
          'quitar' => _quitar(a, nombre),
          _ => _hacer(() => _nube.cambiarRol(a.usuarioId, 'trabajador', trabajadorId: v.substring(3))),
        },
        opciones: [
          ('admin', const Text('Administrador: ve y gestiona todo')),
          // Para pasar a trabajador hay que ligarlo a una ficha libre (o a la suya).
          for (final w in [?ficha, ..._sinCuenta.where((w) => w != ficha)])
            ('tb:${w.id}', Text('Trabajador · ${w.nombre}')),
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
    if (!await confirmar(context, '¿Quitar el acceso a $nombre?')) return;
    await _hacer(() => _nube.quitarAcceso(a.usuarioId));
  }

  Widget _filaInvitacion(InvitacionPendiente i) {
    final ficha = _ficha(i.trabajadorId);
    final dias = i.caduca.difference(DateTime.now()).inDays;
    return _fila(
      lider: Avatar('?', P.borde, size: 32),
      titulo: i.rol == 'admin' ? 'Socio (administrador)' : 'Trabajador · ${ficha?.nombre ?? ''}',
      subtitulo: dias < 1 ? 'Caduca hoy' : 'Caduca en $dias ${dias == 1 ? 'día' : 'días'}',
      accion: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Copiar el enlace para reenviarlo',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: Nube.enlace(i.codigo)));
              _avisar('Enlace copiado.');
            },
            icon: Icon(Icons.copy_rounded, size: 18, color: P.textoSuave),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: P.rojo),
            onPressed: () => _hacer(() => _nube.anularInvitacion(i.id)),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }

  Widget _filaSinCuenta(Trabajador w) => _fila(
    lider: Avatar(inicialesDe(w.nombre), Color(w.color), size: 32),
    titulo: w.nombre,
    subtitulo: 'Falta invitarlo',
    accion: TextButton(
      onPressed: () async {
        await invitarTrabajador(context, w);
        await _cargar();
      },
      child: const Text('Invitar'),
    ),
  );
}
