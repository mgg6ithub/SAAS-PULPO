import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../nube.dart';
import '../store.dart';
import '../theme.dart';
import 'ajustes_dialogo.dart';
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
            Text('${store.nube!.nombre} · Administrador', style: TextStyle(color: P.textoSuave, fontSize: 12.5)),
          ],
        ),
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
    case 'ajustes':
      await abrirAjustes(context);
    case 'invitar':
      await invitarAdministrador(context);
    case 'salir':
      await Nube.cerrarSesion();
  }
}
