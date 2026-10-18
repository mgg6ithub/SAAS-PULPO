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
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .38, letterSpacing: -.2),
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
        borderRadius: BorderRadius.circular(solido ? 4 : 20),
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
                style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600),
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
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: P.texto),
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
          decoration: BoxDecoration(
            color: P.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: activo ? P.textoSuave.withValues(alpha: .4) : P.borde),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: activo ? .06 : .02),
                blurRadius: activo ? 14 : 3,
                offset: Offset(0, activo ? 4 : 1),
              ),
            ],
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
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color == null ? P.borde : Colors.transparent),
      boxShadow: color == null
          ? [BoxShadow(color: P.morado.withValues(alpha: .04), blurRadius: 8, offset: const Offset(0, 2))]
          : null,
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
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: P.borde),
      boxShadow: [BoxShadow(color: P.morado.withValues(alpha: .04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                    if (subtitulo != null) Text(subtitulo!, style: TextStyle(fontSize: 12, color: P.textoSuave)),
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
        style: TextStyle(color: P.morado, fontSize: 12.5, fontWeight: FontWeight.w600),
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    hoverColor: P.columna,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
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
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: P.textoSuave),
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
  const Cifra(this.etiqueta, this.valor, {super.key, this.nota, this.colorNota, this.color, this.tamano = 26});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(etiqueta, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
      const SizedBox(height: 4),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: valor.toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text(
          '${v.round()}',
          style: TextStyle(
            fontFamily: P.titulos,
            fontSize: tamano,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
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
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(colors: [P.tinta, Color.lerp(P.tinta, P.morado, .5)!]),
    ),
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
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                    ),
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitulo!, style: TextStyle(color: P.textoSuave, fontSize: 13)),
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

class Buscador extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;
  const Buscador({super.key, required this.hint, required this.onChanged, this.width = 240});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 36,
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: P.textoSuave, fontSize: 13.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: P.textoSuave),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
      ),
    ),
  );
}

/// Selector segmentado gris: la opción activa en blanco (Resumen | Tableros en Holded).
class Pestanas extends StatelessWidget {
  final List<String> opciones;
  final int seleccion;
  final ValueChanged<int> onChanged;
  const Pestanas({super.key, required this.opciones, required this.seleccion, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, o) in opciones.indexed)
          GestureDetector(
            onTap: () => onChanged(i),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: i == seleccion ? P.superficie : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: i == seleccion
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .08),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: i == seleccion ? P.texto : P.textoSuave,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: i == seleccion ? P.texto : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  o,
                  style: TextStyle(
                    fontSize: 13,
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
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: P.columna, shape: BoxShape.circle),
            child: Stack(
              alignment: Alignment.center,
              children: [Icon(icono, color: P.textoSuave.withValues(alpha: .55), size: 36)],
            ),
          ),
          const SizedBox(height: 14),
          if (titulo != null) ...[
            Text(titulo!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
          ],
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: P.textoSuave, fontSize: 13),
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
  const Col(this.titulo, {this.flex = 1, this.ancho, this.derecha = false});
}

/// Tabla densa de Holded: cabecera gris pequeña, filas de ~50 px, sin rejilla y con hover.
class Tabla extends StatelessWidget {
  final List<Col> columnas;
  final int filas;
  final List<Widget> Function(int i) celdas;
  final void Function(int i)? onTap;
  final Widget? pie;
  const Tabla({super.key, required this.columnas, required this.filas, required this.celdas, this.onTap, this.pie});

  Widget _celda(Col c, Widget w) {
    final hijo = Align(alignment: c.derecha ? Alignment.centerRight : Alignment.centerLeft, child: w);
    return c.ancho != null ? SizedBox(width: c.ancho, child: hijo) : Expanded(flex: c.flex, child: hijo);
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: P.borde),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: P.cabeceraTabla,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              for (final c in columnas)
                _celda(
                  c,
                  Text(
                    c.titulo,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: P.textoSuave),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: P.borde),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: filas,
            separatorBuilder: (_, _) => Divider(height: 1, color: P.borde),
            itemBuilder: (_, i) {
              final cs = celdas(i);
              return InkWell(
                hoverColor: P.columna,
                onTap: onTap == null ? null : () => onTap!(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [for (final (j, c) in columnas.indexed) _celda(c, cs[j])]),
                  ),
                ),
              );
            },
          ),
        ),
        if (pie != null) ...[
          Divider(height: 1, color: P.borde),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: pie),
        ],
      ],
    ),
  );
}

