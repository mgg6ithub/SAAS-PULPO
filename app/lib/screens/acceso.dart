import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../nube.dart';
import '../shell.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cuenta.dart';
import 'vista_trabajador.dart';

/// Entrada de la app con Supabase: sin sesión pide acceso; con sesión carga la empresa y abre Pulpo.
class PuertaNube extends StatefulWidget {
  const PuertaNube({super.key});

  @override
  State<PuertaNube> createState() => _PuertaNubeState();
}

enum _Fase { acceso, cargando, listo, invitacionMala, fallo }

class _PuertaNubeState extends State<PuertaNube> {
  StreamSubscription<AuthState>? _sub;
  _Fase _fase = _Fase.cargando;
  String? _usuario;
  bool _pedirClave = false;

  /// La app se abrió desde el primer enlace del cambio de correo (Supabase pide pulsar el de los dos correos).
  static bool _avisoCorreo = (Uri.base.queryParameters['message'] ?? '').contains('other email');

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((e) {
      // Vuelve del enlace de «olvidé mi contraseña»: al entrar, se pide la nueva.
      if (e.event == AuthChangeEvent.passwordRecovery) _pedirClave = true;
      _sesion(e.session);
    });
    _sesion(Supabase.instance.client.auth.currentSession);
    Nube.reabrir.addListener(_reabrir);
  }

  /// Se ha cambiado, creado o borrado una empresa: se vuelve a abrir la que toque.
  void _reabrir() {
    if (_usuario != null) _abrir(_usuario!);
  }

  @override
  void dispose() {
    Nube.reabrir.removeListener(_reabrir);
    _sub?.cancel();
    super.dispose();
  }

  void _sesion(Session? s) {
    if (s == null) {
      _usuario = null;
      store.vaciar();
      rolTrabajador.value = null;
      if (mounted) setState(() => _fase = _Fase.acceso);
    } else if (s.user.id != _usuario) {
      _abrir(s.user.id);
    }
  }

  Future<void> _abrir(String usuario) async {
    _usuario = usuario;
    setState(() => _fase = _Fase.cargando);
    try {
      await store.cargarDesdeNube(await Nube.abrir());
      // Un trabajador entra directo a su vista; un administrador, a la de siempre.
      rolTrabajador.value = store.nube!.esTrabajador ? store.nube!.trabajadorId : null;
      if (mounted) setState(() => _fase = _Fase.listo);
      if (Nube.creadaAlEntrar) {
        Nube.creadaAlEntrar = false;
        final proveedores = Supabase.instance.client.auth.currentUser?.appMetadata['providers'] as List? ?? [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) nombrarEmpresa(context, porGoogle: proveedores.contains('google'));
        });
      }
      // Vuelve del primer enlace del cambio de correo: falta el del otro correo.
      if (_avisoCorreo) {
        _avisoCorreo = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('Enlace aceptado. Para cambiar el correo, pulsa también el del otro correo.'),
              ),
            );
          }
        });
      }
      if (_pedirClave) {
        _pedirClave = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cambiarClave(context, recuperando: true);
        });
      }
    } on InvitacionNoValida {
      if (mounted) setState(() => _fase = _Fase.invitacionMala);
    } catch (e) {
      debugPrint('Pulpo: no se pudo abrir la empresa: $e');
      if (mounted) setState(() => _fase = _Fase.fallo);
    }
  }

  @override
  Widget build(BuildContext context) => switch (_fase) {
    _Fase.acceso => const PantallaAcceso(),
    _Fase.cargando => Scaffold(
      backgroundColor: P.fondo,
      body: const Center(child: CircularProgressIndicator()),
    ),
    _Fase.listo => Stack(
      children: [
        const Shell(),
        Positioned(
          left: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              for (final (aviso, color) in [(Nube.subiendo, P.tinta), (Nube.choque, P.tinta), (Nube.error, P.rojo)])
                ValueListenableBuilder<String?>(
                  valueListenable: aviso,
                  builder: (_, e, _) => e == null
                      ? const SizedBox.shrink()
                      : Material(
                          color: color,
                          borderRadius: BorderRadius.circular(P.radioControl),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
    ),
    _Fase.invitacionMala => _Aviso(
      'La invitación ya se usó o ha caducado. Pide a quien te invitó un enlace nuevo.',
      textoBoton: 'Entrar sin invitación',
      onReintentar: () => _abrir(_usuario!),
    ),
    _Fase.fallo => _Aviso('No se pudo abrir tu empresa. Comprueba la conexión.', onReintentar: () => _abrir(_usuario!)),
  };
}

class _Aviso extends StatelessWidget {
  final String texto;
  final VoidCallback? onReintentar;
  final String textoBoton;
  const _Aviso(this.texto, {required this.onReintentar, this.textoBoton = 'Reintentar'});

  @override
  Widget build(BuildContext context) => _Marco(
    children: [
      Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(color: P.texto, fontSize: 14, height: 1.4),
      ),
      const SizedBox(height: 16),
      if (onReintentar != null) ...[
        BotonPrimario(textoBoton, icono: Icons.refresh_rounded, conIcono: true, onPressed: onReintentar!),
        const SizedBox(height: 8),
      ],
      TextButton(onPressed: Nube.cerrarSesion, child: const Text('Cerrar sesión')),
    ],
  );
}

class _Marco extends StatelessWidget {
  final List<Widget> children;
  const _Marco({required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: P.fondo,
    body: Center(
      child: SingleChildScrollView(
        padding: margenPagina,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Tarjeta(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: LogoPulpo(size: 44)),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Entrar o crear cuenta en una sola pantalla (DEV-019): Google arriba; debajo, correo y contraseña.
class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key});

  @override
  State<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends State<PantallaAcceso> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _nueva = false, _enviando = false, _verClave = false;
  String? _aviso;
  bool _avisoMalo = true;

  /// Correo de una cuenta creada que aún no se ha confirmado: deja reenviar el correo.
  String? _porConfirmar;

  /// Qué dice la invitación pendiente: null mientras se consulta o si no hay.
  String? _invitacion;

  @override
  void initState() {
    super.initState();
    Nube.correoRecordado().then((c) {
      if (c != null && mounted && _correo.text.isEmpty) _correo.text = c;
    });
    if (Nube.invitacion != null) _leerInvitacion();
  }

  Future<void> _leerInvitacion() async {
    String texto;
    try {
      final i = await Nube.verInvitacion();
      texto = i == null
          ? 'Esta invitación ya se usó o ha caducado. Pide a quien te invitó un enlace nuevo.'
          : 'Te unes a ${i.empresa} como ${i.rol == 'admin' ? 'administrador' : 'trabajador'}'
                '${i.trabajador == null || i.trabajador!.isEmpty ? '' : ' (${i.trabajador})'}.';
    } catch (_) {
      texto = 'Te han invitado a una empresa. Entra o crea tu cuenta para unirte.';
    }
    if (mounted) setState(() => _invitacion = texto);
  }

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  bool get _correoValido => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_correo.text.trim());

  Future<void> _intentar(Future<void> Function() accion) async {
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      await accion();
    } on AuthException catch (e) {
      _ponerAviso(_traducir(e.message));
      if (e.message.toLowerCase().contains('not confirmed')) _porConfirmar = _correo.text.trim();
    } catch (_) {
      _ponerAviso('No se pudo conectar. Comprueba la conexión y vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _recuperar() async {
    if (!_correoValido) return _ponerAviso('Escribe arriba tu correo y vuelve a pulsar.');
    await _intentar(() async {
      await Nube.recuperarClave(_correo.text.trim());
      _ponerAviso('Si hay una cuenta con ese correo, te llegará un enlace para poner otra contraseña.', malo: false);
    });
  }

  Future<void> _reenviar() => _intentar(() async {
    await Nube.reenviarConfirmacion(_porConfirmar!);
    _ponerAviso('Te lo hemos vuelto a enviar. Mira también en spam.', malo: false);
  });

  void _ponerAviso(String texto, {bool malo = true}) {
    if (!mounted) return;
    setState(() {
      _aviso = texto;
      _avisoMalo = malo;
    });
  }

  Future<void> _enviar() async {
    final correo = _correo.text.trim();
    if (!_correoValido) return _ponerAviso('Revisa el correo: falta algo (como nombre@empresa.com).');
    if (_clave.text.length < 6) return _ponerAviso('La contraseña necesita al menos 6 caracteres.');
    await _intentar(() async {
      await Nube.recordarCorreo(correo);
      if (!_nueva) {
        await Supabase.instance.client.auth.signInWithPassword(email: correo, password: _clave.text);
        return;
      }
      final r = await Nube.crearCuenta(correo, _clave.text);
      if (r.session == null && mounted) {
        setState(() {
          _aviso = 'Te hemos enviado un correo a $correo. Ábrelo para confirmar la cuenta y después entra.';
          _avisoMalo = false;
          _nueva = false;
          _porConfirmar = correo;
        });
      }
    });
  }

  void _cambiarModo() => setState(() {
    _nueva = !_nueva;
    _aviso = null;
  });

  /// Los errores de Supabase llegan en inglés: cada uno con una frase que diga qué hacer.
  static String _traducir(String m) {
    final t = m.toLowerCase();
    if (t.contains('invalid login')) {
      return 'Correo o contraseña incorrectos. Revísalos o pulsa «¿Has olvidado la contraseña?».';
    }
    if (t.contains('already registered') || t.contains('already been registered')) {
      return 'Ya hay una cuenta con ese correo. Entra con ella o recupera la contraseña.';
    }
    if (t.contains('not confirmed')) return 'Falta confirmar el correo. Abre el enlace que te enviamos o pide otro.';
    if (t.contains('rate limit') || t.contains('security purposes')) {
      return 'Demasiados intentos seguidos. Espera un minuto y vuelve a probar.';
    }
    if (t.contains('password')) return 'La contraseña no vale: usa al menos 6 caracteres.';
    if (t.contains('email') && (t.contains('invalid') || t.contains('validate'))) {
      return 'Ese correo no es válido. Revisa que esté bien escrito.';
    }
    if (t.contains('signups not allowed') || t.contains('signup is disabled')) {
      return 'Ahora no se pueden crear cuentas. Pide a tu empresa que te invite.';
    }
    return 'Algo ha fallado. Vuelve a intentarlo en un momento.';
  }

  @override
  Widget build(BuildContext context) {
    final suave = TextStyle(color: P.textoSuave, fontSize: 13.5, height: 1.4);
    return _Marco(
      children: [
        Text(
          _nueva ? 'Crea tu cuenta' : 'Entra en Pulpo',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          Nube.invitacion != null
              ? (_invitacion ?? 'Mirando tu invitación…')
              : _nueva
              ? 'Solo correo y contraseña. El nombre de la empresa, al entrar.'
              : 'Tu empresa, tus clientes y tus trabajos.',
          textAlign: TextAlign.center,
          style: Nube.invitacion != null ? suave.copyWith(color: P.texto, fontWeight: FontWeight.w600) : suave,
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _enviando ? null : () => _intentar(Nube.entrarConGoogle),
          child: const Text('Continuar con Google'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            spacing: 10,
            children: [
              Expanded(child: Divider(color: P.borde, height: 1)),
              Text('o con tu correo', style: suave.copyWith(fontSize: 12.5)),
              Expanded(child: Divider(color: P.borde, height: 1)),
            ],
          ),
        ),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Correo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _clave,
                obscureText: !_verClave,
                autofillHints: [_nueva ? AutofillHints.newPassword : AutofillHints.password],
                onSubmitted: (_) => _enviando ? null : _enviar(),
                decoration: InputDecoration(
                  hintText: _nueva ? 'Contraseña (mín. 6 caracteres)' : 'Contraseña',
                  suffixIcon: IconButton(
                    tooltip: _verClave ? 'Ocultar contraseña' : 'Ver contraseña',
                    onPressed: () => setState(() => _verClave = !_verClave),
                    icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_nueva)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _enviando ? null : _recuperar,
              child: const Text('¿Has olvidado la contraseña?'),
            ),
          )
        else
          const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _aviso == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _aviso!,
                    style: TextStyle(color: _avisoMalo ? P.rojo : P.verde, fontSize: 13, height: 1.4),
                  ),
                ),
        ),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: _enviando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_nueva ? 'Crear cuenta' : 'Entrar'),
        ),
        if (!_nueva && _porConfirmar != null)
          TextButton(onPressed: _enviando ? null : _reenviar, child: const Text('Reenviar el correo de confirmación')),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_nueva ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?', style: suave),
            TextButton(onPressed: _enviando ? null : _cambiarModo, child: Text(_nueva ? 'Entra' : 'Crea una')),
          ],
        ),
      ],
    );
  }
}
