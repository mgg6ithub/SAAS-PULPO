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
          body: Row(
            children: [
              // Al ocultarla se pliega hasta desaparecer; queda un botón para volver a abrirla.
              ClipRect(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerRight,
                  widthFactor: ajustes.barraOculta ? 0 : 1,
                  child: ListenableBuilder(
                    listenable: store,
                    builder: (_, _) => _Barra(seccion: seccion, compacta: compacta, onTap: ir, onNuevo: nuevo),
                  ),
                ),
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
                    if (ajustes.barraOculta)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: IconButton(
                          tooltip: 'Mostrar barra lateral',
                          onPressed: ajustes.alternarBarra,
                          icon: Icon(Icons.view_sidebar_outlined, color: P.textoSuave),
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
      Seccion.inicio => Resumen(
        onIr: ir,
        onCliente: (id) => setState(() => clienteId = id),
        onTrabajador: (id) => setState(() => trabajadorId = id),
      ),
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
  final VoidCallback onNuevo;
  const _Barra({required this.seccion, required this.compacta, required this.onTap, required this.onNuevo});

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
                      border: Border(right: BorderSide(color: P.borde)),
                    ),
                    padding: EdgeInsets.fromLTRB(iconos ? 8 : 12, 14, iconos ? 8 : 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo + crear + contraer/expandir.
                        if (iconos) ...[
                          const Center(child: _Logo()),
                          const SizedBox(height: 10),
                          _Icono(Icons.keyboard_double_arrow_right_rounded, 'Expandir', ajustes.alternarContraida),
                          _Icono(Icons.add_rounded, 'Crear (N)', widget.onNuevo),
                        ] else
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              const _Logo(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Pulpo',
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontFamily: P.titulos,
                                    fontSize: 18 * escala,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.4,
                                  ),
                                ),
                              ),
                              _Icono(Icons.add_rounded, 'Crear (N)', widget.onNuevo, pequeno: true),
                              if (!widget.compacta)
                                _Icono(
                                  Icons.keyboard_double_arrow_left_rounded,
                                  'Contraer',
                                  ajustes.alternarContraida,
                                  pequeno: true,
                                ),
                            ],
                          ),
                        const SizedBox(height: 14),
                        if (!iconos) ...[_SelectorEmpresa(escala), const SizedBox(height: 14)],
                        _item(Icons.home_outlined, 'Inicio', Seccion.inicio),
                        _item(Icons.calendar_month_outlined, 'Itinerario', Seccion.planificacion, aviso: vencidas),
                        _item(Icons.apartment_outlined, 'Clientes', Seccion.clientes),
                        _item(Icons.badge_outlined, 'Trabajadores', Seccion.trabajadores),
                        _item(Icons.handyman_outlined, 'Tareas', Seccion.tareas),
                        const SizedBox(height: 14),
                        const Spacer(),
                        // Provisional: rellenar con datos de ejemplo para ver la app llena, y volver a dejarla limpia.
                        _BotonDemo(compacta: iconos, escala: escala),
                        if (!store.demo) ...[
                          const SizedBox(height: 6),
                          _ConEtiqueta(
                            texto: 'Rellenar datos 2 (rutas)',
                            activa: iconos,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: store.cargarDemoRutas,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: P.azul.withValues(alpha: .35)),
                                  color: P.azul.withValues(alpha: .06),
                                ),
                                child: iconos
                                    ? const Icon(Icons.route_rounded, size: 17, color: P.azul)
                                    : Text(
                                        'Rellenar datos 2 (rutas)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13 * escala,
                                          fontWeight: FontWeight.w600,
                                          color: P.azul,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) => _fila(Icons.settings_outlined, 'Ajustes', () => abrirAjustes(context)),
                        ),
                        Builder(
                          builder: (context) => _fila(
                            null,
                            'Mi cuenta',
                            () => abrirAjustes(context),
                            lider: Avatar('YO', P.morado, size: 22 * escala, cuadrado: true),
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
              right: 0,
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
                    () => arrastrando = (_inicioAncho + e.position.dx - _inicioX).clamp(Ajustes.anchoIconos, maximo),
                  ),
                  onPointerUp: (_) {
                    ajustes.ponerAnchoBarra(arrastrando!, max: maximo);
                    setState(() => arrastrando = null);
                  },
                  onPointerCancel: (_) => setState(() => arrastrando = null),
                  child: Align(
                    alignment: Alignment.centerRight,
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
      borderRadius: BorderRadius.circular(8),
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: iconos ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            lider ?? Icon(icono, size: 18 * escala, color: P.textoSuave),
            if (!iconos) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5 * escala, color: P.texto),
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
      padding: const EdgeInsets.only(bottom: 2),
      child: _ConEtiqueta(
        texto: aviso > 0 ? '$texto · $aviso vencidas' : texto,
        activa: iconos,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: P.hover.withValues(alpha: .6),
          onTap: () => widget.onTap(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8 * escala),
            decoration: BoxDecoration(
              color: sel ? P.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: iconos ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icono, size: 19 * escala, color: sel ? P.morado : P.textoSuave),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14 * escala,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                        color: P.texto,
                      ),
                    ),
                  ),
                  if (aviso > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: P.rojo, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '$aviso',
                        style: TextStyle(color: Colors.white, fontSize: 10.5 * escala, fontWeight: FontWeight.w700),
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
          targetAnchor: Alignment.centerRight,
          followerAnchor: Alignment.centerLeft,
          offset: const Offset(10, 0),
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFC4B5FD), Color(0xFF7C3AED)],
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text('🐙', style: TextStyle(fontSize: 16)),
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

/// Caja con la empresa activa. De momento solo hay una; prepara el multiempresa.
class _SelectorEmpresa extends StatelessWidget {
  final double escala;
  const _SelectorEmpresa(this.escala);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: P.borde),
    ),
    child: Row(
      children: [
        Avatar('MP', P.morado, size: 24 * escala, cuadrado: true),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Mi empresa',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5 * escala, fontWeight: FontWeight.w600),
          ),
        ),
        Icon(Icons.unfold_more_rounded, size: 16, color: P.textoSuave),
      ],
    ),
  );
}

/// Botón provisional: rellena con la empresa de ejemplo o la quita y devuelve tus datos.
class _BotonDemo extends StatelessWidget {
  final bool compacta;
  final double escala;
  const _BotonDemo({required this.compacta, required this.escala});

  @override
  Widget build(BuildContext context) {
    final demo = store.demo;
    final color = demo ? P.rojo : P.morado;
    final texto = demo ? 'Quitar datos de ejemplo' : 'Rellenar con datos';
    return _ConEtiqueta(
      texto: texto,
      activa: compacta,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        mouseCursor: SystemMouseCursors.click,
        onTap: demo ? store.quitarDemo : store.cargarDemo,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: .35)),
            color: color.withValues(alpha: .06),
          ),
          child: Row(
            mainAxisAlignment: compacta ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (compacta) Icon(demo ? Icons.close_rounded : Icons.add_rounded, size: 17, color: color),
              if (!compacta)
                Expanded(
                  child: Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13 * escala, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
