import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'ajustes.dart';
import 'columnas.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'marca.dart';

class Avatar extends StatelessWidget {
  final String texto;
  final Color color;
  final double size;
  final bool bordeBlanco;

  /// Cuadrado redondeado con las iniciales, como los contactos de Holded.
  final bool cuadrado;
  const Avatar(this.texto, this.color, {super.key, this.size = 40, this.bordeBlanco = false, this.cuadrado = false});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      shape: cuadrado ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: cuadrado ? BorderRadius.circular(size * .22) : null,
      border: bordeBlanco ? Border.all(color: P.superficie, width: 2) : null,
    ),
    child: Text(
      texto,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * .38, letterSpacing: -.2),
    ),
  );
}

/// Etiqueta de color. Suave por defecto; [solido] para estados (como "Pagado" en Holded).
/// [icono] se ignora a propósito: regla de "cuantos menos iconos, mejor".
class Pill extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;
  final bool punto;
  final bool solido;
  const Pill(this.texto, this.color, {super.key, this.icono, this.punto = false, this.solido = false});

  @override
  Widget build(BuildContext context) {
    // Texto algo más oscuro que el color (más legible y menos «chillón»); en oscuro, algo más claro.
    final fg = solido
        ? Colors.white
        : Color.lerp(color, ajustes.oscuro ? Colors.white : Colors.black, ajustes.oscuro ? .25 : .18)!;
    // Insignia rectangular con borde fino (no cápsula), como en los paneles profesionales.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: solido ? 3 : 2),
      decoration: BoxDecoration(
        color: solido ? color : color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
        border: solido ? null : Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: fg),
            const SizedBox(width: 5),
          ] else if (punto) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: solido ? fg : color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nombre de una fila con la píldora «Nuevo» detrás si se acaba de crear a mano ([Store.esNuevo]).
Widget conNuevo(String id, Widget nombre) => !store.esNuevo(id)
    ? nombre
    : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: nombre),
          const SizedBox(width: 8),
          Pill('Nuevo', P.morado),
        ],
      );

/// Píldora gris con un punto de color delante: "● Caldera". Para categorías.
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const Etiqueta(this.texto, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: P.borde),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: P.texto),
          ),
        ),
      ],
    ),
  );
}

class TipoIcono extends StatelessWidget {
  final String tipo;
  final double size;
  const TipoIcono(this.tipo, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final t = tipoDe(tipo);
    return IconoCuadro(t.icono, t.color, size: size);
  }
}

/// Barrita vertical del color del tipo de mantenimiento: lo identifica sin necesidad de icono.
class BarraTipo extends StatelessWidget {
  final String tipo;
  final double alto;

  /// Color propio (el elegido en la tarea); si no, el de su tipo.
  final Color? color;
  const BarraTipo(this.tipo, {super.key, this.alto = 28, this.color});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tipo,
    child: Container(
      width: 3,
      height: alto,
      decoration: BoxDecoration(color: color ?? tipoDe(tipo).color, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

/// Icono dentro de un cuadrado tintado, para filas de lista y acciones.
class IconoCuadro extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double size;
  const IconoCuadro(this.icono, this.color, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(size * .24)),
    child: Icon(icono, color: color, size: size * .52),
  );
}

/// Tarjeta blanca de borde fino que se marca al pasar el ratón.
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double? width;
  /// Seleccionada (p. ej. la cifra que filtra la lista): borde morado fijo.
  final bool marcado;

  /// Tarjeta de aviso (p. ej. una orden atrasada): fondo y borde suaves de este color.
  final Color? tinte;
  const HoverCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.width,
    this.marcado = false, this.tinte});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final activo = hover && widget.onTap != null;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: widget.width,
          padding: widget.padding,
          // Como los cuadraditos de la landing: blanco, borde fino y sin sombra; al pasar, el borde se tiñe.
          decoration: BoxDecoration(
            color: widget.tinte == null ? P.superficie : Color.alphaBlend(widget.tinte!.withValues(alpha: .06), P.superficie),
            borderRadius: BorderRadius.circular(P.radio),
            border: Border.all(
              color: widget.marcado
                  ? P.morado
                  : activo
                  ? P.morado.withValues(alpha: .45)
                  : widget.tinte?.withValues(alpha: .35) ?? P.borde,
            ),
            boxShadow: P.sombra,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const Tarjeta({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? P.superficie,
      borderRadius: BorderRadius.circular(P.radio),
      border: Border.all(color: color == null ? P.borde : Colors.transparent),
      boxShadow: color == null ? P.sombra : null,
    ),
    child: child,
  );
}

/// Bloque con título (y enlace a la derecha) y filas separadas por líneas, como los de Inicio en Holded.
class SeccionTarjeta extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  final List<Widget> children;

  /// Sin separadores entre hijos (gráficas, contenido libre).
  final bool sinFilas;

  /// Alto fijo: para que las tarjetas puestas en pareja midan lo mismo. El contenido hace scroll.
  final double? alto;

  /// Icono de color junto al título (el toque Pultec).
  final IconData? icono;
  final Color? colorIcono;
  const SeccionTarjeta({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.accion,
    required this.children,
    this.sinFilas = false,
    this.alto,
    this.icono,
    this.colorIcono,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: alto,
    decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(P.radio), boxShadow: P.sombra),
    // Borde por encima del contenido: si no, las cabeceras lo tapan en las esquinas.
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(P.radio),
      border: Border.all(color: P.borde),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: P.mejorada ? const EdgeInsets.fromLTRB(20, 18, 16, 12) : const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(
            children: [
              // Mejorada: icono de línea junto al título, sin cuadro (como «Acciones pendientes» de la maqueta).
              if (icono != null) ...[
                P.mejorada
                    ? Icon(icono, size: 24, color: colorIcono ?? P.texto)
                    : IconoCuadro(icono!, colorIcono ?? P.morado, size: 30),
                SizedBox(width: P.mejorada ? 12 : 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontFamily: P.titulos,
                        fontSize: P.mejorada ? 18 : 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                    if (subtitulo != null) Text(subtitulo!, style: TextStyle(fontSize: 13, color: P.textoSuave)),
                  ],
                ),
              ),
              ?accion,
            ],
          ),
        ),
        if (!P.mejorada) Divider(height: 1, color: P.borde),
        if (alto == null)
          ..._cuerpo()
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _cuerpo()),
            ),
          ),
      ],
    ),
  );

  List<Widget> _cuerpo() => sinFilas
      ? children
      : [
          for (final (i, c) in children.indexed) ...[if (i > 0) Divider(height: 1, color: P.borde), c],
        ];
}

/// Enlace de texto en el color de acento, como "Ir a Cuentas" de Holded.
class Enlace extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;
  const Enlace(this.texto, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(6),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        texto,
        style: TextStyle(color: P.morado, fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Fila de lista: icono en cuadro tintado, título, subtítulo, algo a la derecha y "›".
class FilaLista extends StatelessWidget {
  /// Lo de delante (icono, avatar…); null = la fila empieza en el texto, alineada con el resto de la tarjeta.
  final Widget? lider;
  final String titulo;
  final String? subtitulo;
  final Widget? derecha;
  final VoidCallback? onTap;
  const FilaLista({super.key, this.lider, required this.titulo, this.subtitulo, this.derecha, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      hoverColor: P.hoverFila,
      // Sin toque propio (dentro de una tarjeta que se pulsa entera): manda el cursor de la tarjeta.
      mouseCursor: onTap == null ? MouseCursor.defer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            if (lider != null) ...[lider!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: P.textoSuave),
                    ),
                ],
              ),
            ),
            if (derecha != null) ...[const SizedBox(width: 12), derecha!],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: P.textoSuave),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Cifra grande con su etiqueta gris encima y, opcionalmente, una nota de color debajo.
class Cifra extends StatelessWidget {
  final String etiqueta;
  final num valor;
  final String? nota;
  final Color? colorNota;
  final Color? color;
  final double tamano;

  /// Punto de color delante de la etiqueta.
  final Color? punto;
  const Cifra(
    this.etiqueta,
    this.valor, {
    super.key,
    this.nota,
    this.colorNota,
    this.color,
    this.tamano = 26,
    this.punto,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (punto != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: P.textoSuave),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: valor.toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text(
          '${v.round()}',
          style: TextStyle(
            fontFamily: P.titulos,
            fontSize: tamano,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: color,
          ),
        ),
      ),
      if (nota != null)
        Text(
          nota!,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorNota ?? P.textoSuave),
        ),
    ],
  );
}

/// Banner oscuro de ancho completo: icono, título, texto y un botón blanco.
class BannerOscuro extends StatelessWidget {
  final IconData icono;
  final String titulo, texto, boton;
  final VoidCallback onPressed;
  final VoidCallback? onCerrar;
  const BannerOscuro({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.onPressed,
    this.onCerrar,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(P.radio), color: P.tinta),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icono, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Text(texto, style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 12.5)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: P.tinta),
          onPressed: onPressed,
          child: Text(boton),
        ),
        if (onCerrar != null)
          IconButton(
            onPressed: onCerrar,
            icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: .7)),
          ),
      ],
    ),
  );
}

/// Título de página grande a la izquierda y acciones a la derecha (un solo botón primario).
class Cabecera extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;
  final Widget? lider;
  final Widget? contenido;
  const Cabecera({super.key, required this.titulo, this.subtitulo, this.acciones = const [], this.lider, this.contenido});

  /// Las acciones se quedan siempre arriba a la derecha; si falta ancho, solo con su icono.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: contenido ?? Row(
            children: [
              if (lider != null) ...[lider!, const SizedBox(width: 12)],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontFamily: P.titulos,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        height: 1.15,
                      ),
                    ),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitulo!, style: TextStyle(color: P.textoSuave, fontSize: 14.5)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (acciones.isNotEmpty) ...[
          const SizedBox(width: 12),
          // Pueden ocupar hasta la mitad; si no caben, bajan de línea (nunca desbordan).
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
            child: _Compacto(
              compacto: box.maxWidth < 560,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: acciones,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Botón primario con la tecla rápida en un recuadro, como "Nuevo contacto  N" de Holded.
class BotonPrimario extends StatelessWidget {
  final String texto;

  /// En Pultec el «+» ya dice que es nuevo: «Nuevo mantenimiento» se queda en «Mantenimiento».
  String get _etiqueta {
    if (!industrial) return texto;
    final m = RegExp(r'^Nuev[oa] (.)').firstMatch(texto);
    return m == null ? texto : m.group(1)!.toUpperCase() + texto.substring(m.end);
  }

  final IconData icono;
  final VoidCallback onPressed;
  final String? tecla;

  /// Muestra el icono delante del texto también en escritorio (por defecto solo se ve en móvil).
  final bool conIcono;

  /// Relleno (null = el morado de siempre); p. ej. rojo para «Crear incidencia».
  final Color? color;
  const BotonPrimario(
    this.texto, {
    super.key,
    this.icono = Icons.add_rounded,
    required this.onPressed,
    this.tecla,
    this.conIcono = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => esMovil(context)
      ? Tooltip(
          message: _etiqueta,
          child: IconButton.filled(
            style: IconButton.styleFrom(
              fixedSize: const Size(40, 40),
              minimumSize: const Size(40, 40),
              backgroundColor: color ?? P.morado,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
            ),
            onPressed: onPressed,
            icon: Icon(icono, size: 20, color: Colors.white),
          ),
        )
      : FilledButton(
          // Texto, «+» y tecla siempre en blanco (en oscuro el tema los ponía oscuros).
          style: FilledButton.styleFrom(
            backgroundColor: color ?? P.morado,
            foregroundColor: Colors.white,
            // Con «+», menos aire a los lados (sobre todo antes del «+»): el botón queda más recogido.
            padding: conIcono ? EdgeInsets.only(left: 10, right: tecla == null ? 13 : 9) : null,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El «+» y el nombre, separados por una raya fina que no llega a los bordes del botón.
              if (conIcono) ...[
                Icon(icono, size: 18),
                const SizedBox(width: 6),
                Container(width: 1, height: 16, color: Colors.white.withValues(alpha: .35)),
                const SizedBox(width: 8),
              ],
              Text(_etiqueta),
              if (tecla != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tecla!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ],
          ),
        );
}

/// Botón de acción de las cabeceras: siempre 40 de alto, borde fino (o relleno de [color]),
/// icono opcional delante y, al pasar el ratón, fondo más oscuro y cursor de mano.
class BotonAccion extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  final IconData? icono;
  final String? tooltip;

  /// Relleno (tinta, morado…); null = blanco con borde.
  final Color? color;

  /// Solo el icono (con [texto] de tooltip) también en escritorio, no solo en el móvil.
  final bool soloIcono;
  const BotonAccion(
    this.texto, {
    super.key,
    required this.onPressed,
    this.icono,
    this.tooltip,
    this.color,
    this.soloIcono = false,
  });

  @override
  Widget build(BuildContext context) {
    final fondo = color ?? P.superficie;
    final hover = color == null ? P.hover : Color.lerp(color, Colors.white, .14)!;
    final style =
        OutlinedButton.styleFrom(
          foregroundColor: color == null ? P.texto : Colors.white,
          padding: EdgeInsets.fromLTRB(icono == null ? 16 : 12, 0, 16, 0),
          side: BorderSide(color: color ?? P.borde),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((e) => e.contains(WidgetState.hovered) ? hover : fondo),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        );
    final soloIcono = icono != null && (this.soloIcono || esMovil(context));
    final boton = SizedBox(
      height: 40,
      width: soloIcono ? 40 : null,
      child: soloIcono
          ? OutlinedButton(
              style: style.copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
              onPressed: onPressed,
              child: Icon(icono, size: 19),
            )
          : icono == null
          ? OutlinedButton(style: style, onPressed: onPressed, child: Text(texto))
          : OutlinedButton.icon(style: style, onPressed: onPressed, icon: Icon(icono, size: 19), label: Text(texto)),
    );
    final mensaje = tooltip ?? (soloIcono ? texto : null);
    return mensaje == null ? boton : Tooltip(message: mensaje, child: boton);
  }
}

/// Importar y exportar (Activos, Técnicos): la flecha de descargar y la misma girada, juntas, sin texto; al lado del
/// botón principal, con el borde de [BotonAccion].
class BotonImportarExportar extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  /// Solo exportar e imprimir (vistas donde no se importa): una sola flecha, la de subir.
  final bool soloExportar;
  const BotonImportarExportar({
    super.key,
    required this.onPressed,
    this.tooltip = 'Importar y exportar',
    this.soloExportar = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox(
      height: 40,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: P.texto,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(40, 40),
          side: BorderSide(color: P.borde),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (e) => e.contains(WidgetState.hovered) ? P.hover : P.superficie,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
        onPressed: onPressed,
        // Flecha redondeada, algo más pequeña y en gris suave, para que no pese junto al principal.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!soloExportar) ...[
              Icon(Icons.download_rounded, size: 17, color: P.textoSuave),
              const SizedBox(width: 3),
            ],
            // La misma flecha, girada 180 grados.
            RotatedBox(quarterTurns: 2, child: Icon(Icons.download_rounded, size: 17, color: P.textoSuave)),
          ],
        ),
      ),
    ),
  );
}

