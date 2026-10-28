import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import 'ajustes_dialogo.dart';
import 'cuenta.dart';
import 'invitar.dart';

String? _correo() => Supabase.instance.client.auth.currentUser?.email;

/// Letras del avatar de la barra: las del correo con sesión, "YO" en el modo de pruebas.
String inicialesCuenta() => store.nube == null ? 'YO' : inicialesDe((_correo() ?? '?').split('@').first);

/// Menú de la cuenta, sobre la fila «Mi cuenta» de la barra: quién eres, de qué empresa y cerrar sesión.
Future<void> abrirMiCuenta(BuildContext context) async {
  if (store.nube == null) return abrirAjustes(context);
  final fila = context.findRenderObject() as RenderBox;
  final lienzo = Overlay.of(context).context.findRenderObject() as RenderBox;
  final posicion = RelativeRect.fromRect(
    Rect.fromPoints(
      fila.localToGlobal(Offset.zero, ancestor: lienzo),
      fila.localToGlobal(fila.size.bottomRight(Offset.zero), ancestor: lienzo),
    ),
    Offset.zero & lienzo.size,
  );
  final nube = store.nube!;
  // Las otras empresas de la cuenta, para cambiar de una a otra (si falla la red, el menú sale sin ellas).
  final otras = (await Nube.empresas().catchError((_) => <({String id, String nombre, String rol})>[]))
      .where((e) => e.id != nube.empresaId)
      .toList();
  if (!context.mounted) return;
  final elegido = await showMenu<String>(
    context: context,
    position: posicion,
    color: P.superficie,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(P.radio),
      side: BorderSide(color: P.borde),
    ),
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
            Text(
              '${nube.nombre} · ${nube.esAdmin ? 'Administrador' : 'Trabajador'}',
              style: TextStyle(color: P.textoSuave, fontSize: 12.5),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'cuenta',
        child: Text('Tu cuenta', style: TextStyle(color: P.texto, fontSize: 13.5)),
      ),
      if (nube.esAdmin)
        PopupMenuItem<String>(
          value: 'empresa',
          child: Text('Datos de la empresa', style: TextStyle(color: P.texto, fontSize: 13.5)),
        ),
      for (final e in otras)
        PopupMenuItem<String>(
          value: 'ir:${e.id}',
          child: Text('Cambiar a ${e.nombre}', style: TextStyle(color: P.texto, fontSize: 13.5)),
        ),
      PopupMenuItem<String>(
        value: 'nueva',
        child: Text('Crear otra empresa', style: TextStyle(color: P.texto, fontSize: 13.5)),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'ajustes',
        child: Text('Ajustes', style: TextStyle(color: P.texto, fontSize: 13.5)),
      ),
      PopupMenuItem<String>(
        value: 'invitar',
        child: Text('Invitar a un socio', style: TextStyle(color: P.texto, fontSize: 13.5)),
      ),
      PopupMenuItem<String>(
        value: 'salir',
        child: Text('Cerrar sesión', style: TextStyle(color: P.rojo, fontSize: 13.5)),
      ),
    ],
  );
  if (!context.mounted) return;
  switch (elegido) {
    case 'cuenta':
      await abrirCuenta(context);
    case 'empresa':
      await abrirEmpresa(context);
    case 'nueva':
      await abrirNuevaEmpresa(context);
    case final String ir when ir.startsWith('ir:'):
      await Nube.entrarEn(ir.substring(3));
    case 'ajustes':
      await abrirAjustes(context);
    case 'invitar':
      await invitarAdministrador(context);
    case 'salir':
      await Nube.cerrarSesion();
  }
}
