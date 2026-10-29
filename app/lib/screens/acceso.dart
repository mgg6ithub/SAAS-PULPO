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
              for (final (aviso, color) in [(Nube.choque, P.tinta), (Nube.error, P.rojo)])
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

/// Correo y contraseña: entrar o crear cuenta.
class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key});

  @override
  State<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends State<PantallaAcceso> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _nueva = false, _enviando = false;
  String? _aviso;
  bool _avisoMalo = true;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _recuperar() async {
    final correo = _correo.text.trim();
    if (!correo.contains('@')) {
      setState(() {
        _aviso = 'Escribe tu correo y vuelve a pulsar.';
        _avisoMalo = true;
      });
      return;
    }
    setState(() => _enviando = true);
    try {
      await Nube.recuperarClave(correo);
      _ponerAviso('Si hay una cuenta con ese correo, te llegará un enlace para poner otra contraseña.', malo: false);
    } on AuthException catch (e) {
      _ponerAviso(_traducir(e.message));
    } catch (_) {
      _ponerAviso('No se pudo conectar. Comprueba la conexión.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _ponerAviso(String texto, {bool malo = true}) {
    if (!mounted) return;
    setState(() {
      _aviso = texto;
      _avisoMalo = malo;
    });
  }

  Future<void> _enviar() async {
    final correo = _correo.text.trim();
    if (!correo.contains('@') || _clave.text.length < 6) {
      setState(() {
        _aviso = 'Escribe un correo válido y una contraseña de al menos 6 caracteres.';
        _avisoMalo = true;
      });
      return;
    }
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_nueva) {
        final r = await auth.signUp(email: correo, password: _clave.text);
        if (r.session == null && mounted) {
          setState(() {
            _aviso = 'Te hemos enviado un correo para confirmar la cuenta. Después, entra.';
            _avisoMalo = false;
            _nueva = false;
          });
        }
      } else {
        await auth.signInWithPassword(email: correo, password: _clave.text);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _aviso = _traducir(e.message);
          _avisoMalo = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aviso = 'No se pudo conectar. Comprueba la conexión.';
          _avisoMalo = true;
        });
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _traducir(String m) {
    final t = m.toLowerCase();
    if (t.contains('invalid login')) return 'Correo o contraseña incorrectos.';
    if (t.contains('already registered')) return 'Ya hay una cuenta con ese correo.';
    if (t.contains('not confirmed')) return 'Confirma primero el correo que te hemos enviado.';
    if (t.contains('rate limit')) return 'Demasiados intentos. Espera un poco.';
    return m;
  }

  @override
  Widget build(BuildContext context) => _Marco(
    children: [
      if (Nube.invitacion != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'Te han invitado a una empresa. Entra o crea tu cuenta para unirte.',
            textAlign: TextAlign.center,
            style: TextStyle(color: P.texto, fontSize: 13.5, height: 1.4),
          ),
        ),
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
        obscureText: true,
        autofillHints: [_nueva ? AutofillHints.newPassword : AutofillHints.password],
        onSubmitted: (_) => _enviando ? null : _enviar(),
        decoration: const InputDecoration(hintText: 'Contraseña'),
      ),
      SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(_aviso ?? '', style: TextStyle(color: _avisoMalo ? P.rojo : P.verde, fontSize: 13)),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: _enviando
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : BotonPrimario(
                _nueva ? 'Crear cuenta' : 'Entrar',
                icono: Icons.arrow_forward_rounded,
                conIcono: true,
                onPressed: _enviar,
              ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _enviando ? null : () => setState(() => _nueva = !_nueva),
        child: Text(_nueva ? 'Ya tengo cuenta' : 'Crear una cuenta'),
      ),
      if (!_nueva) TextButton(onPressed: _enviando ? null : _recuperar, child: const Text('¿Olvidaste la contraseña?')),
    ],
  );
}