class Buscador extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  /// Al final del campo, dentro de él (p. ej. el filtro por grupo de Técnicos).
  final Widget? sufijo;
  const Buscador({super.key, required this.hint, required this.onChanged, this.width = 240, this.sufijo});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 40,
    child: TextField(
      onChanged: onChanged,
      // Clic fuera del buscador = deja de escribir (en web con ratón no lo hace solo), así vuelven los atajos.
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      // Ocupa los 40 de alto, como los botones de al lado.
      maxLines: 1,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        constraints: const BoxConstraints.tightFor(height: 40),
        isDense: true,
        hintText: hint,
        hintMaxLines: 1,
        hintStyle: TextStyle(color: P.textoSuave, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        // Lupa y una raya vertical fina que la separa del texto.
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 10, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 18, color: P.textoSuave),
              const SizedBox(width: 8),
              Container(width: 1, height: 18, color: P.borde),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        suffixIcon: sufijo,
        suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      ),
    ),
  );
}

/// Ventana estrecha (móvil, tablet en vertical, media pantalla pequeña): los botones con icono
/// se quedan solo en el icono.
/// También dentro de una [BarraVista] que se ha quedado sin sitio para su principal (`principalCompactoBajo`).
bool esMovil(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 700 ||
    (context.dependOnInheritedWidgetOfExactType<_Compacto>()?.compacto ?? false);

/// Marca para [esMovil]: lo de debajo se dibuja compacto (solo iconos).
class _Compacto extends InheritedWidget {
  final bool compacto;
  const _Compacto({required this.compacto, required super.child});

  @override
  bool updateShouldNotify(_Compacto old) => old.compacto != compacto;
}

/// Barra única de arriba de cada vista (como la del Itinerario): a la izquierda título y filtros; a la
/// derecha buscador y acciones, todo de 40 de alto. [principal] (Nuevo cliente, Nuevo trabajo…) va
/// siempre arriba a la derecha, junto al título, mientras quepa. Si la ventana se estrecha, filtros y
/// buscador bajan a otra fila; un grupo más ancho que la pantalla se desplaza.
class BarraVista extends StatelessWidget {
  final List<Widget> izquierda, derecha;
  final Widget? principal;

  /// Con la barra más estrecha que esto, la principal se dibuja compacta (solo iconos) aunque la ventana no
  /// sea de móvil: p. ej. el Itinerario, con varios botones junto a la fecha.
  final double? principalCompactoBajo;
  const BarraVista({
    super.key,
    required this.izquierda,
    required this.derecha,
    this.principal,
    this.principalCompactoBajo,
  });

  /// Grupo de controles: si no cabe en su fila, baja en varias; uno solo más ancho que la fila se desplaza.
  Widget _grupo(Iterable<Widget> ws, double hueco) => ws.isEmpty
      ? const SizedBox.shrink()
      : Wrap(
          spacing: hueco,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [for (final w in ws) SingleChildScrollView(scrollDirection: Axis.horizontal, child: w)],
        );

  List<Widget> _hijos(Widget? principal) => [
    // El título sin desplazamiento: así puede acortarse ([TextoAjustable]) con el ancho que le quede.
    izquierda.isEmpty ? const SizedBox.shrink() : izquierda.first,
    _grupo(izquierda.skip(1), 14),
    _grupo(derecha, 8),
    principal ?? const SizedBox.shrink(),
  ];

  @override
  Widget build(BuildContext context) => principalCompactoBajo == null || principal == null
      ? _Barra(children: _hijos(principal))
      // Solo se reconstruye al cruzar el umbral.
      : SegunTamano(
          clave: (box) => box.maxWidth < principalCompactoBajo!,
          builder: (context, box) => _Barra(
            children: _hijos(_Compacto(compacto: box.maxWidth < principalCompactoBajo!, child: principal!)),
          ),
        );
}

/// Colocación de la [BarraVista]: hijos 0 título, 1 filtros, 2 derecha, 3 principal.
class _Barra extends MultiChildRenderObjectWidget {
  const _Barra({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarra();
}

class _BarraData extends ContainerBoxParentData<RenderBox> {}

class _RenderBarra extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _BarraData>, RenderBoxContainerDefaultsMixin<RenderBox, _BarraData> {
  static const _huecoIzq = 14.0, _huecoDer = 8.0, _huecoCentro = 16.0, _huecoFilas = 8.0;

  /// Lo mínimo que se deja al título para acortarlo junto a la principal.
  static const _tituloMinimo = 200.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BarraData) child.parentData = _BarraData();
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final hijos = getChildrenAsList();
    // Ancho de cada grupo con todo el ancho disponible; los vacíos no cuentan.
    final nat = [for (final h in hijos) (h..layout(BoxConstraints(maxWidth: w), parentUsesSize: true)).size.width];
    bool hay(int i) => nat[i] > 0;
    double suma(List<int> ids, double hueco) =>
        ids.isEmpty ? 0 : ids.fold(0.0, (s, i) => s + nat[i]) + hueco * (ids.length - 1);
    bool cabe(List<int> izq, List<int> der) =>
        suma(izq, _huecoIzq) + (izq.isNotEmpty && der.isNotEmpty ? _huecoCentro : 0) + suma(der, _huecoDer) <= w;
    List<int> f(List<int> ids) => ids.where(hay).toList();

    // Filas (izquierda, derecha): si no cabe todo en una, los filtros bajan bajo el título (como en
    // Trabajadores) y la principal se queda arriba a la derecha mientras quepa.
    final List<(List<int>, List<int>)> filas;
    if (cabe(f([0, 1]), f([2, 3]))) {
      filas = [
        (f([0, 1]), f([2, 3])),
      ];
    } else if (cabe(f([0]), f([3]))) {
      filas = [
        (f([0]), f([3])),
        // Buscador a continuación de los filtros si cabe; si no, debajo.
        if (cabe(f([1, 2]), []))
          (f([1, 2]), <int>[])
        else ...[
          (f([1]), <int>[]),
          (f([2]), <int>[]),
        ],
      ];
    } else if (w - _huecoCentro - nat[3] >= _tituloMinimo) {
      // Ni título y principal caben: el título se acorta para no dejar la principal sola abajo.
      filas = [
        (f([0]), f([3])),
        (f([1]), <int>[]),
        (f([2]), <int>[]),
      ];
    } else {
      // Caso extremo (la principal casi no deja sitio): cada cosa en su fila antes que cortar el título.
      filas = [
        (f([0]), <int>[]),
        (f([1]), <int>[]),
        (f([2]), <int>[]),
        (<int>[], f([3])),
      ];
    }
    final limite = [for (final x in nat) min(x, w)];
    if (hay(0) && hay(3) && nat[0] + _huecoCentro + nat[3] > w && w - _huecoCentro - nat[3] >= _tituloMinimo) {
      limite[0] = max(0.0, w - _huecoCentro - nat[3]);
    }

    var y = 0.0;
    for (final (izq, der) in filas.where((fila) => fila.$1.isNotEmpty || fila.$2.isNotEmpty)) {
      // Lo que no cabe solo en su fila se desplaza dentro de su ancho.
      for (final i in [...izq, ...der]) {
        hijos[i].layout(BoxConstraints(maxWidth: limite[i]), parentUsesSize: true);
      }
      final alto = [...izq, ...der].fold(0.0, (m, i) => max(m, hijos[i].size.height));
      var x = 0.0;
      for (final i in izq) {
        (hijos[i].parentData! as _BarraData).offset = Offset(x, y + (alto - hijos[i].size.height) / 2);
        x += hijos[i].size.width + _huecoIzq;
      }
      x = w;
      for (final i in der.reversed) {
        x -= hijos[i].size.width;
        (hijos[i].parentData! as _BarraData).offset = Offset(x, y + (alto - hijos[i].size.height) / 2);
        x -= _huecoDer;
      }
      y += alto + _huecoFilas;
    }
    for (final (i, h) in hijos.indexed) {
      if (!hay(i)) (h.parentData! as _BarraData).offset = Offset.zero;
    }
    size = constraints.constrain(Size(w, max(0, y - _huecoFilas)));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Texto de una línea que elige, de [variantes] (de la más larga a la más corta), la primera que cabe.
class TextoAjustable extends StatelessWidget {
  final List<String> variantes;
  final TextStyle estilo;
  const TextoAjustable(this.variantes, {super.key, required this.estilo});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final style = DefaultTextStyle.of(context).style.merge(estilo);
      final escala = MediaQuery.textScalerOf(context);
      final texto = variantes.firstWhere((v) {
        final tp = TextPainter(
          text: TextSpan(text: v, style: style),
          textDirection: TextDirection.ltr,
          textScaler: escala,
          maxLines: 1,
        )..layout();
        return tp.width <= box.maxWidth;
      }, orElse: () => variantes.last);
      return Text(texto, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: style);
    },
  );
}

/// Título de vista dentro de la [BarraVista].
class TituloVista extends StatelessWidget {
  final String texto;
  const TituloVista(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    texto,
    maxLines: 1,
    style: TextStyle(
      fontFamily: P.titulos,
      fontSize: P.mejorada ? 24 : 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
    ),
  );
}

/// Selector segmentado (como el de iOS): opciones de igual ancho y una pastilla blanca que se desliza
/// hasta la elegida. Siempre 40 de alto, como el resto de controles.
class Pestanas extends StatelessWidget {
  final List<String> opciones;
  final List<Color?>? colores;
  final int seleccion;
  final ValueChanged<int> onChanged;

  /// Menos aire a los lados de cada opción, para filtros que van junto a otro selector.
  final bool compactas;
  final bool anchosIguales;

  /// Icono neutro delante de cada opción (null = sin icono).
  final List<IconData?>? iconos;

  /// Color de cada icono (null = el neutro).
  final List<Color?>? coloresIconos;
  const Pestanas({
    this.iconos,
    this.coloresIconos,
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.onChanged,
    this.colores,
    this.compactas = false,
    this.anchosIguales = true,
  });

  Widget _opcion(int i, Widget texto) => colores == null && iconos == null
      ? texto
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconos != null && iconos![i] != null) ...[
              Icon(iconos![i], size: 17, color: coloresIconos?[i] ?? P.textoSuave),
              const SizedBox(width: 6),
            ],
            if (colores != null && colores![i] != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: colores![i], shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            texto,
          ],
        );

  /// Móvil: un desplegable con la opción elegida (las pestañas no caben y quedarían cortadas).
  Widget _desplegable(TextStyle estilo) => PopupMenuButton<int>(
    tooltip: '',
    position: PopupMenuPosition.under,
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final (i, o) in opciones.indexed)
        PopupMenuItem(
          value: i,
          child: _opcion(i, Text(o, style: estilo.copyWith(color: i == seleccion ? P.morado : P.texto))),
        ),
    ],
    child: Container(
      height: 40,
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(P.radioControl)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (seleccion >= 0 && seleccion < opciones.length)
            _opcion(seleccion, Text(opciones[seleccion], style: estilo)),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 20, color: P.textoSuave),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final estilo = DefaultTextStyle.of(context).style.merge(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
    if (esMovil(context)) return _desplegable(estilo);
    final escala = MediaQuery.textScalerOf(context);
    final anchosTexto = <double>[];
    for (final o in opciones) {
      final tp = TextPainter(
        text: TextSpan(text: o, style: estilo),
        textDirection: Directionality.of(context), textScaler: escala, maxLines: 1,
      )..layout();
      anchosTexto.add(tp.width.ceilToDouble());
      tp.dispose();
    }
    final mayor = anchosTexto.fold<double>(0, max);
    final anchos = [for (var i = 0; i < opciones.length; i++)
      (anchosIguales ? mayor : anchosTexto[i]) + (compactas ? 18 : 28) +
      (colores != null && (anchosIguales || colores![i] != null) ? 14 : 0) +
      (iconos != null && (anchosIguales || iconos![i] != null) ? 23 : 0)];
    final total = anchos.fold<double>(0, (a, b) => a + b);
    final valida = seleccion >= 0 && seleccion < opciones.length;
    // Si no caben enteras en el ancho que hay, desplegable (nunca cortadas ni desbordando).
    return LayoutBuilder(
      builder: (context, box) {
        if (total + 6 > box.maxWidth) return _desplegable(estilo);
        // Si quien lo coloca lo estira (un campo a todo lo ancho), las opciones se reparten el sobrante: antes se
        // quedaban a un lado, con un hueco vacío detrás.
        final sobra = max(0.0, box.minWidth - 6 - total) / opciones.length;
        return _pestanas([for (final a in anchos) a + sobra], valida, estilo);
      },
    );
  }

  Widget _pestanas(List<double> anchos, bool valida, TextStyle estilo) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(P.radioControl)),
      child: SizedBox(
        width: anchos.fold<double>(0, (a, b) => a + b),
        child: Stack(
          children: [
            if (valida)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: anchos.take(seleccion).fold<double>(0, (a, b) => a + b),
                top: 0,
                bottom: 0,
                width: anchos[seleccion],
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: P.superficie,
                    borderRadius: BorderRadius.circular(P.radioControl - 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                for (final (i, o) in opciones.indexed)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: SizedBox(
                        width: anchos[i],
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: estilo.copyWith(color: i == seleccion ? P.texto : P.textoSuave),
                            child: _opcion(i, Text(o, maxLines: 1)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pestañas de subvista: la activa en negro relleno; el resto, texto (Resumen | Proyectos en Holded).
class PestanasOscuras extends StatelessWidget {
  final List<String> opciones;
  final int seleccion;
  final ValueChanged<int> onChanged;
  final List<int?>? contadores;
  const PestanasOscuras({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.onChanged,
    this.contadores,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: [
      for (final (i, o) in opciones.indexed)
        InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: i == seleccion ? P.texto : Colors.transparent,
              borderRadius: BorderRadius.circular(P.radioControl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  o,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: i == seleccion ? P.superficie : P.textoSuave,
                  ),
                ),
                if (contadores?[i] != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${contadores![i]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (i == seleccion ? P.superficie : P.textoSuave).withValues(alpha: .7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}

/// Estado vacío: ilustración gris en círculo, título, texto y acción.
class Vacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? titulo;
  final Widget? accion;

  /// Color del icono (por defecto, gris suave), p. ej. rojo en Incidencias.
  final Color? color;

  /// Con scroll si no cabe (por defecto). Sin él, se puede medir su alto natural (p. ej. dentro de un
  /// IntrinsicHeight, que no admite listas desplazables).
  final bool desplazable;

  /// Debajo de [accion], flechas discontinuas que se dibujan solas desde abajo y apuntan al botón.
  final bool flecha;

  /// Qué juego de flechas (cada vista el suyo).
  final int varianteFlecha;
  const Vacio({
    super.key,
    required this.icono,
    required this.texto,
    this.titulo,
    this.accion,
    this.color,
    this.desplazable = true,
    this.flecha = false,
    this.varianteFlecha = 0,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: _envolver(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            // Mejorada: en círculo, como el «todo al día» de la maqueta.
            decoration: P.mejorada
                ? BoxDecoration(color: P.hover, shape: BoxShape.circle)
                : BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(18)),
            child: Icon(icono, color: color ?? P.textoSuave.withValues(alpha: P.mejorada ? .9 : .6), size: 28),
          ),
          const SizedBox(height: 14),
          if (titulo != null) ...[
            Text(titulo!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.3)),
            const SizedBox(height: 4),
          ],
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: P.textoSuave, fontSize: 14),
          ),
          if (accion != null) ...[const SizedBox(height: 16), accion!],
          if (accion != null && flecha) ...[const SizedBox(height: 18), FlechaAlBoton(variante: varianteFlecha)],
        ],
      ),
    ),
  );

  Widget _envolver(Widget hijo) => desplazable
      ? SingleChildScrollView(padding: const EdgeInsets.all(24), child: hijo)
      : Padding(padding: const EdgeInsets.all(24), child: hijo);
}

/// Flecha discontinua que se dibuja marca a marca desde abajo, hace un bucle y acaba apuntando hacia arriba (al
/// botón que tiene encima). [variante] 1 la dibuja en espejo, para que cada vista tenga la suya. Se vuelve a dibujar
/// cada vez que su vista se muestra (al activarse su `TickerMode`).
class FlechaAlBoton extends StatefulWidget {
  final int variante;
  const FlechaAlBoton({super.key, this.variante = 0});

  @override
  State<FlechaAlBoton> createState() => _FlechaAlBotonState();
}

class _FlechaAlBotonState extends State<FlechaAlBoton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
    _visible = visible;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: const Size(140, 150),
        painter: _Flecha(
          CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic),
          P.morado.withValues(alpha: .7),
          widget.variante,
        ),
      ),
    ),
  );
}

