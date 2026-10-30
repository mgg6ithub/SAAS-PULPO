import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../forms.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'accesos.dart';
import 'invitar.dart';
import '../marca.dart';

/// Ventanas de la cuenta (DEV-018): perfil, correo, contraseña, sesiones y borrar la cuenta; datos de la empresa,
/// crear otra y borrarla.

Future<void> abrirCuenta(BuildContext context) => abrirPanel(context, const CuentaForm());

/// Datos de una empresa de la cuenta (la abierta si no se dice cuál).
Future<void> abrirEmpresa(BuildContext context, [String? id]) => abrirPanel(context, EmpresaForm(id: id));

Future<void> abrirNuevaEmpresa(BuildContext context) => abrirPanel(context, const EmpresaForm(nueva: true));

void _avisar(BuildContext context, String texto) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(texto)));

String _error(Object e) => switch (e) {
  AuthException(:final message) when message.toLowerCase().contains('different from the old') =>
    'La contraseña nueva tiene que ser distinta de la de ahora.',
  AuthException(:final message) when message.toLowerCase().contains('rate limit') =>
    'Demasiados intentos. Espera un poco.',
  AuthException(:final message) => message,
  _ => 'No se pudo conectar. Comprueba la conexión.',
};

class CuentaForm extends StatefulWidget {
  const CuentaForm({super.key});

  @override
  State<CuentaForm> createState() => _CuentaFormState();
}

class _CuentaFormState extends State<CuentaForm> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  String _foto = '';
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    Nube.refrescarCuenta().then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
    Nube.perfil().then((p) {
      if (!mounted) return;
      setState(() {
        _nombre.text = p.nombre;
        _foto = p.foto ?? '';
        _cargado = true;
      });
    }, onError: (_) => mounted ? setState(() => _cargado = true) : null);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    try {
      await Nube.guardarPerfil(nombre: _nombre.text.trim(), foto: _foto.isEmpty ? null : _foto);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _avisar(context, 'No se pudo guardar: ${_error(e)}');
    }
  }

  Future<void> _cambiarCorreo() async {
    final nuevo = _correo.text.trim();
    if (!nuevo.contains('@')) return _avisar(context, 'Escribe el correo nuevo.');
    try {
      await Nube.cambiarCorreo(nuevo);
      _correo.clear();
      if (mounted) {
        setState(() {});
        _avisar(context, 'Te hemos mandado un enlace a $nuevo y otro a ${Nube.correo}: pulsa los dos.');
      }
    } catch (e) {
      if (mounted) _avisar(context, _error(e));
    }
  }

  /// Supabase pide confirmar el cambio en los dos correos (el de ahora y el nuevo).
  static const _textoCorreo =
      'Te llegará un enlace al correo nuevo y otro al de ahora; el cambio vale al pulsar los dos.';

  Future<void> _cerrarEnTodos() async {
    if (!await _confirmarAccion(
      context,
      'Cerrar sesión en todos los dispositivos',
      'Tendrás que volver a entrar en todos, también en este.',
      'Cerrar sesión',
    )) {
      return;
    }
    if (mounted) Navigator.pop(context);
    await Nube.cerrarSesion(enTodos: true);
  }

  Future<void> _borrarCuenta() async {
    if (!await confirmarEscribiendo(
      context,
      titulo: 'Borrar tu cuenta',
      texto:
          'Se borra tu cuenta y las empresas donde eres la única persona, con todos sus datos. '
          'En las demás, solo dejas de estar. No se puede deshacer.',
      palabra: 'BORRAR',
    )) {
      return;
    }
    try {
      await Nube.borrarCuenta();
      if (mounted) Navigator.pop(context);
    } on UltimoAdministrador {
      if (mounted) {
        _avisar(context, 'Eres el único administrador de una empresa con más gente: nombra a otro antes de irte.');
      }
    } catch (e) {
      if (mounted) _avisar(context, 'No se pudo borrar la cuenta: ${_error(e)}');
    }
  }

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'CUENTA',
    titulo: _nombre.text.trim().isEmpty ? 'Tu cuenta' : _nombre.text.trim(),
    subtitulo: Nube.correo,
    lider: FotoFormulario(foto: _foto, onCambio: (f) => setState(() => _foto = f)),
    onGuardar: _guardar,
    campos: [
      Bloque('Perfil', descripcion: 'Tu nombre sale en las invitaciones y en los emails.', primero: true, [
        if (_cargado) campo('Nombre', _nombre, hint: 'Nombre y apellido') else const LinearProgressIndicator(),
      ]),
      Bloque('Correo', descripcion: _textoCorreo, [
        if (Nube.correoPendiente case final pendiente?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Pendiente: $pendiente. Confirma el enlace en los dos correos.',
              style: TextStyle(fontSize: 13.5, color: P.ambar, fontWeight: FontWeight.w600),
            ),
          ),
        campo('Correo nuevo', _correo, hint: Nube.correo),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(onPressed: _cambiarCorreo, child: const Text('Cambiar correo')),
        ),
      ]),
      Bloque('Seguridad', descripcion: 'Tu contraseña y dónde tienes la sesión abierta.', [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: () => cambiarClave(context), child: const Text('Cambiar contraseña')),
            OutlinedButton(onPressed: _cerrarEnTodos, child: const Text('Cerrar sesión en todos los dispositivos')),
          ],
        ),
      ]),
      Bloque('Borrar la cuenta', descripcion: 'Para irte de Pultec del todo.', [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: P.rojo),
            onPressed: _borrarCuenta,
            child: const Text('Borrar mi cuenta'),
          ),
        ),
      ]),
    ],
  );
}

