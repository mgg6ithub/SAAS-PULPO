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
import 'screens/simulaciones.dart';
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

  /// Secciones ya abiertas: se quedan montadas (ocultas) para que volver a ellas sea instantáneo.
  final _visitadas = <Seccion>{};

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
    // Primeros pasos: ver el itinerario cuenta solo si ya hay algún trabajo que ver en él.
    if (s == Seccion.planificacion && store.tareas.any((t) => !t.esPlantilla)) ajustes.marcarGuiaItinerario();
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
    _visitadas.add(seccion);
    final enDetalle = clienteId != null || trabajadorId != null;
    return Focus(
      autofocus: true,
      // "N" solo si no se está escribiendo en un campo de texto (si no, no se podría teclear la n).
      onKeyEvent: (_, e) {
        final escribiendo = primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;
        if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyN || escribiendo) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isAltPressed) {
          return KeyEventResult.ignored;
        }
        nuevo();
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: P.fondo,
        // La barra va a la izquierda o, si se elige en Ajustes, a la derecha.
        body: Row(
          textDirection: ajustes.barraDerecha ? TextDirection.rtl : TextDirection.ltr,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([store, ajustes.cambioBarra]),
              builder: (_, _) => _Barra(seccion: seccion, compacta: compacta, onTap: ir),
            ),
            Expanded(
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: store,
                  // Una capa por sección visitada; solo la activa se ve (con fundido de entrada) y recibe
                  // eventos. La ficha de cliente o trabajador va encima, en su propia capa.
                  builder: (context, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final s in Seccion.values)
                        if (_visitadas.contains(s))
                          _Capa(
                            key: ValueKey(s),
                            activa: s == seccion && !enDetalle,
                            child: RepaintBoundary(child: _seccion(s)),
                          ),
                      if (enDetalle)
                        _Capa(
                          key: ValueKey('detalle-$clienteId-$trabajadorId'),
                          activa: true,
                          child: RepaintBoundary(child: _detalle()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detalle() => clienteId != null
      ? ClienteDetalle(clienteId: clienteId!, onVolver: () => setState(() => clienteId = null))
      : TrabajadorDetalle(trabajadorId: trabajadorId!, onVolver: () => setState(() => trabajadorId = null));

  // Sin const: si no, el ListenableBuilder del store no las repinta al cambiar los datos.
  Widget _seccion(Seccion s) => switch (s) {
    Seccion.inicio => Resumen(onIr: ir, onTrabajador: (id) => setState(() => trabajadorId = id)),
    // ignore: prefer_const_constructors
    Seccion.planificacion => Planificacion(),
    Seccion.clientes => Clientes(onAbrir: (id) => setState(() => clienteId = id)),
    Seccion.trabajadores => Trabajadores(onAbrir: (id) => setState(() => trabajadorId = id)),
    // ignore: prefer_const_constructors
    Seccion.tareas => TareasPagina(),
  };
}

/// Capa de una página. Activa: entra con fundido y leve zoom (tras su primer fotograma, para que se vea
/// aunque tarde en construirse). Inactiva: se desvanece rápido y queda montada pero oculta, sin
/// animaciones, foco ni toques.
class _Capa extends StatefulWidget {
  final bool activa;
  final Widget child;
  const _Capa({super.key, required this.activa, required this.child});

  @override
  State<_Capa> createState() => _CapaState();
}

class _CapaState extends State<_Capa> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))
    ..addStatusListener((_) => setState(() {}));
  late final a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
  late final escala = Tween(begin: .985, end: 1.0).animate(a);

  void _entrar() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && widget.activa) c.forward(from: 0);
  });

  @override
  void initState() {
    super.initState();
    if (widget.activa) _entrar();
  }

  @override
  void didUpdateWidget(_Capa old) {
    super.didUpdateWidget(old);
    if (widget.activa && !old.activa) _entrar();
    if (!widget.activa && old.activa) c.animateBack(0, duration: const Duration(milliseconds: 90));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  /// Tamaño con el que se vio por última vez. Oculta, la capa lo conserva: así redimensionar la ventana
  /// o la barra no vuelve a maquetar las páginas que no se ven.
  Size? _tamano;

  @override
  Widget build(BuildContext context) {
    final capa = _capa();
    return LayoutBuilder(
      builder: (context, box) {
        if (widget.activa || _tamano == null) _tamano = box.biggest;
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _tamano!.width,
          maxWidth: _tamano!.width,
          minHeight: _tamano!.height,
          maxHeight: _tamano!.height,
          child: capa,
        );
      },
    );
  }

  Widget _capa() => Offstage(
    offstage: !widget.activa && c.isDismissed,
    child: TickerMode(
      enabled: widget.activa,
      child: ExcludeFocus(
        excluding: !widget.activa,
        child: IgnorePointer(
          ignoring: !widget.activa,
          child: FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: escala, child: widget.child),
          ),
        ),
      ),
    ),
  );
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
  /// Ancho mientras se arrastra (se guarda al soltar). Va en un ValueNotifier: arrastrar solo cambia el
  /// ancho del contenedor, no reconstruye la barra.
  final _arrastre = ValueNotifier<double?>(null);
  double _inicioX = 0, _inicioAncho = 0;

  /// En ventanas estrechas la barra arranca en solo iconos, pero "Expandir" la abre igualmente.
  bool _abiertaCompacta = false;

  void _alternar() =>
      widget.compacta ? setState(() => _abiertaCompacta = !_abiertaCompacta) : ajustes.alternarContraida();

  @override
  void dispose() {
    _arrastre.dispose();
    super.dispose();
  }

  /// Como mucho, un 25 % de la ventana.
  double get maximo => (MediaQuery.sizeOf(context).width * .25).clamp(Ajustes.anchoTextos + 40, 2000);

  /// Ancho objetivo. Al arrastrar sigue al ratón sin saltos; al soltar se ajusta (y se anima).
  double _ancho(double? arrastrando) {
    if (widget.compacta) return _abiertaCompacta ? Ajustes.anchoTextos + 40 : Ajustes.anchoIconos;
    if (arrastrando != null) return arrastrando;
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
    // El contenido solo se reconstruye al pasar a solo iconos o al cambiar la escala del texto (en pasos
    // de 0,04); el resto del arrastre o de la animación solo recoloca.
    final contenido = SegunTamano(
      clave: _modo,
      builder: (context, box) {
        final modo = _modo(box);
        _iconos = modo.$1;
        _escala = modo.$2;
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
                  const SizedBox(height: 4),
                  _Icono(
                    ajustes.barraDerecha
                        ? Icons.keyboard_double_arrow_left_rounded
                        : Icons.keyboard_double_arrow_right_rounded,
                    'Expandir',
                    _alternar,
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
                      _Icono(
                        ajustes.barraDerecha
                            ? Icons.keyboard_double_arrow_right_rounded
                            : Icons.keyboard_double_arrow_left_rounded,
                        'Contraer',
                        _alternar,
                        pequeno: true,
                      ),
                    ],
                  ),
                // Contraída: una línea separa el logo del menú. Expandida, solo aire.
                if (iconos) ...[
                  const SizedBox(height: 8),
                  Divider(height: 1, color: P.borde),
                  const SizedBox(height: 10),
                ] else
                  const SizedBox(height: 26),
                _menu(vencidas),
                const SizedBox(height: 14),
                const Spacer(),
                _BotonDemo(
                  texto: 'Simulaciones',
                  icono: Icons.science_outlined,
                  color: P.morado,
                  compacta: iconos,
                  escala: escala,
                  onTap: () => abrirSimulaciones(context),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: P.borde),
                const SizedBox(height: 8),
                Builder(builder: (context) => _fila(Icons.settings_outlined, 'Ajustes', () => abrirAjustes(context))),
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
    );
    return ValueListenableBuilder<double?>(
      valueListenable: _arrastre,
      builder: (context, arrastrando, child) => AnimatedContainer(
        duration: arrastrando == null ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutQuart,
        width: _ancho(arrastrando),
        child: child,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: contenido),
          // Borde arrastrable.
          if (!widget.compacta)
            Positioned(
              top: 0,
              bottom: 0,
              left: ajustes.barraDerecha ? 0 : null,
              right: ajustes.barraDerecha ? null : 0,
              width: 10,
              child: _AsaBarra(
                derecha: ajustes.barraDerecha,
                onInicio: (x) {
                  _inicioX = x;
                  _inicioAncho = _ancho(null);
                  _arrastre.value = _inicioAncho;
                },
                onMover: (x) => _arrastre.value = (_inicioAncho + (x - _inicioX) * (ajustes.barraDerecha ? -1 : 1))
                    .clamp(Ajustes.anchoIconos, maximo),
                onFin: () {
                  if (_arrastre.value != null) ajustes.ponerAnchoBarra(_arrastre.value!, max: maximo);
                  _arrastre.value = null;
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Modo de la barra según su ancho real: (solo iconos, escala del texto). La escala va de 0,92 a 1,25
  /// al ensanchar, redondeada a pasos de 0,04 para no reconstruir en cada píxel.
  (bool, double) _modo(BoxConstraints box) {
    final iconos = box.maxWidth < 120;
    if (iconos) return (true, 1.0);
    final e = (.92 + (box.maxWidth - Ajustes.anchoTextos) / 700).clamp(.92, 1.25);
    return (false, (e * 25).round() / 25);
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

  /// Alto de cada opción del menú y separación entre ellas.
  double get _altoItem => 40 * escala;
  static const _hueco = 4.0;

  /// Menú de secciones. La marca de la opción activa es un único fondo morado que se desliza
  /// de una a otra (como en macOS), en vez de apagarse una y encenderse otra.
  Widget _menu(int vencidas) {
    final items = [
      (Icons.home_outlined, 'Inicio', Seccion.inicio, 0),
      (Icons.calendar_month_outlined, 'Itinerario', Seccion.planificacion, vencidas),
      (Icons.apartment_outlined, 'Clientes', Seccion.clientes, 0),
      (Icons.badge_outlined, 'Trabajadores', Seccion.trabajadores, 0),
      (Icons.handyman_outlined, 'Trabajos', Seccion.tareas, 0),
    ];
    final activo = items.indexWhere((x) => x.$3 == widget.seccion);
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          top: activo * (_altoItem + _hueco),
          left: 0,
          right: 0,
          height: _altoItem,
          child: DecoratedBox(
            decoration: BoxDecoration(color: P.moradoSuave, borderRadius: BorderRadius.circular(P.radioControl)),
          ),
        ),
        Column(children: [for (final (icono, texto, s, aviso) in items) _item(icono, texto, s, aviso: aviso)]),
      ],
    );
  }

  Widget _item(IconData icono, String texto, Seccion s, {int aviso = 0}) {
    final sel = s == widget.seccion;
    return Padding(
      padding: const EdgeInsets.only(bottom: _hueco),
      child: _ConEtiqueta(
        texto: aviso > 0 ? '$texto · $aviso vencidos' : texto,
        activa: iconos,
        child: InkWell(
          borderRadius: BorderRadius.circular(P.radioControl),
          mouseCursor: SystemMouseCursors.click,
          // Sin onda ni destello al pulsar: solo se desliza el fondo.
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: sel ? Colors.transparent : P.hover.withValues(alpha: .7),
          onTap: () => widget.onTap(s),
          child: Container(
            height: _altoItem,
            padding: EdgeInsets.symmetric(horizontal: iconos ? 8 : 12),
            child: Row(
              mainAxisAlignment: iconos ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: sel ? P.morado : P.textoSuave),
                      duration: const Duration(milliseconds: 200),
                      builder: (_, c, _) => Icon(icono, size: 20 * escala, color: c),
                    ),
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
                    // Mismo grosor siempre (que el texto no "salte"); solo cambia el color, con transición.
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: P.titulos,
                        fontSize: 15 * escala,
                        fontWeight: FontWeight.w600,
                        color: sel ? P.moradoOscuro : P.texto,
                      ),
                      child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis),
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

/// Borde arrastrable de la barra: raya morada al pasar el ratón o arrastrar. Lleva su propio estado,
/// así el hover no reconstruye la barra. Eventos de puntero directos: responde al primer píxel.
class _AsaBarra extends StatefulWidget {
  final bool derecha;
  final ValueChanged<double> onInicio, onMover;
  final VoidCallback onFin;
  const _AsaBarra({required this.derecha, required this.onInicio, required this.onMover, required this.onFin});

  @override
  State<_AsaBarra> createState() => _AsaBarraState();
}

class _AsaBarraState extends State<_AsaBarra> {
  bool encima = false, arrastrando = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    onEnter: (_) => setState(() => encima = true),
    onExit: (_) => setState(() => encima = false),
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        setState(() => arrastrando = true);
        widget.onInicio(e.position.dx);
      },
      onPointerMove: (e) => widget.onMover(e.position.dx),
      onPointerUp: (_) {
        setState(() => arrastrando = false);
        widget.onFin();
      },
      onPointerCancel: (_) {
        setState(() => arrastrando = false);
        widget.onFin();
      },
      child: Align(
        alignment: widget.derecha ? Alignment.centerLeft : Alignment.centerRight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: encima || arrastrando ? 3 : 0,
          color: P.morado,
        ),
      ),
    ),
  );
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