class _Flecha extends CustomPainter {
  final Animation<double> avance;
  final Color color;
  final int variante;
  _Flecha(this.avance, this.color, this.variante) : super(repaint: avance);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Variante 1: en espejo (sale de abajo a la derecha y el bucle gira al otro lado).
    double x(double f) => variante == 1 ? w * (1 - f) : w * f;
    // Sale de abajo a un lado, sube hacia el otro, da una vuelta y sube recta al botón.
    final camino = Path()
      ..moveTo(x(.26), h - 2)
      ..cubicTo(x(.80), h * .92, x(.88), h * .56, x(.58), h * .54)
      ..cubicTo(x(.28), h * .52, x(.30), h * .84, x(.52), h * .78)
      ..cubicTo(x(.70), h * .73, x(.52), h * .30, x(.50), h * .07);
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final m = camino.computeMetrics().first;
    final hasta = m.length * avance.value;
    const marca = 6.0, hueco = 5.0;
    for (var d = 0.0; d < hasta - 4; d += marca + hueco) {
      canvas.drawPath(m.extractPath(d, min(d + marca, hasta - 4)), trazo);
    }
    // Punta cerrada y rellena, en la dirección del trazo, que crece al llegar.
    if (avance.value > .9) {
      final t = m.getTangentForOffset(hasta)!;
      final ang = -t.angle;
      final k = ((avance.value - .9) / .1).clamp(0.0, 1.0);
      final largo = 10 * k, ancho = 5 * k;
      final f = Offset(cos(ang), sin(ang)), n = Offset(-f.dy, f.dx);
      final punta = t.position + f * 2;
      final a = punta - f * largo + n * ancho, b = punta - f * largo * .7, c = punta - f * largo - n * ancho;
      canvas.drawPath(
        Path()
          ..moveTo(punta.dx, punta.dy)
          ..lineTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..close(),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_Flecha old) => old.color != color || old.variante != variante;
}

// ── Tablas ───────────────────────────────────────────────

/// Columna de una tabla: título y ancho (flex o fijo).
class Col {
  final String titulo;
  final int flex;
  final double? ancho;
  final bool derecha;

  /// Contenido propio de la cabecera en vez del título (p. ej. el botón de seleccionar).
  final Widget? cabecera;

  /// Texto al pasar el ratón por la cabecera (por defecto, «Arrastrar para intercambiar…»); sirve para
  /// columnas con título abreviado.
  final String? ayuda;

  /// No se puede quitar (la que dice qué es cada fila).
  final bool fija;

  /// De serie no sale: la añade el usuario desde el menú de columnas.
  final bool oculta;
  const Col(
    this.titulo, {
    this.flex = 1,
    this.ancho,
    this.derecha = false,
    this.cabecera,
    this.ayuda,
    this.fija = false,
    this.oculta = false,
  });
}

/// Tabla densa: cabecera gris pequeña, filas de ~56 px, sin rejilla y con la fila resaltada al pasar
/// el ratón. Las columnas se ensanchan o estrechan arrastrando su borde en la cabecera (como en Windows).
class Tabla extends StatefulWidget {
  final List<Col> columnas;
  final int filas;
  final Widget Function(int i, Widget fila)? envolverFila;

  /// Nombre con el que se guardan para cada cuenta el orden de sus columnas y cuáles se ven ([columnasTablas]);
  /// Exportar sale igual. Sin él, no se guarda nada y se ven todas.
  final String? id;

  /// Al final de la cabecera, el menú para quitar y añadir columnas (necesita [id]).
  final bool menuColumnas;
  final List<Widget> Function(int i) celdas;
  final void Function(int i)? onTap;
  final Widget? pie;
  final Widget? seleccionCabecera;

  /// Color del borde de una fila destacada (p. ej. la que se abrió desde Inicio); null = sin destacar.
  final Color? Function(int i)? resaltar;

  /// Fila que entra ya marcada (como con las flechas) y a la vista; null o -1 = ninguna.
  final int? focoInicial;
  const Tabla({
    this.focoInicial,
    super.key,
    required this.columnas,
    required this.filas,
    required this.celdas,
    this.onTap,
    this.pie,
    this.seleccionCabecera,
    this.resaltar,
    this.envolverFila,
    this.id,
    this.menuColumnas = false,
  });

  @override
  State<Tabla> createState() => _TablaState();
}

class _TablaState extends State<Tabla> with TickerProviderStateMixin {
  /// Al aparecer, las primeras filas entran escalonadas (opacidad y un poco desde abajo).
  late final _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..forward();

