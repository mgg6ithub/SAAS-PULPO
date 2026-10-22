import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

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
    final fg = solido ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: solido ? 7 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: solido ? color : color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(solido ? 6 : 99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (punto) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
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

/// Píldora gris con un punto de color delante: "● Caldera". Para categorías.
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const Etiqueta(this.texto, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(20)),
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
  const HoverCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.width});

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
            color: P.superficie,
            borderRadius: BorderRadius.circular(P.radio),
            border: Border.all(color: activo ? P.morado.withValues(alpha: .45) : P.borde),
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

  /// Icono de color junto al título (el toque Pulpo).
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
    decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(P.radio)),
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
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(
            children: [
              if (icono != null) ...[IconoCuadro(icono!, colorIcono ?? P.morado, size: 30), const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontFamily: P.titulos,
                        fontSize: 16,
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
        Divider(height: 1, color: P.borde),
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
  final Widget lider;
  final String titulo;
  final String? subtitulo;
  final Widget? derecha;
  final VoidCallback? onTap;
  const FilaLista({super.key, required this.lider, required this.titulo, this.subtitulo, this.derecha, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      hoverColor: P.hoverFila,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
  const Cabecera({super.key, required this.titulo, this.subtitulo, this.acciones = const [], this.lider});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
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
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: acciones),
      ],
    ),
  );
}

/// Botón primario con la tecla rápida en un recuadro, como "Nuevo contacto  N" de Holded.
class BotonPrimario extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback onPressed;
  final String? tecla;
  const BotonPrimario(this.texto, {super.key, this.icono = Icons.add_rounded, required this.onPressed, this.tecla});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(texto),
        if (tecla != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(tecla!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
  const BotonAccion(this.texto, {super.key, required this.onPressed, this.icono, this.tooltip, this.color});

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
    final boton = SizedBox(
      height: 40,
      child: icono == null
          ? OutlinedButton(style: style, onPressed: onPressed, child: Text(texto))
          : OutlinedButton.icon(style: style, onPressed: onPressed, icon: Icon(icono, size: 19), label: Text(texto)),
    );
    return tooltip == null ? boton : Tooltip(message: tooltip!, child: boton);
  }
}

class Buscador extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;
  const Buscador({super.key, required this.hint, required this.onChanged, this.width = 240});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 40,
    // expands: el campo llena los 40 de alto, igual que botones y pestañas.
    child: TextField(
      onChanged: onChanged,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: P.textoSuave, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: P.textoSuave),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
      ),
    ),
  );
}

/// Barra única de arriba de cada vista (como la del Itinerario): a la izquierda título y filtros; a la
/// derecha buscador y acciones, todo de 40 de alto. Nunca se parte en dos filas: si no cabe, se desplaza.
class BarraVista extends StatelessWidget {
  final List<Widget> izquierda, derecha;
  const BarraVista({super.key, required this.izquierda, required this.derecha});

  List<Widget> _con(List<Widget> ws, double hueco) => [
    for (final (i, w) in ws.indexed) ...[if (i > 0) SizedBox(width: hueco), w],
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.maxWidth),
        child: IntrinsicWidth(
          child: Row(
            children: [..._con(izquierda, 14), const Spacer(), const SizedBox(width: 16), ..._con(derecha, 8)],
          ),
        ),
      ),
    ),
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
    style: TextStyle(fontFamily: P.titulos, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.6),
  );
}

/// Selector segmentado (como el de iOS): opciones de igual ancho y una pastilla blanca que se desliza
/// hasta la elegida. Siempre 40 de alto, como el resto de controles.
class Pestanas extends StatelessWidget {
  final List<String> opciones;
  final int seleccion;
  final ValueChanged<int> onChanged;
  const Pestanas({super.key, required this.opciones, required this.seleccion, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final estilo = DefaultTextStyle.of(context).style.merge(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
    final escala = MediaQuery.textScalerOf(context);
    // Ancho de cada opción: el del texto más largo (mismo ancho para todas, así la pastilla solo se desplaza).
    var mayor = 0.0;
    for (final o in opciones) {
      final tp = TextPainter(
        text: TextSpan(text: o, style: estilo),
        textDirection: TextDirection.ltr,
        textScaler: escala,
        maxLines: 1,
      )..layout();
      mayor = max(mayor, tp.width);
    }
    final w = mayor.ceilToDouble() + 28;
    final valida = seleccion >= 0 && seleccion < opciones.length;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(P.radioControl)),
      child: SizedBox(
        width: w * opciones.length,
        child: Stack(
          children: [
            if (valida)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: seleccion * w,
                top: 0,
                bottom: 0,
                width: w,
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
                        width: w,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: estilo.copyWith(color: i == seleccion ? P.texto : P.textoSuave),
                            child: Text(o, maxLines: 1),
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
  const Vacio({super.key, required this.icono, required this.texto, this.titulo, this.accion});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(18)),
            child: Icon(icono, color: P.textoSuave.withValues(alpha: .6), size: 28),
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
        ],
      ),
    ),
  );
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
  const Col(this.titulo, {this.flex = 1, this.ancho, this.derecha = false, this.cabecera});
}

