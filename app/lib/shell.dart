import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ajustes.dart';
import 'forms.dart';
import 'models.dart';
import 'screens/ajustes_dialogo.dart';
import 'screens/cliente_detalle.dart';
import 'screens/clientes.dart';
import 'screens/planificacion.dart';
import 'screens/resumen.dart';
import 'screens/tareas.dart';
import 'screens/trabajador_detalle.dart';
import 'screens/trabajadores.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Secciones de la barra lateral, en orden.
enum Seccion { inicio, planificacion, clientes, trabajadores, tareas }

/// Barra lateral + página activa.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  // ?s=1 abre directamente una sección (útil para enlaces y capturas).
  Seccion seccion =
      Seccion.values[(int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 0).clamp(0, Seccion.values.length - 1)];
  String? clienteId = Uri.base.queryParameters['c'];
  String? trabajadorId = Uri.base.queryParameters['t'];

  @override
  void initState() {
    super.initState();
    // ?nuevo=tarea|cliente|trabajador abre ese formulario al entrar (útil para capturas).
    final nuevo = Uri.base.queryParameters['nuevo'];
    if (nuevo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (nuevo) {
          case 'cliente':
            abrirClienteForm(context);
          case 'trabajador':
            abrirTrabajadorForm(context);
          default:
            abrirTareaForm(context, null, clienteId: store.clientes.firstOrNull?.id);
        }
      });
    }
  }

  void ir(Seccion s) => setState(() {
    seccion = s;
    clienteId = null;
    trabajadorId = null;
  });

  /// "N" crea algo nuevo según la sección en la que estés (como en Holded).
  void nuevo() {
    switch (seccion) {
      case Seccion.clientes:
        abrirClienteForm(context);
      case Seccion.trabajadores:
        abrirTrabajadorForm(context);
      default:
        abrirTareaForm(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compacta = MediaQuery.sizeOf(context).width < 900;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyN): nuevo},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: P.fondo,
          // La barra va a la izquierda o, si se elige en Ajustes, a la derecha.
          body: Row(
            textDirection: ajustes.barraDerecha ? TextDirection.rtl : TextDirection.ltr,
            children: [
              ListenableBuilder(
                listenable: store,
                builder: (_, _) => _Barra(seccion: seccion, compacta: compacta, onTap: ir),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: store,
                        builder: (context, _) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          layoutBuilder: (actual, anteriores) =>
                              Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, .01), end: Offset.zero).animate(a),
                              child: child,
                            ),
                          ),
                          // Capa propia: al redimensionar la barra no se repinta de más. La clave va aquí
                          // para que el AnimatedSwitcher detecte el cambio de página.
                          child: RepaintBoundary(key: ValueKey('$seccion-$clienteId-$trabajadorId'), child: _pagina()),
                        ),
                      ),
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

  Widget _pagina() {
    if (clienteId != null) {
      return ClienteDetalle(clienteId: clienteId!, onVolver: () => setState(() => clienteId = null));
    }
    if (trabajadorId != null) {
      return TrabajadorDetalle(trabajadorId: trabajadorId!, onVolver: () => setState(() => trabajadorId = null));
    }
    // Sin const: si no, el ListenableBuilder del store no las repinta al cambiar los datos.
    return switch (seccion) {
      Seccion.inicio => Resumen(onIr: ir, onTrabajador: (id) => setState(() => trabajadorId = id)),
      // ignore: prefer_const_constructors
      Seccion.planificacion => Planificacion(),
      Seccion.clientes => Clientes(onAbrir: (id) => setState(() => clienteId = id)),
      Seccion.trabajadores => Trabajadores(onAbrir: (id) => setState(() => trabajadorId = id)),
      // ignore: prefer_const_constructors
      Seccion.tareas => TareasPagina(),
    };
  }
}

/// Barra lateral clara. Se ensancha o estrecha arrastrando su borde derecho (hasta media pantalla);
/// por debajo de cierto ancho se queda en solo iconos. El botón de arriba la contrae o la expande.
/// Con más ancho, el texto crece un poco (con tope).
class _Barra extends StatefulWidget {
  final Seccion seccion;
  final bool compacta;
  final ValueChanged<Seccion> onTap;
  const _Barra({required this.seccion, required this.compacta, required this.onTap});

  @override
  State<_Barra> createState() => _BarraState();
}

class _BarraState extends State<_Barra> {
  /// Ancho mientras se arrastra (se guarda al soltar) y dónde empezó el arrastre.
  double? arrastrando;
  double _inicioX = 0, _inicioAncho = 0;
  bool sobreBorde = false;

  /// Como mucho, un 25 % de la ventana.
  double get maximo => (MediaQuery.sizeOf(context).width * .25).clamp(Ajustes.anchoTextos + 40, 2000);

  /// Ancho objetivo. Al arrastrar sigue al ratón sin saltos; al soltar se ajusta (y se anima).
  double get ancho {
    if (widget.compacta) return Ajustes.anchoIconos;
    if (arrastrando != null) return arrastrando!;
    final a = ajustes.anchoBarra;
    return a <= Ajustes.anchoIconos ? Ajustes.anchoIconos : a.clamp(Ajustes.anchoTextos, maximo);
  }