  /// Entra con [Tabla.focoInicial] marcada y la acerca a la vista.
  void _marcarInicial() {
    final i = widget.focoInicial;
    if (i == null || i < 0 || i >= widget.filas) return;
    _foco = i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo((i * 57.0 - 57).clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  /// Se ha marcado o quitado una columna (o se han cargado las de la cuenta): se vuelve a repartir el ancho.
  void _alCambiarColumnas() => setState(() {
    anchos.clear();
    _desde = {};
    _col = null;
  });

  @override
  void didUpdateWidget(Tabla old) {
    super.didUpdateWidget(old);
    if (widget.id != old.id) anchos.clear();
    if (widget.focoInicial != old.focoInicial) _marcarInicial();
  }

  /// Anchos elegidos arrastrando, por título de columna (las columnas pueden aparecer o no según el ancho).
  final anchos = <String, double>{};
  final _claves = <String, GlobalKey>{};
  final _lienzo = GlobalKey(), _pie = GlobalKey();
  int? _columnaArrastrando;

  /// Columna que se lleva en la mano, las columnas tal como se ven y, tras un cambio, desde dónde (en px) llega cada
  /// una a su sitio nuevo mientras [_deslizar] avanza.
  String? _moviendo;
  var _visibles = <Col>[];
  var _desde = <String, double>{};
  late final _deslizar = AnimationController(vsync: this, duration: const Duration(milliseconds: 240), value: 1);

  /// Cuánto está la columna en la mano apartada de su sitio: la lleva el puntero.
  final _tiron = ValueNotifier<double>(0);

  /// Dónde estaban el puntero y el borde izquierdo de la columna al cogerla.
  double _punteroInicial = 0, _izquierdaInicial = 0;

  /// Las cajas de las cabeceras (null si alguna aún no está pintada).
  Map<String, RenderBox>? _cajas() {
    final cajas = <String, RenderBox>{};
    for (final c in _visibles) {
      final caja = _claves[c.titulo]?.currentContext?.findRenderObject();
      if (caja is! RenderBox || !caja.hasSize) return null;
      cajas[c.titulo] = caja;
    }
    return cajas;
  }

  /// Borde izquierdo de cada columna con las columnas en [orden] (tras el margen de la tabla).
  static Map<String, double> _sitios(List<Col> orden, Map<String, RenderBox> cajas) {
    final sitios = <String, double>{};
    var x = 18.0;
    for (final c in orden) {
      sitios[c.titulo] = x;
      x += cajas[c.titulo]!.size.width;
    }
    return sitios;
  }

  void _cogerColumna(String titulo, Offset global) {
    final lienzo = _lienzo.currentContext?.findRenderObject() as RenderBox?;
    final cajas = _cajas();
    if (lienzo == null || cajas == null) return;
    Tooltip.dismissAllToolTips();
    _punteroInicial = lienzo.globalToLocal(global).dx;
    _izquierdaInicial = _sitios(_visibles, cajas)[titulo]!;
    _tiron.value = 0;
    setState(() {
      _moviendo = titulo;
      _desde = {};
    });
  }

  /// La columna sigue al puntero y, en cuanto su borde pasa de la mitad de la vecina, se cambian: la vecina se
  /// desliza al hueco que deja.
  void _llevarColumna(Offset global) {
    final titulo = _moviendo;
    final lienzo = _lienzo.currentContext?.findRenderObject() as RenderBox?;
    final cajas = _cajas();
    if (titulo == null || lienzo == null || cajas == null) return;
    // Solo se intercambian las de título; las de cabecera propia (casillas, menú de columnas) no se mueven.
    bool movible(Col c) => c.titulo.isNotEmpty && c.cabecera == null;
    final ancho = cajas[titulo]!.size.width;
    final total = cajas.values.fold(0.0, (a, c) => a + c.size.width);
    final izquierda = (_izquierdaInicial + lienzo.globalToLocal(global).dx - _punteroInicial)
        .clamp(18.0, max(18.0, 18 + total - ancho));
    var orden = [..._visibles];
    var cambiado = false;
    while (true) {
      final sitios = _sitios(orden, cajas);
      final i = orden.indexWhere((c) => c.titulo == titulo);
      final despues = orden.skip(i + 1).where(movible).firstOrNull;
      final antes = orden.take(i).where(movible).lastOrNull;
      double mitad(Col c) => sitios[c.titulo]! + cajas[c.titulo]!.size.width / 2;
      final otra = despues != null && izquierda + ancho > mitad(despues)
          ? despues
          : (antes != null && izquierda < mitad(antes) ? antes : null);
      if (otra == null) break;
      final j = orden.indexOf(otra);
      final nuevo = [...orden];
      nuevo[i] = otra;
      nuevo[j] = orden[i];
      orden = nuevo;
      cambiado = true;
    }
    final sitios = _sitios(orden, cajas);
    _tiron.value = izquierda - sitios[titulo]!;
    if (!cambiado) return;
    // Desde donde se ve ahora cada una (aunque esté a medio camino) hasta su sitio nuevo.
    final desde = <String, double>{
      for (final c in orden)
        if (c.titulo != titulo) c.titulo: cajas[c.titulo]!.localToGlobal(Offset.zero, ancestor: lienzo).dx - sitios[c.titulo]!,
    };
    setState(() {
      // El orden guardado conserva el sitio de las columnas que ahora no se ven.
      final titulos = [for (final c in orden) if (_orden.contains(c.titulo)) c.titulo];
      final huecos = [for (final t in titulos) _orden.indexOf(t)]..sort();
      for (final (n, hueco) in huecos.indexed) {
        _orden[hueco] = titulos[n];
      }
      _desde = desde;
    });
    _deslizar.forward(from: 0);
  }

  /// Al soltarla, termina de encajar en su sitio.
  void _soltarColumna() {
    final titulo = _moviendo;
    if (titulo == null || !mounted) return;
    setState(() {
      _moviendo = null;
      _desde = {titulo: _tiron.value};
    });
    _tiron.value = 0;
    _deslizar.forward(from: 0);
    if (widget.id != null) columnasTablas.guardar();
  }

  /// Sitio de la columna en la mano entre las que se ven (null = ninguna).
  int? _encima(List<Col> columnas) {
    final i = columnas.indexWhere((c) => c.titulo == _moviendo);
    return _moviendo == null || i < 0 ? null : i;
  }

  /// La celda de la columna [titulo], deslizándose hasta su sitio si acaba de cambiar.
  Widget _deslizada(String titulo, Widget celda) => AnimatedBuilder(
    animation: _deslizar,
    child: celda,
    builder: (_, child) => Transform.translate(
      offset: Offset((_desde[titulo] ?? 0) * (1 - Curves.easeOutCubic.transform(_deslizar.value)), 0),
      child: child,
    ),
  );
  final _ordenPropio = <String>[];
  List<String> get _orden => widget.id == null ? _ordenPropio : columnasTablas.orden(widget.id!);

  /// Teclado: ↓/↑ recorren las filas de la tabla de la vista (la última abierta), Intro abre la marcada y
  /// Esc quita la marca. No actúa al escribir en un campo ni con una ventana encima.
  static final _abiertas = <_TablaState>[];
  int? _foco;

  /// Columna marcada dentro de la fila (←/→); Intro o espacio la «pulsan» como un clic.
  int? _col;
  int _nCols = 0;
  final _celdas = <int, GlobalKey>{};
  final _scroll = ScrollController();
  final _filas = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _marcarInicial();
    _abiertas.add(this);
    HardwareKeyboard.instance.addHandler(_tecla);
    columnasTablas.addListener(_alCambiarColumnas);
  }

  @override
  void dispose() {
    _abiertas.remove(this);
    HardwareKeyboard.instance.removeHandler(_tecla);
    columnasTablas.removeListener(_alCambiarColumnas);
    _scroll.dispose();
    _entrada.dispose();
    _deslizar.dispose();
    _tiron.dispose();
    super.dispose();
  }

  /// Busca dentro de la celda lo primero que se pueda pulsar y lo pulsa.
  bool _pulsarCelda(int j) {
    final c = _celdas[j]?.currentContext;
    if (c == null) return false;
    VoidCallback? accion;
    void buscar(Element e) {
      if (accion != null) return;
      final w = e.widget;
      if (w is InkWell && w.onTap != null) {
        accion = w.onTap;
      } else if (w is GestureDetector && w.onTap != null) {
        accion = w.onTap;
      } else if (w is ButtonStyleButton && w.onPressed != null) {
        accion = w.onPressed;
      } else if (w is IconButton && w.onPressed != null) {
        accion = w.onPressed;
      } else {
        e.visitChildElements(buscar);
      }
    }

    (c as Element).visitChildElements(buscar);
    accion?.call();
    return accion != null;
  }

  bool _tecla(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    final k = e.logicalKey;
    const teclas = [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.escape,
    ];
    if (!teclas.contains(k) || !mounted || _abiertas.lastOrNull != this || widget.filas == 0) return false;
    final foco = primaryFocus?.context;
    if (foco?.findAncestorStateOfType<EditableTextState>() != null) return false;
    final arriba = foco == null ? null : ModalRoute.of(foco);
    if (arriba != null && arriba != ModalRoute.of(context)) return false;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      // Sin ninguna marcada, la primera pulsación marca la primera fila; la siguiente la abre.
      if (_foco == null) {
        setState(() => _foco = 0);
        return true;
      }
      // En una celda: lo mismo que un clic en lo que tenga (selector, enlace…); si no tiene nada, la fila.
      if (_col != null && _pulsarCelda(_col!)) return true;
      if (widget.onTap == null) return false;
      widget.onTap!(_foco!);
      return true;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (_foco == null) return false;
      setState(() => _foco = _col = null);
      return true;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      if (_foco == null || _nCols == 0) return false;
      final der = k == LogicalKeyboardKey.arrowRight;
      final j = _col == null ? (der ? 0 : _nCols - 1) : (_col! + (der ? 1 : -1)).clamp(0, _nCols - 1);
      setState(() => _col = j);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _celdas[j]?.currentContext;
        final ro = c?.findRenderObject();
        final lado = c == null ? null : Scrollable.maybeOf(c, axis: Axis.horizontal);
        if (ro != null && lado != null) {
          lado.position.ensureVisible(
            ro,
            duration: const Duration(milliseconds: 120),
            alignmentPolicy: der
                ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        }
      });
      return true;
    }
    final baja = k == LogicalKeyboardKey.arrowDown;
    final i = _foco == null ? (baja ? 0 : widget.filas - 1) : (_foco! + (baja ? 1 : -1)).clamp(0, widget.filas - 1);
    setState(() => _foco = i);
    void mostrar() {
      final c = _filas[i]?.currentContext;
      if (c == null) return;
      // Solo en vertical: si la tabla también se desplaza de lado, eso no se toca.
      final vertical = Scrollable.maybeOf(c, axis: Axis.vertical);
      final ro = c.findRenderObject();
      if (vertical == null || ro == null) return;
      vertical.position.ensureVisible(
        ro,
        duration: const Duration(milliseconds: 120),
        alignmentPolicy: baja
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fila aún sin construir (fuera de la vista): primero se acerca la lista y luego se ajusta.
      if (_filas[i]?.currentContext == null && _scroll.hasClients) {
        _scroll.jumpTo((i * 57.0).clamp(0, _scroll.position.maxScrollExtent));
        WidgetsBinding.instance.addPostFrameCallback((_) => mostrar());
      } else {
        mostrar();
      }
    });
    return true;
  }