/// Datos de una empresa de la cuenta ([id], o la abierta) o, con [nueva], una empresa más. La abierta, además,
/// invitar a un socio y sus accesos.
class EmpresaForm extends StatefulWidget {
  final bool nueva;
  final String? id;
  const EmpresaForm({super.key, this.nueva = false, this.id});

  @override
  State<EmpresaForm> createState() => _EmpresaFormState();
}

class _EmpresaFormState extends State<EmpresaForm> {
  final _nombre = TextEditingController();
  final _cif = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _claveNombre = GlobalKey();
  String _tipo = 'Varios';
  String _logo = '';
  String _icono = '';
  int _color = 0;
  bool _intento = false, _cargado = false;

  String get _id => widget.id ?? store.nube!.empresaId;
  bool get _abierta => _id == store.nube!.empresaId;

  @override
  void initState() {
    super.initState();
    _nombre.addListener(() => setState(() {}));
    if (widget.nueva) {
      _cargado = true;
      return;
    }
    Nube.datosEmpresa(_id).then((d) {
      if (!mounted) return;
      setState(() {
        _nombre.text = d['nombre'] as String;
        _cif.text = d['cif'] as String;
        _direccion.text = d['direccion'] as String;
        _telefono.text = d['telefono'] as String;
        _logo = d['logo'] as String? ?? '';
        _icono = d['icono'] as String? ?? '';
        _color = d['color'] as int? ?? 0;
        if (Nube.tiposEmpresa.containsKey(d['tipo'])) _tipo = d['tipo'] as String;
        _cargado = true;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_nombre, _cif, _direccion, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _faltaNombre => _nombre.text.trim().isEmpty;

  void _irAlNombre() => Scrollable.ensureVisible(
    _claveNombre.currentContext!,
    duration: const Duration(milliseconds: 350),
    alignment: .2,
  );

  Future<void> _guardar() async {
    setState(() => _intento = true);
    if (_faltaNombre) return _irAlNombre();
    try {
      if (widget.nueva) {
        await Nube.crearEmpresa(_nombre.text.trim(), _tipo);
      } else {
        await Nube.guardarEmpresa(_id, {
          'nombre': _nombre.text.trim(),
          'tipo': _tipo,
          'cif': _cif.text.trim(),
          'direccion': _direccion.text.trim(),
          'telefono': _telefono.text.trim(),
          'logo': _logo.isEmpty ? null : _logo,
          'icono': _icono,
          'color': _color,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _avisar(context, 'No se pudo guardar: ${_error(e)}');
    }
  }

  Future<void> _borrar() async {
    final nombre = store.nube!.nombre;
    if (!await confirmarEscribiendo(
      context,
      titulo: 'Borrar $nombre',
      texto: m('Se borran sus clientes, trabajadores, trabajos y accesos, para todas las personas de la empresa.'),
      palabra: nombre,
    )) {
      return;
    }
    try {
      await store.nube!.borrarEmpresa();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _avisar(context, 'No se pudo borrar: ${_error(e)}');
    }
  }

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'EMPRESAS',
    titulo: widget.nueva ? 'Nueva empresa' : (_faltaNombre ? 'Tu empresa' : _nombre.text.trim()),
    subtitulo: widget.nueva ? m('Con sus propios clientes, trabajadores y trabajos.') : null,
    lider: widget.nueva
        ? null
        : FotoFormulario(foto: _logo, cuadrado: true, onCambio: (f) => setState(() => _logo = f)),
    onGuardar: _guardar,
    onBorrar: widget.nueva || !_abierta ? null : _borrar,
    avisos: [if (_intento && _faltaNombre) ('Te falta el nombre', _irAlNombre)],
    campos: [
      Bloque('Empresa', descripcion: 'Cómo se llama y a qué se dedica.', primero: true, [
        if (!_cargado)
          const LinearProgressIndicator()
        else ...[
          KeyedSubtree(
            key: _claveNombre,
            child: campo(
              'Nombre',
              _nombre,
              hint: 'Ascensores Altura',
              obligatorio: true,
              error: _intento && _faltaNombre ? 'Ponle un nombre' : null,
            ),
          ),
          etiqueta(widget.nueva ? 'A qué se dedica (decide las plantillas con las que empieza)' : 'A qué se dedica'),
          conMargen(
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _tipo,
              items: [for (final t in Nube.tiposEmpresa.keys) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (t) => setState(() => _tipo = t!),
            ),
          ),
        ],
      ]),
      if (!widget.nueva && _cargado)
        Bloque('Datos fiscales y contacto', descripcion: 'Para los partes, las facturas y los emails.', [
          dos(campo('CIF', _cif), campo('Teléfono', _telefono)),
          campo('Dirección', _direccion, hint: 'Calle, número, ciudad'),
        ]),
      if (!widget.nueva && _cargado)
        Bloque('Icono y color', descripcion: 'Para distinguirla en el selector de empresas.', [_iconoYColor()]),
      if (!widget.nueva && _cargado && _abierta && store.nube!.esAdmin) ...[
        Bloque('Invitar a un socio', descripcion: 'Un enlace de un solo uso: verá y gestionará toda la empresa.', [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: () => invitarAdministrador(context), child: const Text('Crear enlace')),
          ),
        ]),
        Bloque('Accesos', descripcion: 'Quién entra en la empresa y con qué rol.', [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: () => abrirAccesos(context), child: const Text('Ver accesos')),
          ),
        ]),
      ],
      if (!widget.nueva && _cargado && !_abierta)
        Bloque('Socios y accesos', descripcion: 'Se gestionan con la empresa abierta.', [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Nube.entrarEn(_id);
              },
              child: const Text('Cambiar a esta empresa'),
            ),
          ),
        ]),
    ],
  );