  // El modo (solo iconos o con textos) y la escala salen del ancho REAL de cada fotograma,
  // así el paso entre uno y otro ocurre durante la animación y no de golpe.
  bool _iconos = false;
  double _escala = 1;
  bool get iconos => _iconos;
  double get escala => _escala;

  @override
  Widget build(BuildContext context) {
    final vencidas = store.tareas
        .where((t) => !t.esPlantilla && t.activa && t.proximo != null && diasHasta(t.proximo!) < 0)
        .length;
    return AnimatedContainer(
      duration: arrastrando == null ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Curves.easeOutQuart,
      width: ancho,
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                _iconos = box.maxWidth < 120;
                // Texto: 1 a 248 px, hasta 1,25 al ensanchar y 0,92 en lo más estrecho.
                _escala = _iconos ? 1 : (.92 + (box.maxWidth - Ajustes.anchoTextos) / 700).clamp(.92, 1.25);
                return ClipRect(
                  child: Container(
                    decoration: BoxDecoration(
                      color: P.barra,
                      border: ajustes.barraDerecha
                          ? Border(left: BorderSide(color: P.borde))
                          : Border(right: BorderSide(color: P.borde)),
                    ),
                    padding: EdgeInsets.fromLTRB(iconos ? 10 : 14, 18, iconos ? 10 : 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo y nombre, como en la landing; a la derecha, contraer/expandir.
                        if (iconos) ...[
                          const Center(child: LogoPulpo(size: 32)),
                          const SizedBox(height: 12),
                          _Icono(
                            ajustes.barraDerecha
                                ? Icons.keyboard_double_arrow_left_rounded
                                : Icons.keyboard_double_arrow_right_rounded,
                            'Expandir',
                            ajustes.alternarContraida,
                          ),
                        ] else
                          Row(
                            children: [
                              const SizedBox(width: 2),
                              const LogoPulpo(size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Pulpo',
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontFamily: P.titulos,
                                    fontSize: 21 * escala,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -.6,
                                  ),
                                ),
                              ),
                              if (!widget.compacta)
                                _Icono(
                                  ajustes.barraDerecha
                                      ? Icons.keyboard_double_arrow_right_rounded
                                      : Icons.keyboard_double_arrow_left_rounded,
                                  'Contraer',
                                  ajustes.alternarContraida,
                                  pequeno: true,
                                ),
                            ],
                          ),
                        const SizedBox(height: 26),
                        _item(Icons.home_outlined, 'Inicio', Seccion.inicio),
                        _item(Icons.calendar_month_outlined, 'Itinerario', Seccion.planificacion, aviso: vencidas),
                        _item(Icons.apartment_outlined, 'Clientes', Seccion.clientes),
                        _item(Icons.badge_outlined, 'Trabajadores', Seccion.trabajadores),
                        _item(Icons.handyman_outlined, 'Tareas', Seccion.tareas),
                        const SizedBox(height: 14),
                        const Spacer(),
                        // Provisional: rellenar con datos de ejemplo para ver la app llena, y volver a dejarla limpia.
                        // Discreto: es una herramienta de prueba, no parte del producto.
                        _BotonDemo(
                          texto: store.demo ? 'Quitar datos de ejemplo' : 'Rellenar con datos',
                          icono: store.demo ? Icons.close_rounded : Icons.add_rounded,
                          color: store.demo ? P.rojo : P.morado,
                          compacta: iconos,
                          escala: escala,
                          onTap: store.demo ? store.quitarDemo : store.cargarDemo,
                        ),
                        if (!store.demo)
                          _BotonDemo(
                            texto: 'Rellenar datos 2 (rutas)',
                            icono: Icons.route_rounded,
                            color: P.teal,
                            compacta: iconos,
                            escala: escala,
                            onTap: store.cargarDemoRutas,
                          ),
                        const SizedBox(height: 8),
                        Divider(height: 1, color: P.borde),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) => _fila(Icons.settings_outlined, 'Ajustes', () => abrirAjustes(context)),
                        ),
                        Builder(
                          builder: (context) => _fila(
                            null,
                            'Mi cuenta',
                            () => abrirAjustes(context),
                            lider: Avatar('YO', P.tinta, size: 22 * escala, cuadrado: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Borde arrastrable.
          if (!widget.compacta)
            Positioned(
              top: 0,
              bottom: 0,
              left: ajustes.barraDerecha ? 0 : null,
              right: ajustes.barraDerecha ? null : 0,
              width: 10,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                onEnter: (_) => setState(() => sobreBorde = true),
                onExit: (_) => setState(() => sobreBorde = false),
                // Eventos de puntero directos (sin el umbral de los gestos): responde al primer píxel.
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    _inicioX = e.position.dx;
                    _inicioAncho = ancho;
                    setState(() => arrastrando = ancho);
                  },
                  onPointerMove: (e) => setState(
                    () => arrastrando = (_inicioAncho + (e.position.dx - _inicioX) * (ajustes.barraDerecha ? -1 : 1))
                        .clamp(Ajustes.anchoIconos, maximo),
                  ),
                  onPointerUp: (_) {
                    ajustes.ponerAnchoBarra(arrastrando!, max: maximo);
                    setState(() => arrastrando = null);
                  },
                  onPointerCancel: (_) => setState(() => arrastrando = null),
                  child: Align(
                    alignment: ajustes.barraDerecha ? Alignment.centerLeft : Alignment.centerRight,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: sobreBorde || arrastrando != null ? 3 : 0,
                      color: P.morado,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fila(IconData? icono, String texto, VoidCallback onTap, {Widget? lider}) => _ConEtiqueta(
    texto: texto,
    activa: iconos,
    child: InkWell(
      borderRadius: BorderRadius.circular(P.radioControl),
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisAlignment: iconos ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            lider ?? Icon(icono, size: 19 * escala, color: P.textoSuave),
            if (!iconos) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5 * escala, color: P.texto),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _item(IconData icono, String texto, Seccion s, {int aviso = 0}) {
    final sel = s == widget.seccion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _ConEtiqueta(
        texto: aviso > 0 ? '$texto · $aviso vencidas' : texto,
        activa: iconos,
        child: InkWell(
          borderRadius: BorderRadius.circular(P.radioControl),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: P.hover.withValues(alpha: .7),
          onTap: () => widget.onTap(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(horizontal: iconos ? 8 : 12, vertical: 10 * escala),
            decoration: BoxDecoration(
              color: sel ? P.moradoSuave : Colors.transparent,
              borderRadius: BorderRadius.circular(P.radioControl),
            ),
            child: Row(
              mainAxisAlignment: iconos ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icono, size: 20 * escala, color: sel ? P.morado : P.textoSuave),
                    // Solo iconos: el aviso queda como un punto rojo sobre el icono.
                    if (iconos && aviso > 0)
                      Positioned(
                        right: -3,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: P.rojo,
                            shape: BoxShape.circle,
                            border: Border.all(color: P.barra, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!iconos) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15 * escala,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                        color: sel ? P.moradoOscuro : P.texto,
                      ),
                    ),
                  ),
                  if (aviso > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: P.rojo.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$aviso',
                        style: TextStyle(color: P.rojo, fontSize: 11.5 * escala, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// En modo solo iconos, al pasar el ratón sale una pestañita oscura a la derecha con el nombre.
class _ConEtiqueta extends StatefulWidget {
  final String texto;
  final bool activa;
  final Widget child;
  const _ConEtiqueta({required this.texto, required this.activa, required this.child});

  @override
  State<_ConEtiqueta> createState() => _ConEtiquetaState();
}

class _ConEtiquetaState extends State<_ConEtiqueta> {
  final portal = OverlayPortalController();
  final enlace = LayerLink();

  @override
  void didUpdateWidget(_ConEtiqueta old) {
    super.didUpdateWidget(old);
    if (!widget.activa && portal.isShowing) portal.hide();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: enlace,
    child: OverlayPortal(
      controller: portal,
      overlayChildBuilder: (_) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: enlace,
          targetAnchor: ajustes.barraDerecha ? Alignment.centerLeft : Alignment.centerRight,
          followerAnchor: ajustes.barraDerecha ? Alignment.centerRight : Alignment.centerLeft,
          offset: Offset(ajustes.barraDerecha ? -10 : 10, 0),
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 120),
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(-4 * (1 - v), 0), child: child),
              ),
              child: Material(
                color: P.tinta,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  child: Text(
                    widget.texto,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => widget.activa ? portal.show() : null,
        onExit: (_) => portal.hide(),
        child: widget.child,
      ),
    ),
  );
}

/// Botón de icono de la barra, con su nombre en tooltip.
class _Icono extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final VoidCallback onTap;
  final bool pequeno;
  const _Icono(this.icono, this.nombre, this.onTap, {this.pequeno = false});

  @override
  Widget build(BuildContext context) => _ConEtiqueta(
    texto: nombre,
    activa: !pequeno,
    child: Tooltip(
      message: pequeno ? nombre : '',
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(pequeno ? 5 : 9),
          child: Icon(icono, size: 18, color: P.textoSuave),
        ),
      ),
    ),
  );
}

/// Botón provisional de datos de ejemplo: una fila de texto discreta con su punto de color.
class _BotonDemo extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final bool compacta;
  final double escala;
  final VoidCallback onTap;
  const _BotonDemo({
    required this.texto,
    required this.icono,
    required this.color,
    required this.compacta,
    required this.escala,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _ConEtiqueta(
    texto: texto,
    activa: compacta,
    child: InkWell(
      borderRadius: BorderRadius.circular(P.radioControl),
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisAlignment: compacta ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (compacta)
              Icon(icono, size: 17, color: color)
            else ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13 * escala, fontWeight: FontWeight.w500, color: P.textoSuave),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