/// Texto de celda: normal, gris o en negrita.
Widget celdaTexto(String t, {bool suave = false, bool negrita = false}) => Text(
  t.isEmpty ? '—' : t,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    fontSize: 13,
    color: suave || t.isEmpty ? P.textoSuave : P.texto,
    fontWeight: negrita ? FontWeight.w600 : FontWeight.w400,
  ),
);

/// Pie de tabla: "1–12 (12)" a la izquierda, como la paginación de Holded.
Widget pieTabla(int n, String nombre) => Text('1–$n ($n $nombre)', style: TextStyle(fontSize: 12, color: P.textoSuave));

/// Barra de filtros: grupo izquierdo y derecho en los extremos; si no caben, el derecho baja de línea.
class BarraFiltros extends StatelessWidget {
  final List<Widget> izquierda, derecha;
  const BarraFiltros({super.key, required this.izquierda, required this.derecha});

  Widget _grupo(List<Widget> ws) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, w) in ws.indexed) ...[if (i > 0) const SizedBox(width: 8), w],
    ],
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [_grupo(izquierda), _grupo(derecha)],
    ),
  );
}

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
      child: SizedBox(width: 34, height: 34, child: Icon(i, size: 18, color: P.textoSuave)),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(8),
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
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text('Hoy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
    height: 36,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(8)),
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
                width: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lista == v ? P.superficie : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
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

/// Estado de una tarea como pastilla sólida: vencida, toca hoy, pronto, al día, hecha.
Widget pillEstado(Tarea t) {
  if (t.esPlantilla) return Pill('Plantilla', P.morado, icono: Icons.content_copy_rounded);
  if (!t.activa) return const Pill('Pausada', P.gris, solido: true);
  if (t.proximo == null) return const Pill('Sin fecha', P.gris, solido: true);
  final n = diasHasta(t.proximo!);
  if (n < 0) return const Pill('Vencida', P.rojo, solido: true);
  if (n == 0) return Pill('Hoy', P.morado, solido: true);
  if (n <= 7) return const Pill('Pronto', P.ambar, solido: true);
  return const Pill('Al día', P.verde, solido: true);
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
class MarcaSeleccion extends StatelessWidget {
  final bool activo, seleccionado;
  final Widget child;
  const MarcaSeleccion({super.key, required this.activo, required this.seleccionado, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activo && seleccionado ? P.morado : Colors.transparent, width: 2),
        ),
        child: child,
      ),
      if (activo) Positioned(top: 12, right: 12, child: CirculoSeleccion(seleccionado)),
    ],
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

/// Botón que entra en el modo selección.
class BotonSeleccionar extends StatelessWidget {
  final VoidCallback onPressed;
  const BotonSeleccionar({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: 'Seleccionar',
    style: IconButton.styleFrom(
      side: BorderSide(color: P.borde),
      fixedSize: const Size(36, 36),
      minimumSize: const Size(36, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: onPressed,
    icon: Icon(Icons.checklist_rounded, size: 18, color: P.textoSuave),
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// Tres (o más) cifras encima de una lista, como las de Jobber: etiqueta, número grande y nota.
/// La primera lleva el punto de color de su estado.
class ResumenLista extends StatelessWidget {
  final List<(String, int, String, Color)> cifras;
  final void Function(int i)? onTap;
  const ResumenLista(this.cifras, {super.key, this.onTap});

  Widget _tarjeta(int i) {
    final (etiqueta, valor, nota, color) = cifras[i];
    return HoverCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      onTap: onTap == null ? null : () => onTap!(i),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(etiqueta, style: TextStyle(fontSize: 13, color: P.textoSuave)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$valor',
            style: TextStyle(fontFamily: P.titulos, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1),
          ),
          Text(nota, style: TextStyle(fontSize: 12, color: P.textoSuave)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < cifras.length; i++) ...[if (i > 0) const SizedBox(width: 14), Expanded(child: _tarjeta(i))],
    ],
  );
}