  Widget _celda(Col c, Widget w, {GlobalKey? clave, bool inicio = false}) {
    final contenido = clave == null && (c.titulo.isEmpty || inicio) && widget.seleccionCabecera != null
        ? Transform.translate(offset: const Offset(-4, 0), child: w)
        : w;
    final alineada = Align(
      key: clave,
      alignment: c.derecha ? Alignment.centerRight : Alignment.centerLeft,
      child: contenido,
    );
    final hijo = _deslizada(c.titulo, alineada);
    // Cada columna con su clave: al cambiar de sitio se lleva sus celdas (y lo que estén haciendo).
    final identidad = c.titulo.isEmpty ? null : ValueKey('columna-${c.titulo}');
    final fijo = anchos[c.titulo] ?? c.ancho;
    return fijo != null
        ? SizedBox(key: identidad, width: fijo, child: hijo)
        : Expanded(key: identidad, flex: c.flex, child: hijo);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    for (final (i, c) in widget.columnas.indexed) {
      if (c.titulo.isEmpty || _orden.contains(c.titulo)) continue;
      final siguiente = widget.columnas.skip(i + 1).where((c) => _orden.contains(c.titulo)).firstOrNull;
      if (siguiente == null) {
        _orden.add(c.titulo);
      } else {
        _orden.insert(_orden.indexOf(siguiente.titulo), c.titulo);
      }
    }
    final columnas = [
      for (final c in widget.columnas)
        if (id == null || c.titulo.isEmpty || c.fija || columnasTablas.ve(id, c.titulo, porDefecto: !c.oculta)) c,
    ]..sort((a, b) {
        if (a.titulo.isEmpty) return b.titulo.isEmpty ? 0 : -1;
        if (b.titulo.isEmpty) return 1;
        return _orden.indexOf(a.titulo).compareTo(_orden.indexOf(b.titulo));
      });
    // El menú va siempre el último, separado por una raya; no es una columna que se mueva ni se guarde.
    final menu = id != null && widget.menuColumnas
        ? Col(
            'Columnas',
            ancho: 48,
            derecha: true,
            cabecera: Row(
              children: [
                Container(width: 1, height: 16, color: P.borde),
                const Spacer(),
                _MenuColumnas(
                  tabla: id,
                  columnas: [
                    for (final t in _orden) ...widget.columnas.where((c) => c.titulo == t),
                  ],
                ),
              ],
            ),
          )
        : null;
    if (menu != null) columnas.add(menu);
    _nCols = columnas.length;
    _visibles = columnas;
    return Container(
      decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(P.radio), boxShadow: P.sombra),
      // Borde por encima del contenido: si no, las cabeceras lo tapan en las esquinas.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(P.radio),
        border: Border.all(color: P.borde),
      ),
      clipBehavior: Clip.antiAlias,
      // Pocas filas: la tabla mide lo que su contenido. Muchas: ocupa el alto y solo construye las visibles.
      child: TooltipVisibility(
        visible: _columnaArrastrando == null && _moviendo == null,
        child: CustomPaint(
          key: _lienzo,
          foregroundPainter: _columnaArrastrando != null
              ? _GuiasColumna(
                  columna: _claves[columnas[_columnaArrastrando!].titulo]!,
                  lienzo: _lienzo,
                  pie: _pie,
                  primera: _columnaArrastrando == 0,
                  color: P.morado,
                )
              : _moviendo != null
              ? _LineasColumnas(
                  cajas: [for (final c in columnas) _claves[c.titulo]],
                  enLaMano: _encima(columnas),
                  lienzo: _lienzo,
                  pie: _pie,
                  tiron: _tiron,
                  repintar: Listenable.merge([_tiron, _deslizar]),
                  linea: P.textoSuave.withValues(alpha: .35),
                  marcada: P.morado,
                )
              : null,
          child: Column(
            mainAxisSize: widget.filas > 15 ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    color: P.cabeceraTabla,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    height: 42,
                    child: _FilaColumnas(
                      encima: _encima(columnas),
                      tiron: _tiron,
                      fondo: Color.alphaBlend(P.morado.withValues(alpha: .14), P.superficie),
                      children: [
                        for (final (j, c) in columnas.indexed)
                          _celda(
                            c,
                            clave: _claves.putIfAbsent(c.titulo, GlobalKey.new),
                            c.cabecera ??
                                Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: j == 0 && widget.seleccionCabecera != null ? 36 : 0,
                                        ),
                                        child: _TituloColumna(
                                          titulo: c.titulo,
                                          ayuda: c.ayuda,
                                          derecha: c.derecha,
                                          enLaMano: _moviendo == c.titulo,
                                          onEmpezar: (global) => _cogerColumna(c.titulo, global),
                                          onMover: _llevarColumna,
                                          onSoltar: _soltarColumna,
                                        ),
                                      ),
                                    ),
                                    // Asa para redimensionar (no en la última ni en las columnas sin título).
                                    // Tampoco antes de una última columna de solo icono (p. ej. el rayo): no se ensancha.
                                    if (j < columnas.length - 1 &&
                                        c.titulo.isNotEmpty &&
                                        !(j == columnas.length - 2 && columnas.last.cabecera != null))
                                      _AsaColumna(
                                        onInicio: () {
                                          Tooltip.dismissAllToolTips();
                                          final siguiente = columnas[j + 1];
                                          final izquierda =
                                              _claves[c.titulo]?.currentContext?.findRenderObject() as RenderBox?;
                                          final derecha =
                                              _claves[siguiente.titulo]?.currentContext?.findRenderObject()
                                                  as RenderBox?;
                                          if (izquierda != null && derecha != null) {
                                            setState(() {
                                              anchos[c.titulo] = izquierda.size.width;
                                              anchos[siguiente.titulo] = derecha.size.width;
                                              _columnaArrastrando = j + 1;
                                            });
                                          }
                                        },
                                        onFin: () => setState(() => _columnaArrastrando = null),
                                        onMover: (dx) {
                                          final siguiente = columnas[j + 1];
                                          final izquierda = anchos[c.titulo]!;
                                          final derecha = anchos[siguiente.titulo]!;
                                          final minimoIzquierda = c.ancho == null ? 56.0 : c.ancho!.clamp(0.0, 56.0);
                                          final minimoDerecha = siguiente.ancho == null
                                              ? 56.0
                                              : siguiente.ancho!.clamp(0.0, 56.0);
                                          final cambio = dx.clamp(minimoIzquierda - izquierda, derecha - minimoDerecha);
                                          setState(() {
                                            anchos[c.titulo] = izquierda + cambio;
                                            anchos[siguiente.titulo] = derecha - cambio;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.seleccionCabecera != null)
                    Positioned(
                      left: 8,
                      top: 0,
                      width: 32,
                      height: 42,
                      child: Align(alignment: Alignment.centerLeft, child: widget.seleccionCabecera!),
                    ),
                ],
              ),
              Divider(height: 1, color: P.borde),
              Flexible(
                fit: widget.filas > 15 ? FlexFit.tight : FlexFit.loose,
                child: ListView.separated(
                  controller: _scroll,
                  shrinkWrap: widget.filas <= 15,
                  itemCount: widget.filas,
                  separatorBuilder: (_, _) => Divider(height: 1, color: P.borde),
                  itemBuilder: (_, i) {
                    final cs = widget.celdas(i);
                    // Las celdas vienen en el orden de [Tabla.columnas], se vean o no; el menú no lleva.
                    Widget celdaDe(Col c) => c == menu ? const SizedBox() : cs[widget.columnas.indexOf(c)];
                    final borde = widget.resaltar?.call(i);
                    final marcada = i == _foco;
                    // Destacada: un poco hacia dentro para que el borde se vea entero también por los lados.
                    final fila = Material(
                      key: _filas.putIfAbsent(i, GlobalKey.new),
                      color: borde != null
                          ? borde.withValues(alpha: .06)
                          : marcada
                          ? P.hoverFila
                          : Colors.transparent,
                      shape: borde == null
                          ? null
                          : RoundedRectangleBorder(
                              side: BorderSide(color: borde, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                      child: InkWell(
                        hoverColor: P.hoverFila,
                        onTap: widget.onTap == null ? null : () => widget.onTap!(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            child: _FilaColumnas(
                              encima: _encima(columnas),
                              tiron: _tiron,
                              fondo: Color.alphaBlend(P.morado.withValues(alpha: .06), P.superficie),
                              // Cubre también el relleno de la fila: la columna se ve entera, sin cortes.
                              sobresale: 10,
                              children: [
                                for (final (j, c) in columnas.indexed)
                                  _celda(
                                    c,
                                    // Celda marcada con el teclado: un recuadro algo más oscuro encima.
                                    marcada && j == _col
                                        ? Container(
                                            key: _celdas.putIfAbsent(j, GlobalKey.new),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: P.hover,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: P.borde),
                                            ),
                                            child: celdaDe(c),
                                          )
                                        : celdaDe(c),
                                    inicio: c == columnas.first,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    final contenido = borde == null ? fila : Padding(padding: const EdgeInsets.all(3), child: fila);
                    final envuelta = widget.envolverFila?.call(i, contenido) ?? contenido;
                    if (i >= 12 || _entrada.isCompleted) return envuelta;
                    final paso = CurvedAnimation(
                      parent: _entrada,
                      curve: Interval(i * .045, (i * .045 + .5).clamp(0, 1), curve: Curves.easeOutCubic),
                    );
                    return FadeTransition(
                      opacity: paso,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, .12), end: Offset.zero).animate(paso),
                        child: envuelta,
                      ),
                    );
                  },
                ),
              ),
              if (widget.pie != null) ...[
                Divider(key: _pie, height: 1, color: P.borde),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: widget.pie),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Último botón de la cabecera: todas las columnas de la tabla, con marcadas las que se ven, para quitar o añadir.
class _MenuColumnas extends StatelessWidget {
  final String tabla;

  /// Las de la tabla, en el orden en que las tiene el usuario.
  final List<Col> columnas;
  const _MenuColumnas({required this.tabla, required this.columnas});

  @override
  Widget build(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(-200, 4),
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(P.superficie),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    menuChildren: [
      MenuItemButton(
        onPressed: null,
        child: Text('Columnas', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
      ),
      for (final c in columnas) _opcion(c),
      const Divider(height: 8),
      MenuItemButton(
        closeOnActivate: false,
        leadingIcon: Icon(Icons.restart_alt_rounded, size: 20, color: P.textoSuave),
        onPressed: () => columnasTablas.restablecer(tabla),
        child: const Text('Restaurar'),
      ),
    ],
    builder: (context, menu, _) => IconButton(
      tooltip: 'Elegir columnas',
      visualDensity: VisualDensity.compact,
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      icon: Icon(Icons.view_column_outlined, size: 18, color: P.textoSuave),
    ),
  );

  Widget _opcion(Col c) {
    final visible = c.fija || columnasTablas.ve(tabla, c.titulo, porDefecto: !c.oculta);
    return MenuItemButton(
      closeOnActivate: false,
      leadingIcon: Icon(
        visible ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
        size: 20,
        // La fija sale marcada y apagada: está, pero no se puede quitar.
        color: c.fija ? P.textoSuave.withValues(alpha: .55) : (visible ? P.morado : P.textoSuave),
      ),
      onPressed: c.fija ? null : () => columnasTablas.poner(tabla, c.titulo, !visible),
      child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 160), child: Text(c.titulo)),
    );
  }
}

/// La fila de una tabla en la que una columna puede ir «en la mano»: se pinta la última (por encima de las demás),
/// sobre su fondo y desplazada lo que diga [tiron].
class _FilaColumnas extends Row {
  final int? encima;
  final ValueListenable<double> tiron;
  final Color fondo;
  final double sobresale;
  const _FilaColumnas({
    required this.encima,
    required this.tiron,
    required this.fondo,
    this.sobresale = 0,
    super.children,
  });

  @override
  RenderFlex createRenderObject(BuildContext context) => _PintaColumnas(
    direction: Axis.horizontal,
    textDirection: getEffectiveTextDirection(context),
    crossAxisAlignment: crossAxisAlignment,
    tiron: tiron,
  )..poner(encima, fondo, sobresale);

  @override
  void updateRenderObject(BuildContext context, RenderFlex renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _PintaColumnas).poner(encima, fondo, sobresale);
  }
}

class _PintaColumnas extends RenderFlex {
  final ValueListenable<double> tiron;
  int? _encima;
  Color _fondo = Colors.transparent;
  double _sobresale = 0;
  _PintaColumnas({required this.tiron, super.direction, super.textDirection, super.crossAxisAlignment});

  void poner(int? encima, Color fondo, double sobresale) {
    _encima = encima;
    _fondo = fondo;
    _sobresale = sobresale;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    tiron.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    tiron.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_encima == null) return super.paint(context, offset);
    RenderBox? suelta;
    var hijo = firstChild;
    for (var i = 0; hijo != null; i++) {
      final datos = hijo.parentData! as FlexParentData;
      if (i == _encima) {
        suelta = hijo;
      } else {
        context.paintChild(hijo, datos.offset + offset);
      }
      hijo = datos.nextSibling;
    }
    if (suelta == null) return;
    final sitio = (suelta.parentData! as FlexParentData).offset + offset + Offset(tiron.value, 0);
    // Entre separador y separador (van 7 px antes del final de cada celda).
    final caja = Rect.fromLTWH(sitio.dx - 7, offset.dy - _sobresale, suelta.size.width, size.height + _sobresale * 2);
    context.canvas
      ..drawShadow(Path()..addRect(caja), Colors.black, 5, false)
      ..drawRect(caja, Paint()..color = _fondo);
    context.paintChild(suelta, sitio);
  }
}

/// Título arrastrable; el separador de anchura queda fuera de su zona de arrastre.
class _TituloColumna extends StatefulWidget {
  final String titulo;
  final bool derecha, enLaMano;
  final ValueChanged<Offset> onEmpezar, onMover;
  final VoidCallback onSoltar;
  final String? ayuda;
  const _TituloColumna({
    required this.titulo,
    required this.derecha,
    required this.enLaMano,
    required this.onEmpezar,
    required this.onMover,
    required this.onSoltar,
    this.ayuda,
  });

  @override
  State<_TituloColumna> createState() => _TituloColumnaState();
}

class _TituloColumnaState extends State<_TituloColumna> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.enLaMano ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
    onEnter: (_) => setState(() => _encima = true),
    onExit: (_) => setState(() => _encima = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Desde donde se pulsa: la columna no da un salto al empezar a moverse.
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: (d) => widget.onEmpezar(d.globalPosition),
      onHorizontalDragUpdate: (d) => widget.onMover(d.globalPosition),
      onHorizontalDragEnd: (_) => widget.onSoltar(),
      onHorizontalDragCancel: widget.onSoltar,
      child: Tooltip(
        message: widget.ayuda ?? 'Arrastrar para intercambiar ${widget.titulo}',
        child: Semantics(
          label: 'Columna ${widget.titulo}, arrastrar para intercambiar',
          child: _contenido(_encima || widget.enLaMano),
        ),
      ),
    ),
  );

  Widget _contenido(bool mostrarAsa) => SizedBox(
    height: 42,
    // Flex (no Row) para poder recortar: en una columna muy estrecha, lo que no cabe (el asa) se recorta en vez de
    // desbordar.
    child: Flex(
      direction: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      children: [
        Expanded(
          child: Text(
            widget.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.derecha ? TextAlign.right : TextAlign.left,
            // Mejorada: cabecera algo más marcada, como las tablas de un panel tradicional.
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: P.mejorada ? FontWeight.w600 : FontWeight.w500,
              color: P.textoSuave,
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: mostrarAsa ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Icon(Icons.drag_indicator_rounded, size: 16, color: P.textoSuave),
        ),
      ],
    ),
  );
}

/// Guías superpuestas: no interceptan el ratón ni crean widgets por cada tramo.
class _GuiasColumna extends CustomPainter {
  final GlobalKey columna, lienzo, pie;
  final bool primera;
  final Color color;
  _GuiasColumna({
    required this.columna,
    required this.lienzo,
    required this.pie,
    required this.primera,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final celda = columna.currentContext?.findRenderObject() as RenderBox?;
    final tabla = lienzo.currentContext?.findRenderObject() as RenderBox?;
    if (celda == null || tabla == null || !celda.hasSize) return;
    final origen = celda.localToGlobal(Offset.zero, ancestor: tabla);
    final pintura = Paint()
      ..color = color.withValues(alpha: .65)
      ..strokeWidth = 1;
    // Las guías coinciden con el centro del asa de cada límite.
    final izquierda = primera ? 1.0 : origen.dx - 7;
    final derecha = origen.dx + celda.size.width - 7;
    // El pie (el recuento) no es de ninguna columna: las guías paran en la última fila.
    final cajaPie = pie.currentContext?.findRenderObject() as RenderBox?;
    if (cajaPie != null && cajaPie.hasSize)
      size = Size(size.width, cajaPie.localToGlobal(Offset.zero, ancestor: tabla).dy);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Rect.fromLTRB(izquierda, 0, derecha, size.height), Paint()..color = color.withValues(alpha: .07));
    for (final x in [izquierda, derecha]) {
      for (double y = 0; y < size.height; y += 10) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + 5).clamp(0, size.height)), pintura);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GuiasColumna oldDelegate) => true;
}

/// Mientras se lleva una columna: una línea vertical en cada límite, de la cabecera a la última fila, que se mueve
/// con las columnas. Las de la que va en la mano, en morado.
class _LineasColumnas extends CustomPainter {
  /// Las cabeceras, en el orden en que se ven.
  final List<GlobalKey?> cajas;
  final int? enLaMano;
  final GlobalKey lienzo, pie;
  final ValueListenable<double> tiron;
  final Color linea, marcada;
  _LineasColumnas({
    required this.cajas,
    required this.enLaMano,
    required this.lienzo,
    required this.pie,
    required this.tiron,
    required Listenable repintar,
    required this.linea,
    required this.marcada,
  }) : super(repaint: repintar);

  @override
  void paint(Canvas canvas, Size size) {
    final tabla = lienzo.currentContext?.findRenderObject() as RenderBox?;
    if (tabla == null) return;
    final cajaPie = pie.currentContext?.findRenderObject() as RenderBox?;
    final alto = cajaPie != null && cajaPie.hasSize
        ? cajaPie.localToGlobal(Offset.zero, ancestor: tabla).dy
        : size.height;
    // Dónde empieza y acaba cada columna tal como se ve ahora (a medio deslizar incluido).
    final tramos = <(double, double)>[];
    for (final (i, clave) in cajas.indexed) {
      final caja = clave?.currentContext?.findRenderObject() as RenderBox?;
      if (caja == null || !caja.hasSize) return;
      final x = caja.localToGlobal(Offset.zero, ancestor: tabla).dx + (i == enLaMano ? tiron.value : 0);
      tramos.add((x - 7, x + caja.size.width - 7));
    }
    final mano = enLaMano == null ? null : tramos[enLaMano!];
    void raya(double x, Color color, double grosor) => canvas.drawLine(
      Offset(x, 0),
      Offset(x, alto),
      Paint()
        ..color = color
        ..strokeWidth = grosor,
    );
    for (final (i, (_, fin)) in tramos.indexed) {
      // El borde derecho de la tabla ya está; bajo la columna en la mano no se pintan las de las demás.
      if (i == tramos.length - 1 || i == enLaMano || (mano != null && fin > mano.$1 + 1 && fin < mano.$2 - 1)) {
        continue;
      }
      raya(fin, linea, 1);
    }
    if (mano != null) {
      raya(mano.$1, marcada, 1.8);
      raya(mano.$2, marcada, 1.8);
    }
  }

  @override
  bool shouldRepaint(covariant _LineasColumnas old) => true;
}

/// Borde arrastrable de una columna en la cabecera: raya fina que se pone morada al pasar el ratón.
class _AsaColumna extends StatefulWidget {
  final VoidCallback onInicio;
  final ValueChanged<double> onMover;
  final VoidCallback onFin;
  const _AsaColumna({required this.onInicio, required this.onMover, required this.onFin});

  @override
  State<_AsaColumna> createState() => _AsaColumnaState();
}

class _AsaColumnaState extends State<_AsaColumna> {
  bool activa = false, arrastrando = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    onEnter: (_) => setState(() => activa = true),
    onExit: (_) => setState(() => activa = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        setState(() => arrastrando = true);
        widget.onInicio();
      },
      onHorizontalDragUpdate: (d) => widget.onMover(d.delta.dx),
      onHorizontalDragEnd: (_) {
        setState(() => arrastrando = false);
        widget.onFin();
      },
      onHorizontalDragCancel: () {
        setState(() => arrastrando = false);
        widget.onFin();
      },
      child: SizedBox(
        width: 14,
        height: 42,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: activa || arrastrando ? 3 : 1,
            height: activa || arrastrando ? 26 : 16,
            decoration: BoxDecoration(
              color: activa || arrastrando ? P.morado : P.borde,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Texto de celda: normal, gris o en negrita.
Widget celdaTexto(String t, {bool suave = false, bool negrita = false}) => Text(
  t.isEmpty ? '—' : t,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    fontSize: 14,
    color: suave || t.isEmpty ? P.textoSuave : P.texto,
    fontWeight: negrita ? FontWeight.w600 : FontWeight.w400,
  ),
);

/// Pie de tabla: "1–12 (12)" a la izquierda, como la paginación de Holded.
Widget pieTabla(int n, String nombre) =>
    Text('1–$n ($n $nombre)', style: TextStyle(fontSize: 12.5, color: P.textoSuave));

/// Navegación de fechas en un solo bloque con borde: ‹  Hoy  › (como el calendario de Holded).
class NavegadorFecha extends StatelessWidget {
  final VoidCallback onAnterior, onHoy, onSiguiente;
  final String anterior, siguiente;
  const NavegadorFecha({
    super.key,
    required this.onAnterior,
    required this.onHoy,
    required this.onSiguiente,
    this.anterior = 'Anterior',
    this.siguiente = 'Siguiente',
  });

  Widget _flecha(IconData i, String tip, VoidCallback f) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: f,
      child: SizedBox(width: 38, height: 38, child: Icon(i, size: 20, color: P.textoSuave)),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(P.radioControl)),
    // Borde por encima del contenido: si no, las cabeceras lo tapan en las esquinas.
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(P.radioControl),
      border: Border.all(color: P.borde),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _flecha(Icons.chevron_left_rounded, anterior, onAnterior),
        VerticalDivider(width: 1, color: P.borde),
        InkWell(
          onTap: onHoy,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text('Hoy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        VerticalDivider(width: 1, color: P.borde),
        _flecha(Icons.chevron_right_rounded, siguiente, onSiguiente),
      ],
    ),
  );
}

/// Interruptor de vista (lista / bloques) con dos iconos.
class SelectorVista extends StatelessWidget {
  final bool lista;
  final ValueChanged<bool> onChanged;

  /// Bloques a la izquierda (solo Técnicos); en el resto de vistas, la lista va primero.
  final bool bloquesPrimero;
  const SelectorVista({super.key, required this.lista, required this.onChanged, this.bloquesPrimero = false});

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(P.radioControl)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (v, i, tip) in [
          if (bloquesPrimero) (false, Icons.grid_view_rounded, 'Bloques'),
          (true, Icons.view_list_rounded, 'Lista'),
          if (!bloquesPrimero) (false, Icons.grid_view_rounded, 'Bloques'),
        ])
          Tooltip(
            message: tip,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lista == v ? P.superficie : Colors.transparent,
                  borderRadius: BorderRadius.circular(P.radioControl - 3),
                  boxShadow: lista == v
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .08),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Icon(i, size: 17, color: lista == v ? P.texto : P.textoSuave),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Asignación en un círculo: persona (asignado, en verde) o persona tachada (sin asignar, en gris).
class IconoAsignado extends StatelessWidget {
  final bool asignado;
  final double size;
  final Color? color;
  const IconoAsignado(this.asignado, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (asignado ? P.verde : P.textoSuave);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.4)),
      child: Icon(asignado ? Icons.person_outline_rounded : Icons.person_off_outlined, size: size * .6, color: c),
    );
  }
}