/// Tabla densa: cabecera gris pequeña, filas de ~56 px, sin rejilla y con la fila resaltada al pasar
/// el ratón. Las columnas se ensanchan o estrechan arrastrando su borde en la cabecera (como en Windows).
class Tabla extends StatefulWidget {
  final List<Col> columnas;
  final int filas;
  final List<Widget> Function(int i) celdas;
  final void Function(int i)? onTap;
  final Widget? pie;
  final Widget? seleccionCabecera;
  const Tabla({
    super.key,
    required this.columnas,
    required this.filas,
    required this.celdas,
    this.onTap,
    this.pie,
    this.seleccionCabecera,
  });

  @override
  State<Tabla> createState() => _TablaState();
}

class _TablaState extends State<Tabla> {
  /// Anchos elegidos arrastrando, por título de columna (las columnas pueden aparecer o no según el ancho).
  final anchos = <String, double>{};
  final _claves = <String, GlobalKey>{};
  final _lienzo = GlobalKey();
  int? _columnaArrastrando;
  final _orden = <String>[];

  Widget _celda(Col c, Widget w, {GlobalKey? clave, bool inicio = false}) {
    final contenido = clave == null && (c.titulo.isEmpty || inicio) && widget.seleccionCabecera != null
        ? Transform.translate(offset: const Offset(-4, 0), child: w)
        : w;
    final hijo = Align(
      key: clave,
      alignment: c.derecha ? Alignment.centerRight : Alignment.centerLeft,
      child: contenido,
    );
    final fijo = anchos[c.titulo] ?? c.ancho;
    return fijo != null ? SizedBox(width: fijo, child: hijo) : Expanded(flex: c.flex, child: hijo);
  }

  @override
  Widget build(BuildContext context) {
    for (final (i, c) in widget.columnas.indexed) {
      if (_orden.contains(c.titulo)) continue;
      final siguiente = widget.columnas.skip(i + 1).where((c) => _orden.contains(c.titulo)).firstOrNull;
      if (siguiente == null) {
        _orden.add(c.titulo);
      } else {
        _orden.insert(_orden.indexOf(siguiente.titulo), c.titulo);
      }
    }
    final columnas = [...widget.columnas]
      ..sort((a, b) {
        if (a.titulo.isEmpty) return b.titulo.isEmpty ? 0 : -1;
        if (b.titulo.isEmpty) return 1;
        return _orden.indexOf(a.titulo).compareTo(_orden.indexOf(b.titulo));
      });
    return Container(
      decoration: BoxDecoration(color: P.superficie, borderRadius: BorderRadius.circular(P.radio)),
      // Borde por encima del contenido: si no, las cabeceras lo tapan en las esquinas.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(P.radio),
        border: Border.all(color: P.borde),
      ),
      clipBehavior: Clip.antiAlias,
      // Pocas filas: la tabla mide lo que su contenido. Muchas: ocupa el alto y solo construye las visibles.
      child: CustomPaint(
        key: _lienzo,
        foregroundPainter: _columnaArrastrando == null
            ? null
            : _GuiasColumna(
                columna: _claves[columnas[_columnaArrastrando!].titulo]!,
                lienzo: _lienzo,
                primera: _columnaArrastrando == 0,
                color: P.morado,
              ),
        child: Column(
          mainAxisSize: widget.filas > 15 ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  color: P.cabeceraTabla,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  height: 42,
                  child: Row(
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
                                        derecha: c.derecha,
                                        onIntercambiar: (origen) => setState(() {
                                          final desde = _orden.indexOf(origen);
                                          final hasta = _orden.indexOf(c.titulo);
                                          _orden[desde] = c.titulo;
                                          _orden[hasta] = origen;
                                        }),
                                      ),
                                    ),
                                  ),
                                  // Asa para redimensionar (no en la última ni en las columnas sin título).
                                  if (j < columnas.length - 1 && c.titulo.isNotEmpty)
                                    _AsaColumna(
                                      onInicio: () {
                                        final siguiente = columnas[j + 1];
                                        final izquierda =
                                            _claves[c.titulo]?.currentContext?.findRenderObject() as RenderBox?;
                                        final derecha =
                                            _claves[siguiente.titulo]?.currentContext?.findRenderObject() as RenderBox?;
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
                shrinkWrap: widget.filas <= 15,
                itemCount: widget.filas,
                separatorBuilder: (_, _) => Divider(height: 1, color: P.borde),
                itemBuilder: (_, i) {
                  final cs = widget.celdas(i);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      hoverColor: P.hoverFila,
                      onTap: widget.onTap == null ? null : () => widget.onTap!(i),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: Row(
                            children: [
                              for (final c in columnas)
                                _celda(c, cs[widget.columnas.indexOf(c)], inicio: c == columnas.first),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.pie != null) ...[
              Divider(height: 1, color: P.borde),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: widget.pie),
            ],
          ],
        ),
      ),
    );
  }
}

