import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ajustes_dialogo.dart';
import 'cuenta.dart';
import '../marca.dart';

String? _correo() => Supabase.instance.client.auth.currentUser?.email;

/// Letras del avatar de la barra: las del correo con sesión, "YO" en el modo de pruebas.
String inicialesCuenta() => store.nube == null ? 'YO' : inicialesDe((_correo() ?? '?').split('@').first);

/// «Empresa · Rol» de la sesión.
String _empresaYRol() {
  final nube = store.nube!;
  return '${nube.nombre} · ${nube.esAdmin ? 'Administrador' : m('Trabajador')}';
}

/// Posición de un menú junto al widget de [context] (encima o debajo, según quepa).
RelativeRect _junto(BuildContext context) {
  final fila = context.findRenderObject() as RenderBox;
  final lienzo = Overlay.of(context).context.findRenderObject() as RenderBox;
  return RelativeRect.fromRect(
    Rect.fromPoints(
      fila.localToGlobal(Offset.zero, ancestor: lienzo),
      fila.localToGlobal(fila.size.bottomRight(Offset.zero), ancestor: lienzo),
    ),
    Offset.zero & lienzo.size,
  );
}

ShapeBorder get _forma => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(P.radio),
  side: BorderSide(color: P.borde),
);

PopupMenuItem<String> _opcion(String valor, String texto, {Color? color}) => PopupMenuItem<String>(
  value: valor,
  child: Text(texto, style: TextStyle(color: color ?? P.texto, fontSize: 13.5)),
);

/// Menú del usuario (abajo de la barra, como en ChatGPT): quién eres, Ajustes (con tu cuenta dentro) y
/// cerrar sesión. Sin sesión (modo de pruebas), abre los Ajustes.
Future<void> abrirMenuUsuario(BuildContext context) async {
  if (store.nube == null) return abrirAjustes(context);
  final elegido = await showMenu<String>(
    context: context,
    position: _junto(context),
    color: P.superficie,
    shape: _forma,
    items: [
      PopupMenuItem<String>(
        enabled: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _correo() ?? '',
              style: TextStyle(color: P.texto, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(_empresaYRol(), style: TextStyle(color: P.textoSuave, fontSize: 12.5)),
          ],
        ),
      ),
      const PopupMenuDivider(),
      _opcion('ajustes', 'Ajustes'),
      _opcion('salir', 'Cerrar sesión', color: P.rojo),
    ],
  );
  if (!context.mounted) return;
  switch (elegido) {
    case 'ajustes':
      await abrirAjustes(context);
    case 'salir':
      await Nube.cerrarSesion();
  }
}

/// Menú de empresas: todas las de la cuenta para cambiar de una a otra, un lápiz en cada una para editar sus datos
/// (si eres administrador) y, abajo, «Crear empresa».
Future<void> abrirSelectorEmpresa(BuildContext context, {List<EmpresaDeCuenta>? empresas}) async {
  final nube = store.nube;
  if (nube == null) return;
  // Si falla la red, el menú sale con la empresa abierta y «Crear empresa».
  final todas =
      empresas ??
      await Nube.empresas().catchError(
        (_) => <EmpresaDeCuenta>[
          (id: nube.empresaId, nombre: nube.nombre, rol: nube.rol, icono: 'otro', color: P.morado),
        ],
      );
  if (!context.mounted) return;
  final elegido = await showMenu<String>(
    context: context,
    position: _junto(context),
    color: P.superficie,
    shape: _forma,
    constraints: const BoxConstraints(minWidth: 260, maxWidth: 340),
    items: [
      for (final e in todas)
        PopupMenuItem<String>(
          value: 'ir:${e.id}',
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Builder(
            builder: (c) => Row(
              children: [
                IconoCuadro(iconosTipo[e.icono]!, e.color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: P.texto,
                      fontSize: 13.5,
                      fontWeight: e.id == nube.empresaId ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (e.rol == 'admin')
                  IconButton(
                    tooltip: 'Editar ${e.nombre}',
                    onPressed: () => Navigator.pop(c, 'editar:${e.id}'),
                    icon: Icon(Icons.edit_outlined, size: 17, color: P.textoSuave),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),
        ),
      const PopupMenuDivider(),
      _opcion('nueva', 'Crear empresa', color: P.morado),
    ],
  );
  if (!context.mounted) return;
  switch (elegido) {
    case final String ir when ir.startsWith('ir:'):
      if (ir.substring(3) != nube.empresaId) await Nube.entrarEn(ir.substring(3));
    case final String editar when editar.startsWith('editar:'):
      await abrirEmpresa(context, editar.substring(7));
    case 'nueva':
      await abrirNuevaEmpresa(context);
  }
}

/// Selector de empresa, arriba de la barra lateral: icono y nombre de la empresa abierta con un chevron.
/// Con la barra en solo iconos, solo el icono.
class SelectorEmpresa extends StatefulWidget {
  final bool compacto;
  final double escala;
  const SelectorEmpresa({super.key, this.compacto = false, this.escala = 1});

  @override
  State<SelectorEmpresa> createState() => _SelectorEmpresaState();
}

class _SelectorEmpresaState extends State<SelectorEmpresa> {
  List<EmpresaDeCuenta>? _empresas;

  @override
  void initState() {
    super.initState();
    Nube.empresas().then((e) {
      if (mounted) setState(() => _empresas = e);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final nube = store.nube!;
    final abierta = _empresas?.where((e) => e.id == nube.empresaId).firstOrNull;
    final icono = IconoCuadro(
      iconosTipo[abierta?.icono ?? Nube.iconoEmpresa('', nube.tipo)]!,
      abierta?.color ?? P.morado,
      size: 28 * widget.escala,
    );
    return Tooltip(
      message: widget.compacto ? '${nube.nombre} · Cambiar de empresa' : 'Cambiar de empresa',
      child: InkWell(
        borderRadius: BorderRadius.circular(P.radioControl),
        mouseCursor: SystemMouseCursors.click,
        onTap: () => abrirSelectorEmpresa(context, empresas: _empresas),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.compacto ? 0 : 6, vertical: 6),
          child: widget.compacto
              ? Center(child: icono)
              : Row(
                  children: [
                    icono,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nube.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5 * widget.escala, fontWeight: FontWeight.w600, color: P.texto),
                      ),
                    ),
                    Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Botón del usuario, abajo de la barra lateral: avatar, correo y «empresa · rol». Abre [abrirMenuUsuario].
class BotonUsuario extends StatelessWidget {
  final bool compacto;
  final double escala;
  const BotonUsuario({super.key, this.compacto = false, this.escala = 1});

  @override
  Widget build(BuildContext context) {
    final avatar = Avatar(inicialesCuenta(), P.tinta, size: 28 * escala, cuadrado: true);
    return Tooltip(
      message: store.nube == null ? 'Ajustes' : 'Tu cuenta y ajustes',
      child: InkWell(
        borderRadius: BorderRadius.circular(P.radioControl),
        mouseCursor: SystemMouseCursors.click,
        onTap: () => abrirMenuUsuario(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compacto ? 0 : 6, vertical: 6),
          child: compacto
              ? Center(child: avatar)
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.nube == null ? 'Modo de pruebas' : (_correo() ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5 * escala, fontWeight: FontWeight.w600, color: P.texto),
                          ),
                          Text(
                            store.nube == null ? 'Ajustes' : _empresaYRol(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12 * escala, color: P.textoSuave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