/// Avatares superpuestos de los trabajadores asignados.
class AvataresTrabajadores extends StatelessWidget {
  final List<String> ids;
  final double size;
  const AvataresTrabajadores(this.ids, {super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final ws = ids.map(store.trabajador).whereType<Trabajador>().take(3).toList();
    if (ws.isEmpty) {
      return Tooltip(
        message: m('Sin trabajador asignado'),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: P.borde, width: 1.5),
          ),
          // Sin nadie: la persona tachada dentro del círculo.
          child: Icon(Icons.person_off_outlined, size: size * .55, color: P.textoSuave),
        ),
      );
    }
    final paso = size * .65;
    return SizedBox(
      width: size + (ws.length - 1) * paso,
      height: size,
      child: Stack(
        children: [
          for (final (i, w) in ws.indexed)
            Positioned(
              left: i * paso,
              child: Tooltip(
                message: w.nombreCompleto,
                child: Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: size, bordeBlanco: true),
              ),
            ),
        ],
      ),
    );
  }
}

/// Quién lo hace, como en la landing: píldora suave con el nombre del trabajador en su color
/// ("Laura"), "+N" si hay más, o "Sin asignar" en gris.
class PillTrabajadores extends StatelessWidget {
  final List<String> ids;
  const PillTrabajadores(this.ids, {super.key});

  @override
  Widget build(BuildContext context) {
    final ws = ids.map(store.trabajador).whereType<Trabajador>().toList();
    if (ws.isEmpty) return Pill('Sin asignar', P.textoSuave);
    return Tooltip(
      message: ws.map((w) => w.nombreCompleto).join(', '),
      child: Pill(
        ws.length == 1 ? ws.first.nombre : '${ws.first.nombre} +${ws.length - 1}',
        colorPaleta(ws.first.color),
      ),
    );
  }
}

/// Estado de una tarea como pastilla suave con su punto: vencida, toca hoy, pronto, al día.
Widget pillEstado(Tarea t) {
  if (t.esPlantilla) return Pill('Plantilla', P.morado, icono: Icons.content_copy_rounded);
  if (!t.activa) return const Pill('Pausado', P.gris, punto: true);
  if (t.proximo == null) return const Pill('Sin fecha', P.gris, punto: true);
  final n = diasHasta(t.proximo!);
  if (n < 0) return const Pill('Vencido', P.rojo, punto: true);
  if (n == 0) return Pill('Hoy', P.morado, punto: true);
  if (n <= 7) return const Pill('Pronto', P.ambar, punto: true);
  return const Pill('Al día', P.verde, punto: true);
}

/// Consejo de la interfaz: bombilla morada y una frase que explica para qué sirve algo.
/// Todos los consejos de Pultec usan este estilo.
class Consejo extends StatelessWidget {
  final String texto;

  /// A la derecha, p. ej. un enlace para hacerlo.
  final Widget? accion;

  /// Para recordar que se ha cerrado (por defecto, el propio texto).
  final String? clave;
  const Consejo(this.texto, {super.key, this.accion, this.clave});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ajustes,
    builder: (context, _) {
      final id = clave ?? texto.hashCode.toString();
      // Cerrado con su X: ya no sale.
      if (ajustes.consejoCerrado(id)) return const SizedBox.shrink();
      return Tarjeta(
        color: P.moradoSuave,
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: P.morado, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texto, style: TextStyle(color: P.moradoOscuro, fontSize: 13)),
            ),
            if (accion != null) ...[const SizedBox(width: 12), accion!],
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'No volver a mostrar',
              visualDensity: VisualDensity.compact,
              onPressed: () => ajustes.cerrarConsejo(id),
              icon: Icon(Icons.close_rounded, size: 18, color: P.moradoOscuro.withValues(alpha: .7)),
            ),
          ],
        ),
      );
    },
  );
}

/// Píldora con el estado del próximo mantenimiento.
Widget pillVencimiento(Tarea t) {
  if (t.esPlantilla) return Pill(t.periodicidad.etiqueta, P.gris, icono: Icons.repeat_rounded);
  if (t.proximo == null) return const Pill('Sin fecha', P.gris, icono: Icons.event_outlined);
  final n = diasHasta(t.proximo!);
  final color = n < 0 ? P.rojo : (n <= 3 ? P.ambar : P.morado);
  return Pill(relativo(t.proximo!), color, icono: n < 0 ? Icons.warning_amber_rounded : Icons.event_outlined);
}

/// Pregunta para borrar trabajos: avisa de los subtrabajos que se borran con ellos (DEV-003).
String preguntaBorrarTrabajos(Iterable<String> ids, {required String nombre}) {
  final sub = {for (final id in ids) ...store.descendientes(id).map((h) => h.id)}.difference(ids.toSet()).length;
  final aviso = switch (sub) {
    0 => '',
    1 => ' También se eliminará su subtrabajo.',
    _ => ' También se eliminarán sus $sub subtrabajos.',
  };
  return '¿Eliminar $nombre?$aviso';
}

/// Pide confirmar una acción. Por defecto es borrar (papelera roja, «Eliminar», «No se puede deshacer»); lo que
/// no borra pasa `destructivo: false` con su [accion] e [icono] y, si quiere, una [nota] bajo el texto.
Future<bool> confirmar(
  BuildContext context,
  String texto, {
  String accion = 'Eliminar',
  IconData icono = Icons.delete_outline_rounded,
  bool destructivo = true,
  String? nota,
  String cancelar = 'Cancelar',
  List<(IconData, String)> lista = const [],
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (destructivo ? P.rojo : P.morado).withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono, color: destructivo ? P.rojo : P.morado, size: 26),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                // Lo que se va con ello, cada cosa con su icono: «[icono] 3 órdenes de trabajo».
                if (lista.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Se borrarán también', textAlign: TextAlign.center, style: TextStyle(color: P.textoSuave, fontSize: 13)),
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (icono, texto) in lista)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icono, size: 18, color: P.textoSuave),
                                const SizedBox(width: 8),
                                Text(texto, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  nota ?? (destructivo ? 'No se puede deshacer.' : ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: P.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: destructivo ? P.rojo : P.morado),
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(accion),
                ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: P.textoSuave),
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(cancelar),
                ),
              ],
            ),
          ),
        ),
      ),
    ) ??
    false;

// ── Selección múltiple ───────────────────────────────────

/// Círculo que se marca con un tick al seleccionar un elemento.
class CirculoSeleccion extends StatelessWidget {
  final bool seleccionado;
  const CirculoSeleccion(this.seleccionado, {super.key});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: seleccionado ? P.morado : P.superficie,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: seleccionado ? P.morado : P.textoSuave.withValues(alpha: .6), width: 1.5),
    ),
    child: seleccionado ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
  );
}

/// Bloque en modo selección: tick arriba a la derecha y borde de color si está elegido.
class MarcaSeleccion extends StatefulWidget {
  final bool activo, seleccionado;
  final Widget child;