  /// Iconos de [iconosTipo] en el color elegido y, debajo, los colores de la paleta.
  Widget _iconoYColor() {
    final color = Nube.colorEmpresa(_color);
    final icono = Nube.iconoEmpresa(_icono, _tipo);
    Widget opcion({required bool sel, required VoidCallback onTap, required String tooltip, required Widget child}) =>
        Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(P.radioControl),
            mouseCursor: SystemMouseCursors.click,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(P.radioControl),
                border: Border.all(color: sel ? color : Colors.transparent, width: 1.5),
              ),
              child: child,
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final e in iconosTipo.entries)
              opcion(
                sel: e.key == icono,
                tooltip: 'Icono',
                onTap: () => setState(() => _icono = e.key),
                child: IconoCuadro(e.value, color, size: 34),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final c in [P.morado, ...paleta])
              opcion(
                sel: c.toARGB32() == color.toARGB32(),
                tooltip: 'Color',
                onTap: () => setState(() => _color = c == P.morado ? 0 : c.toARGB32()),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Contraseña nueva, dos veces. Con [recuperando] viene del enlace de «olvidé mi contraseña».
Future<void> cambiarClave(BuildContext context, {bool recuperando = false}) => showDialog<void>(
  context: context,
  barrierDismissible: !recuperando,
  builder: (_) => _Dialogo(child: _ClaveNueva(recuperando: recuperando)),
);

class _ClaveNueva extends StatefulWidget {
  final bool recuperando;
  const _ClaveNueva({required this.recuperando});

  @override
  State<_ClaveNueva> createState() => _ClaveNuevaState();
}

class _ClaveNuevaState extends State<_ClaveNueva> {
  final _una = TextEditingController(), _otra = TextEditingController();
  String? _aviso;
  bool _enviando = false;

  @override
  void dispose() {
    _una.dispose();
    _otra.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_una.text.length < 6) return setState(() => _aviso = 'Al menos 6 caracteres.');
    if (_una.text != _otra.text) return setState(() => _aviso = 'Las dos no coinciden.');
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      await Nube.cambiarClave(_una.text);
      if (!mounted) return;
      Navigator.pop(context);
      _avisar(context, 'Contraseña cambiada.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _aviso = _error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.recuperando ? 'Pon una contraseña nueva' : 'Cambiar contraseña',
        style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _una,
        obscureText: true,
        autofocus: true,
        autofillHints: const [AutofillHints.newPassword],
        decoration: const InputDecoration(hintText: 'Contraseña nueva'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _otra,
        obscureText: true,
        autofillHints: const [AutofillHints.newPassword],
        onSubmitted: (_) => _enviando ? null : _guardar(),
        decoration: const InputDecoration(hintText: 'Repítela'),
      ),
      SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(_aviso ?? '', style: const TextStyle(color: P.rojo, fontSize: 13)),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!widget.recuperando) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _enviando ? null : _guardar, child: const Text('Guardar')),
        ],
      ),
    ],
  );
}