/// Título arrastrable; el separador de anchura queda fuera de su zona de arrastre.
class _TituloColumna extends StatefulWidget {
  final String titulo;
  final bool derecha;
  final ValueChanged<String> onIntercambiar;
  const _TituloColumna({required this.titulo, required this.derecha, required this.onIntercambiar});

  @override
  State<_TituloColumna> createState() => _TituloColumnaState();
}

class _TituloColumnaState extends State<_TituloColumna> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) => DragTarget<String>(
    onWillAcceptWithDetails: (d) => d.data != widget.titulo,
    onAcceptWithDetails: (d) => widget.onIntercambiar(d.data),
    builder: (context, candidatos, rechazados) => MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: Draggable<String>(
        data: widget.titulo,
        axis: Axis.horizontal,
        feedback: Material(
          color: P.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(P.radioControl),
            side: BorderSide(color: P.morado),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              widget.titulo,
              style: TextStyle(color: P.morado, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: .35, child: _contenido(false)),
        child: Tooltip(
          message: 'Arrastrar para intercambiar ${widget.titulo}',
          child: Semantics(
            label: 'Columna ${widget.titulo}, arrastrar para intercambiar',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              color: candidatos.isEmpty ? Colors.transparent : P.hoverFila,
              child: _contenido(_encima || candidatos.isNotEmpty),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _contenido(bool mostrarAsa) => SizedBox(
    height: 42,
    child: Row(
      children: [
        Expanded(
          child: Text(
            widget.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.derecha ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: P.textoSuave),
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
  final GlobalKey columna, lienzo;
  final bool primera;
  final Color color;
  _GuiasColumna({required this.columna, required this.lienzo, required this.primera, required this.color});

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
  const SelectorVista({super.key, required this.lista, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(P.radioControl)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (v, i, tip) in [
          (true, Icons.view_list_rounded, 'Lista'),
          (false, Icons.grid_view_rounded, 'Bloques'),
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
        message: 'Sin trabajador asignado',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: P.borde, width: 1.5),
          ),
          child: Icon(Icons.person_outline_rounded, size: size * .55, color: P.textoSuave),
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
  if (!t.activa) return const Pill('Pausada', P.gris, punto: true);
  if (t.proximo == null) return const Pill('Sin fecha', P.gris, punto: true);
  final n = diasHasta(t.proximo!);
  if (n < 0) return const Pill('Vencida', P.rojo, punto: true);
  if (n == 0) return Pill('Hoy', P.morado, punto: true);
  if (n <= 7) return const Pill('Pronto', P.ambar, punto: true);
  return const Pill('Al día', P.verde, punto: true);
}

/// Píldora con el estado del próximo mantenimiento.
Widget pillVencimiento(Tarea t) {
  if (t.esPlantilla) return Pill(t.periodicidad.etiqueta, P.gris, icono: Icons.repeat_rounded);
  if (t.proximo == null) return const Pill('Sin fecha', P.gris, icono: Icons.event_outlined);
  final n = diasHasta(t.proximo!);
  final color = n < 0 ? P.rojo : (n <= 3 ? P.ambar : P.morado);
  return Pill(relativo(t.proximo!), color, icono: n < 0 ? Icons.warning_amber_rounded : Icons.event_outlined);
}

Future<bool> confirmar(BuildContext context, String texto) async =>
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
                    decoration: BoxDecoration(color: P.rojo.withValues(alpha: .1), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, color: P.rojo, size: 26),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'No se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: P.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: P.rojo),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Eliminar'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: P.textoSuave),
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancelar'),
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
  const BarraSeleccion({
    super.key,
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: P.rojo),
            onPressed: seleccionados == 0 ? null : onEliminar,
            child: const Text('Eliminar'),
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
  const Rejilla({super.key, required this.columnas, required this.children, this.hueco = 14});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i += columnas) ...[
        if (i > 0) SizedBox(height: hueco),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < columnas; j++) ...[
              if (j > 0) SizedBox(width: hueco),
              Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
            ],
          ],
        ),
      ],
    ],
  );
}