  /// Sin selección activa, al pasar el ratón aparece el check arriba a la derecha; pulsarlo entra en
  /// el modo selección con esta tarjeta marcada.
  final VoidCallback? onMarcar;
  const MarcaSeleccion({
    super.key,
    required this.activo,
    required this.seleccionado,
    required this.child,
    this.onMarcar,
  });

  @override
  State<MarcaSeleccion> createState() => _MarcaSeleccionState();
}

class _MarcaSeleccionState extends State<MarcaSeleccion> {
  bool encima = false;

  @override
  Widget build(BuildContext context) {
    final verCheck = widget.activo || (encima && widget.onMarcar != null);
    return MouseRegion(
      onEnter: (_) => setState(() => encima = true),
      onExit: (_) => setState(() => encima = false),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(P.radio),
              border: Border.all(color: widget.activo && widget.seleccionado ? P.morado : Colors.transparent, width: 2),
            ),
            child: widget.child,
          ),
          Positioned(
            top: 12,
            right: 12,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: verCheck ? 1 : 0,
              child: IgnorePointer(
                ignoring: !verCheck || widget.activo,
                child: Tooltip(
                  message: 'Seleccionar',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(onTap: widget.onMarcar, child: CirculoSeleccion(widget.seleccionado)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de la cabecera de una lista (a la izquierda de "Nombre"): entra o sale del modo selección.
class BotonSeleccionLista extends StatelessWidget {
  final bool activo;
  final VoidCallback onTap;
  const BotonSeleccionLista({super.key, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: activo ? 'Salir de la selección' : 'Seleccionar',
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: activo ? 'Salir de la selección' : 'Seleccionar',
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        style: IconButton.styleFrom(
          fixedSize: const Size(32, 32),
          minimumSize: const Size(32, 32),
          maximumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          hoverColor: P.hover,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
        ),
        icon: Icon(Icons.checklist_rounded, size: 22, color: activo ? P.morado : P.textoSuave),
      ),
    ),
  );
}

/// Atenúa e inutiliza lo que no se puede tocar mientras se selecciona.
class Atenuado extends StatelessWidget {
  final bool activo;
  final Widget child;
  const Atenuado({super.key, required this.activo, required this.child});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: activo,
    child: AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: activo ? .3 : 1, child: child),
  );
}

/// Barra flotante del modo selección: cuántos hay, seleccionar todo, eliminar y salir.
class BarraSeleccion extends StatelessWidget {
  final int seleccionados, total;
  final String nombre; // en plural: "trabajadores", "clientes"
  final VoidCallback onTodos, onEliminar, onSalir;

  /// Acciones propias de lo que se selecciona (trabajos, trabajadores, clientes), antes de «Eliminar».
  final List<Widget> acciones;

  /// Texto del botón rojo (Pultec cancela las OT en vez de borrarlas).
  final String textoEliminar;

  /// En vez del botón rojo, este (p. ej. un menú para elegir qué se quita).
  final Widget? eliminar;
  const BarraSeleccion({
    super.key,
    this.acciones = const [],
    this.eliminar,
    this.textoEliminar = 'Eliminar',
    required this.seleccionados,
    required this.total,
    required this.nombre,
    required this.onTodos,
    required this.onEliminar,
    required this.onSalir,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: P.tinta,
    elevation: 8,
    shadowColor: Colors.black26,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radio)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            seleccionados == 0 ? 'Toca para seleccionar $nombre' : '$seleccionados seleccionados',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(width: 12),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: onTodos,
            child: Text(seleccionados == total && total > 0 ? 'Ninguno' : 'Seleccionar todo'),
          ),
          const SizedBox(width: 4),
          ...acciones,
          eliminar ??
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: P.rojo),
                onPressed: seleccionados == 0 ? null : onEliminar,
                child: Text(textoEliminar),
              ),
          IconButton(
            tooltip: 'Salir de la selección',
            onPressed: onSalir,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

/// Lo que una [Tabla] necesita para la selección múltiple: el botón de la cabecera, la columna y la casilla
/// de cada fila, y qué hace tocar una fila (marcarla si se está seleccionando; si no, abrirla).
class Seleccionable {
  final bool activo;
  final Set<String> ids;
  final VoidCallback _modo;
  final ValueChanged<String> _alternar;
  const Seleccionable._(this.activo, this.ids, this._modo, this._alternar);

  Widget get cabecera => BotonSeleccionLista(activo: activo, onTap: _modo);
  List<Col> get columna => activo ? const [Col('', ancho: 36, cabecera: SizedBox())] : const [];
  List<Widget> casilla(String id) => activo ? [CirculoSeleccion(ids.contains(id))] : const [];
  void tocar(String id, VoidCallback abrir) => activo ? _alternar(id) : abrir();
}

/// Selección múltiple de una lista vertical, como en Órdenes de trabajo y Técnicos: [builder] pinta la
/// tabla con el [Seleccionable] y aquí va la barra flotante para seleccionar todo y eliminar.
class SeleccionMultiple extends StatefulWidget {
  /// Ids de las filas visibles, en orden.
  final List<String> ids;
  final String singular, plural;
  final ValueChanged<String> borrar;

  /// Aviso al confirmar según lo elegido (p. ej. qué más se borra con ellos).
  final String? Function(List<String> ids)? nota;

  /// Qué más se borra con lo elegido, cada cosa con su icono (sale en el aviso en una lista).
  final List<(IconData, String)> Function(List<String> ids)? lista;

  /// Acciones propias antes de «Eliminar» (p. ej. pausar mantenimientos), con los ids elegidos.
  final List<Widget> Function(List<String> ids)? acciones;
  final Widget Function(BuildContext context, Seleccionable s) builder;
  const SeleccionMultiple({
    super.key,
    this.acciones,
    required this.ids,
    required this.singular,
    required this.plural,
    required this.borrar,
    required this.builder,
    this.nota,
    this.lista,
  });

  @override
  State<SeleccionMultiple> createState() => _SeleccionMultipleState();
}

class _SeleccionMultipleState extends State<SeleccionMultiple> {
  bool activo = false;
  final sel = <String>{};

  void _salir() => setState(() {
    activo = false;
    sel.clear();
  });

  Future<void> _eliminar() async {
    final ids = sel.where(widget.ids.contains).toList();
    final que = '${ids.length} ${ids.length == 1 ? widget.singular : widget.plural}';
    final aviso = widget.nota?.call(ids);
    final lista = widget.lista?.call(ids) ?? const [];
    final nota = [?aviso, if (lista.isNotEmpty) 'También del calendario y del histórico.', 'Podrás deshacerlo.'];
    if (!await confirmar(context, '¿Eliminar $que?', lista: lista, nota: nota.join(' '))) return;
    store.deshacible('Has borrado $que', () => ids.forEach(widget.borrar));
    _salir();
  }

  @override
  Widget build(BuildContext context) {
    final n = sel.where(widget.ids.contains).length;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.builder(
          context,
          Seleccionable._(
            activo,
            sel,
            () => activo ? _salir() : setState(() => activo = true),
            (id) => setState(() => sel.contains(id) ? sel.remove(id) : sel.add(id)),
          ),
        ),
        if (activo)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: BarraSeleccion(
                acciones: n == 0 || widget.acciones == null
                    ? const []
                    : widget.acciones!(sel.where(widget.ids.contains).toList()),
                seleccionados: n,
                total: widget.ids.length,
                nombre: widget.plural,
                onTodos: () => setState(() => n == widget.ids.length ? sel.clear() : sel.addAll(widget.ids)),
                onEliminar: _eliminar,
                onSalir: _salir,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Rendimiento ──────────────────────────────────────────

/// Como LayoutBuilder, pero solo vuelve a construir su contenido cuando cambia [clave] (un umbral,
/// el nº de columnas, el alto…). Al redimensionar en tiempo real (barra lateral, separador del mapa)
/// el contenido se recoloca sin reconstruirse en cada fotograma. Lo que dependa del ancho exacto
/// debe resolverse con maquetación (Expanded, Flexible, [Rejilla]), no con el número del builder.
class SegunTamano extends StatefulWidget {
  final Object? Function(BoxConstraints box) clave;
  final Widget Function(BuildContext context, BoxConstraints box) builder;
  const SegunTamano({super.key, required this.clave, required this.builder});

  @override
  State<SegunTamano> createState() => _SegunTamanoState();
}

class _SegunTamanoState extends State<SegunTamano> {
  Object? _clave;
  Widget? _hijo;

  @override
  Widget build(BuildContext context) {
    // Si el padre se reconstruye (datos nuevos), el contenido también; un cambio de tamaño, solo si cambia la clave.
    _hijo = null;
    return LayoutBuilder(
      builder: (context, box) {
        final k = widget.clave(box);
        if (_hijo == null || k != _clave) {
          _clave = k;
          _hijo = widget.builder(context, box);
        }
        return _hijo!;
      },
    );
  }
}

/// Rejilla desplazable de tarjetas: tantas columnas como quepan de [anchoMin] y, por filas, solo
/// construye las visibles (ListView.builder). Para listas que pueden crecer (clientes, trabajadores, tareas).
class ListaRejilla extends StatelessWidget {
  final double anchoMin, hueco;
  final int total;
  final Widget Function(int i) item;
  final EdgeInsets padding;
  const ListaRejilla({
    super.key,
    required this.anchoMin,
    required this.total,
    required this.item,
    this.hueco = 16,
    this.padding = const EdgeInsets.only(bottom: 80),
  });

  int _cols(BoxConstraints box) => max(1, ((box.maxWidth + hueco) / (anchoMin + hueco)).floor());

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: _cols,
    builder: (context, box) {
      final cols = _cols(box);
      return ListView.builder(
        padding: padding,
        itemCount: (total / cols).ceil(),
        itemBuilder: (_, f) => Padding(
          padding: EdgeInsets.only(bottom: hueco),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) SizedBox(width: hueco),
                Expanded(child: f * cols + j < total ? item(f * cols + j) : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Rejilla de [columnas] columnas iguales hecha con filas de Expanded: el ancho de cada tarjeta lo
/// resuelve la maquetación, así redimensionar no reconstruye las tarjetas.
class Rejilla extends StatelessWidget {
  final int columnas;
  final double hueco;
  final List<Widget> children;

  /// Las tarjetas de cada fila, todas del alto de la más alta (p. ej. si una etiqueta ocupa dos líneas). Solo para
  /// hijos que saben medirse solos (sin LayoutBuilder dentro).
  final bool igualarAlto;
  const Rejilla({super.key, required this.columnas, required this.children, this.hueco = 14, this.igualarAlto = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i += columnas) ...[
        if (i > 0) SizedBox(height: hueco),
        _fila([
          for (var j = 0; j < columnas; j++) ...[
            if (j > 0) SizedBox(width: hueco),
            Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
          ],
        ]),
      ],
    ],
  );

  Widget _fila(List<Widget> hijos) => igualarAlto
      ? IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
        )
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: hijos);
}

/// Borde de rayas alrededor de un rectángulo redondeado (foto vacía de formulario, guía de Inicio).
class BordeDiscontinuo extends CustomPainter {
  final Color color;
  final BorderRadius radio;
  final double separacion;
  const BordeDiscontinuo(this.color, this.radio, {this.separacion = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final camino = Path()..addRRect(radio.toRRect(Offset.zero & size).deflate(.7));
    for (final m in camino.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 4 + separacion) {
        canvas.drawPath(m.extractPath(d, min(d + 4, m.length)), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(BordeDiscontinuo old) => old.color != color || old.radio != radio || old.separacion != separacion;
}

// ── Menús ──────────────────────────────────────────────

/// El menú de [BotonMenu] abierto bajo [ancla] (en coordenadas globales), sin un widget por botón: para rejillas
/// que se pintan de una vez (una celda tocada abre sus opciones). Devuelve la opción elegida o null.
Future<T?> abrirMenu<T>(BuildContext context, Rect ancla, List<(T, Widget)> opciones, {T? seleccionado}) {
  final capa = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final arriba = capa.globalToLocal(ancla.bottomLeft + const Offset(0, 4));
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(arriba & Size(ancla.width, 0), Offset.zero & capa.size),
    items: [for (final (valor, hijo) in opciones) _OpcionMenu(valor, valor == seleccionado, hijo)],
  );
}

/// Botón que abre un menú debajo. Regla para todos los menús de la app:
/// - al pasar el ratón, fondo suave redondeado (sin el destello cuadrado de PopupMenuButton) y cursor de mano;
/// - al abrir, el fondo se apaga despacio y la opción actual sale resaltada y con el foco;
/// - con las flechas ↑↓ se recorre, Intro o espacio elige y Esc cierra;
/// - al cerrar no vuelve el fondo hasta que el ratón sale y entra otra vez.
class BotonMenu<T> extends StatefulWidget {
  final String tooltip;
  final List<(T, Widget)> opciones;
  final T? seleccionado;
  final ValueChanged<T> onSelected;
  final Widget child;
  final bool resaltarHover;
  const BotonMenu({
    super.key,
    required this.tooltip,
    required this.opciones,
    required this.onSelected,
    required this.child,
    this.seleccionado,
    this.resaltarHover = true,
    this.relleno = const EdgeInsets.symmetric(horizontal: 8),
  });

  /// Sin relleno cuando hace de campo de formulario, para alinearse con los demás campos.
  final EdgeInsets relleno;

  @override
  State<BotonMenu<T>> createState() => _BotonMenuState<T>();
}

class _BotonMenuState<T> extends State<BotonMenu<T>> {
  bool hover = false, abierto = false;

  Future<void> _abrir() async {
    final caja = context.findRenderObject()! as RenderBox;
    final capa = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final abajo = caja.localToGlobal(caja.size.bottomLeft(const Offset(0, 4)), ancestor: capa);
    setState(() => abierto = true);
    final v = await showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(abajo & Size(caja.size.width, 0), Offset.zero & capa.size),
      items: [for (final (valor, hijo) in widget.opciones) _OpcionMenu(valor, valor == widget.seleccionado, hijo)],
    );
    if (!mounted) return;
    // Sin fondo al cerrar: vuelve solo al salir y entrar otra vez con el ratón.
    setState(() {
      abierto = false;
      hover = false;
    });
    if (v != null) widget.onSelected(v);
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: abierto ? '' : widget.tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _abrir,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: widget.relleno,
          decoration: BoxDecoration(
            color: widget.resaltarHover && hover && !abierto ? P.hover : P.hover.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(P.radioControl),
          ),
          child: widget.child,
        ),
      ),
    ),
  );
}

/// Opción de [BotonMenu]: la actual empieza resaltada y con el foco; ↑↓ pasan a la anterior o la siguiente.
/// Solo hay un resaltado, el del foco: pasar el ratón por una opción le da el foco (no se suman hover y foco).
class _OpcionMenu<T> extends PopupMenuEntry<T> {
  final T valor;
  final bool actual;
  final Widget child;
  const _OpcionMenu(this.valor, this.actual, this.child);

  @override
  double get height => 40;

  @override
  bool represents(T? value) => value == valor;

  @override
  State<_OpcionMenu<T>> createState() => _OpcionMenuState<T>();
}

class _OpcionMenuState<T> extends State<_OpcionMenu<T>> {
  final foco = FocusNode();

  @override
  void dispose() {
    foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    // En web las flechas desplazan la página por defecto: aquí mueven el foco entre opciones.
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
      SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        focusNode: foco,
        autofocus: widget.actual,
        borderRadius: BorderRadius.circular(P.radioControl - 2),
        focusColor: P.hover,
        hoverColor: Colors.transparent,
        onHover: (dentro) {
          if (dentro) foco.requestFocus();
        },
        splashFactory: NoSplash.splashFactory,
        onTap: () => Navigator.pop(context, widget.valor),
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 14, fontWeight: widget.actual ? FontWeight.w600 : FontWeight.w400),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

// ── Avance al pasar el ratón ──────────────────────────────

/// Tarjeta blanca que aparece al dejar el ratón encima (sin pulsar), con una puntita hacia el elemento:
/// lo mínimo para saber qué es sin abrirlo. Debajo del elemento, o encima si está en la mitad de abajo
/// de la pantalla. Se va al salir o al pulsar (el clic abre la ficha completa).
class Avance extends StatefulWidget {
  final Widget child;
  final WidgetBuilder contenido;
  const Avance({super.key, required this.child, required this.contenido});

  @override
  State<Avance> createState() => _AvanceState();
}

class _AvanceState extends State<Avance> {
  final _control = OverlayPortalController();
  final _enlace = LayerLink();
  Timer? _espera;
  bool _arriba = false;

  void _mostrar() {
    final caja = context.findRenderObject() as RenderBox?;
    if (caja == null || !caja.attached) return;
    final y = caja.localToGlobal(caja.size.center(Offset.zero)).dy;
    setState(() => _arriba = y > MediaQuery.sizeOf(context).height / 2);
    _control.show();
  }

  void _ocultar() {
    _espera?.cancel();
    if (_control.isShowing) _control.hide();
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _enlace,
    child: OverlayPortal(
      controller: _control,
      overlayChildBuilder: (context) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _enlace,
          targetAnchor: _arriba ? Alignment.topCenter : Alignment.bottomCenter,
          followerAnchor: _arriba ? Alignment.bottomCenter : Alignment.topCenter,
          offset: Offset(0, _arriba ? -4 : 4),
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_arriba) CustomPaint(size: const Size(14, 7), painter: _Puntita(arriba: true)),
                Material(
                  color: P.superficie,
                  elevation: 10,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(P.radioControl),
                    side: BorderSide(color: P.borde),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Padding(padding: const EdgeInsets.all(12), child: widget.contenido(context)),
                  ),
                ),
                if (_arriba) CustomPaint(size: const Size(14, 7), painter: _Puntita(arriba: false)),
              ],
            ),
          ),
        ),
      ),
      child: Listener(
        onPointerDown: (_) => _ocultar(),
        child: MouseRegion(
          onEnter: (_) {
            _espera?.cancel();
            _espera = Timer(const Duration(milliseconds: 350), _mostrar);
          },
          onExit: (_) => _ocultar(),
          child: widget.child,
        ),
      ),
    ),
  );
}