/// Primer arranque de una cuenta sin empresa (DEV-019): se le ha creado una y aquí le pone nombre. Con
/// [porGoogle] además se explica que se ha creado, por si esperaba unirse a la de otra persona.
Future<void> nombrarEmpresa(BuildContext context, {bool porGoogle = false}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _Dialogo(child: _NombrarEmpresa(porGoogle: porGoogle)),
);

class _NombrarEmpresa extends StatefulWidget {
  final bool porGoogle;
  const _NombrarEmpresa({required this.porGoogle});

  @override
  State<_NombrarEmpresa> createState() => _NombrarEmpresaState();
}

class _NombrarEmpresaState extends State<_NombrarEmpresa> {
  final _nombre = TextEditingController();
  String? _aviso;
  bool _enviando = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return setState(() => _aviso = 'Ponle un nombre (luego se puede cambiar).');
    setState(() => _enviando = true);
    try {
      final nube = store.nube!;
      Navigator.pop(context);
      await Nube.guardarEmpresa(nube.empresaId, {'nombre': nombre});
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _aviso = _error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '¿Cómo se llama tu empresa?',
        style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        widget.porGoogle
            ? 'Hemos creado una empresa nueva para tu cuenta. Si querías unirte a la de otra persona, '
                  'pídele un enlace de invitación.'
            : 'Sale en la barra, en los partes y en los emails. Podrás cambiarlo en Mi cuenta.',
        style: TextStyle(color: P.textoSuave, height: 1.4),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _nombre,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _enviando ? null : _guardar(),
        decoration: const InputDecoration(hintText: 'Ascensores Altura'),
      ),
      SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(_aviso ?? '', style: const TextStyle(color: P.rojo, fontSize: 13)),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ahora no')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _enviando ? null : _guardar, child: const Text('Empezar')),
        ],
      ),
    ],
  );
}

/// Confirmación fuerte: solo se puede aceptar escribiendo [palabra] (el nombre de la empresa, «BORRAR»…).
Future<bool> confirmarEscribiendo(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String palabra,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _Dialogo(
        child: _Escribir(titulo: titulo, texto: texto, palabra: palabra),
      ),
    ) ??
    false;

class _Escribir extends StatefulWidget {
  final String titulo, texto, palabra;
  const _Escribir({required this.titulo, required this.texto, required this.palabra});

  @override
  State<_Escribir> createState() => _EscribirState();
}

class _EscribirState extends State<_Escribir> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _vale => _c.text.trim() == widget.palabra;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.titulo,
        style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(widget.texto, style: TextStyle(color: P.textoSuave, height: 1.4)),
      const SizedBox(height: 16),
      etiqueta('Escribe «${widget.palabra}» para confirmar'),
      TextField(
        controller: _c,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _vale ? Navigator.pop(context, true) : null,
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: P.rojo),
            onPressed: _vale ? () => Navigator.pop(context, true) : null,
            child: const Text('Borrar'),
          ),
        ],
      ),
    ],
  );
}

Future<bool> _confirmarAccion(BuildContext context, String titulo, String texto, String boton) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => _Dialogo(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(texto, style: TextStyle(color: P.textoSuave, height: 1.4)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(boton)),
              ],
            ),
          ],
        ),
      ),
    ) ??
    false;

class _Dialogo extends StatelessWidget {
  final Widget child;
  const _Dialogo({required this.child});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: P.superficie,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(P.radio),
      side: BorderSide(color: P.borde),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}