/// Puntita del [Avance], del color de la tarjeta.
class _Puntita extends CustomPainter {
  final bool arriba;
  const _Puntita({required this.arriba});

  @override
  void paint(Canvas canvas, Size size) {
    final p = arriba
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(p..close(), Paint()..color = P.superficie);
    canvas.drawPath(
      arriba
          ? (Path()
              ..moveTo(0, size.height)
              ..lineTo(size.width / 2, 0)
              ..lineTo(size.width, size.height))
          : (Path()
              ..moveTo(0, 0)
              ..lineTo(size.width / 2, size.height)
              ..lineTo(size.width, 0)),
      Paint()
        ..color = P.borde
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Puntita old) => old.arriba != arriba;
}

/// Tabla más ancha que la vista: se desplaza en horizontal con una barra siempre visible justo debajo de
/// la fila de títulos, para arrastrarla con el ratón. Si cabe, no hay barra ni desplazamiento.
class DesplazarTabla extends StatefulWidget {
  final double ancho;
  final Widget child;
  const DesplazarTabla({super.key, required this.ancho, required this.child});

  @override
  State<DesplazarTabla> createState() => _DesplazarTablaState();
}

class _DesplazarTablaState extends State<DesplazarTabla> {
  final _control = ScrollController();

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final sobra = widget.ancho > box.maxWidth;
      final contenido = SizedBox(width: sobra ? widget.ancho : box.maxWidth, child: widget.child);
      if (!sobra) return contenido;
      return RawScrollbar(
        controller: _control,
        thumbVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.top,
        // Debajo de la cabecera de la tabla (42 de alto más su línea).
        padding: const EdgeInsets.only(top: 44, left: 8, right: 8),
        thickness: 8,
        radius: const Radius.circular(4),
        thumbColor: P.textoSuave.withValues(alpha: .45),
        child: SingleChildScrollView(controller: _control, scrollDirection: Axis.horizontal, child: contenido),
      );
    },
  );
}


/// Fondo de las pantallas de entrada (acceso, nombre de la empresa), como el de la landing: blanco con una
/// cuadrícula de 64 px muy suave que se desvanece hacia los bordes. Bajo el cursor (fuera de la tarjeta), las
/// líneas se tiñen apenas de morado, como las tarjetas de la landing.
class FondoMarca extends StatefulWidget {
  const FondoMarca({super.key});

  @override
  State<FondoMarca> createState() => _FondoMarcaState();
}

class _FondoMarcaState extends State<FondoMarca> {
  // El cursor en un ValueNotifier: moverlo solo repinta el brillo, sin reconstruir nada.
  final _cursor = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: (e) => _cursor.value = e.localPosition,
    onExit: (_) => _cursor.value = null,
    child: ColoredBox(
      color: P.superficie,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const RadialGradient(
              center: Alignment(0, -.4),
              radius: .75,
              colors: [Colors.white, Colors.transparent],
              stops: [.2, 1],
            ).createShader(r),
            child: RepaintBoundary(child: CustomPaint(painter: _Cuadricula(P.texto.withValues(alpha: .05)))),
          ),
          RepaintBoundary(child: CustomPaint(painter: _BrilloCuadricula(_cursor, P.morado))),
        ],
      ),
    ),
  );
}

/// Las líneas de la cuadrícula cerca del cursor, en morado que se apaga al alejarse.
class _BrilloCuadricula extends CustomPainter {
  final ValueNotifier<Offset?> cursor;
  final Color color;
  _BrilloCuadricula(this.cursor, this.color) : super(repaint: cursor);

  static const _radio = 170.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = cursor.value;
    if (c == null) return;
    final p = Paint()
      ..strokeWidth = 1
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: _radio));
    const lado = 64.0;
    for (var x = (size.width / 2) % lado; x < size.width; x += lado) {
      if ((x - c.dx).abs() < _radio) canvas.drawLine(Offset(x, c.dy - _radio), Offset(x, c.dy + _radio), p);
    }
    for (var y = (size.height / 2) % lado; y < size.height; y += lado) {
      if ((y - c.dy).abs() < _radio) canvas.drawLine(Offset(c.dx - _radio, y), Offset(c.dx + _radio, y), p);
    }
  }

  @override
  bool shouldRepaint(_BrilloCuadricula o) => o.color != color || o.cursor != cursor;
}

/// Cuadrícula como la de la landing: líneas finas cada 64 px, centrada.
class _Cuadricula extends CustomPainter {
  final Color color;
  const _Cuadricula(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const lado = 64.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = (size.width / 2) % lado; x < size.width; x += lado) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = (size.height / 2) % lado; y < size.height; y += lado) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Cuadricula o) => o.color != color;
}

/// Cambio de vista suave: al cambiar [clave], la nueva entra con opacidad y un poco desde abajo y la anterior se
/// desvanece (p. ej. al entrar en un activo o volver a la lista).
class TransicionVista extends StatelessWidget {
  final Object? clave;
  final Widget child;
  const TransicionVista({super.key, required this.clave, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 160),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (actual, anteriores) =>
        Stack(fit: StackFit.expand, alignment: Alignment.topLeft, children: [...anteriores, ?actual]),
    transitionBuilder: (hijo, a) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .015), end: Offset.zero).animate(a),
        child: hijo,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(clave), child: child),
  );
}

/// Cambio de vista suave y con sentido: la que entra llega desde un lado mientras la anterior se aparta hacia el
/// contrario. Empieza cuando la vista nueva ya está pintada, para que no dé un salto si tarda en construirse.
class TransicionLateral extends StatefulWidget {
  /// Al cambiar, se anima el paso a la vista nueva.
  final Object clave;

  /// Sitio de la vista: si sube, entra por la derecha; si baja, por la izquierda. Igual o null: fundido.
  final int? orden;
  final Widget child;
  const TransicionLateral({super.key, required this.clave, this.orden, required this.child});

  @override
  State<TransicionLateral> createState() => _TransicionLateralState();
}

class _TransicionLateralState extends State<TransicionLateral> with SingleTickerProviderStateMixin {
  late final _paso = AnimationController(vsync: this, duration: const Duration(milliseconds: 460), value: 1)
    ..addStatusListener((e) {
      if (e == AnimationStatus.completed && _saliente != null) setState(() => _saliente = null);
    });
  Widget? _saliente;
  int _numero = 0, _sentido = 0;

  @override
  void didUpdateWidget(TransicionLateral old) {
    super.didUpdateWidget(old);
    if (old.clave == widget.clave) return;
    _numero++;
    // Con «reducir movimiento», el cambio es directo.
    if (MediaQuery.disableAnimationsOf(context)) {
      _saliente = null;
      _paso.value = 1;
      return;
    }
    final antes = old.orden, ahora = widget.orden;
    _sentido = antes == null || ahora == null ? 0 : (ahora - antes).sign;
    _saliente = old.child;
    _paso.value = 0;
    // Primero se pinta la vista nueva (aún invisible) y entonces arranca.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _paso.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _paso.dispose();
    super.dispose();
  }

  /// La misma envoltura para la que entra y la que sale: así la que sale conserva su estado.
  Widget _capa(int numero, Widget child, {required bool entra}) {
    final movimiento = _paso.drive(CurveTween(curve: Curves.easeOutCubic));
    final desde = _sentido == 0 ? const Offset(0, .012) : Offset(.07 * _sentido, 0);
    return KeyedSubtree(
      key: ValueKey(numero),
      child: IgnorePointer(
        ignoring: !entra,
        child: FadeTransition(
          opacity: entra
              ? _paso.drive(CurveTween(curve: const Interval(.2, 1, curve: Curves.easeOut)))
              : _paso.drive(Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: const Interval(0, .4)))),
          child: SlideTransition(
            position: movimiento.drive(
              entra
                  ? Tween(begin: desde, end: Offset.zero)
                  : Tween(begin: Offset.zero, end: Offset(-.05 * _sentido, 0)),
            ),
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (_saliente case final anterior?) _capa(_numero - 1, anterior, entra: false),
        _capa(_numero, widget.child, entra: true),
      ],
    ),
  );
}
