import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ajustes.dart';
import 'finanzas.dart';
import 'forms.dart';
import 'models.dart';
import 'screens/ajustes_dialogo.dart';
import 'screens/cliente_detalle.dart';
import 'screens/finanzas.dart';
import 'screens/clientes.dart';
import 'screens/mi_cuenta.dart';
import 'screens/planificacion.dart';
import 'screens/resumen.dart';
import 'screens/simulaciones.dart';
import 'screens/tarea_detalle.dart';
import 'screens/tareas.dart';
import 'screens/trabajador_detalle.dart';
import 'screens/trabajadores.dart';
import 'screens/vista_trabajador.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Secciones de la barra lateral, en orden.
enum Seccion { inicio, planificacion, clientes, trabajadores, tareas, finanzas }

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
  String? tareaId;

  /// Secciones ya abiertas: se quedan montadas (ocultas) para que volver a ellas sea instantáneo.
  final _visitadas = <Seccion>{};

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_tecla);
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
    tareaId = null;
  });

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_tecla);
    super.dispose();
  }

  /// Menú «Crear» de la barra lateral (la tecla T lo abre).
  final _crear = MenuController();

  /// Ventana abierta con la N: otra N la cierra.
  bool _abiertaConN = false;

  /// "N" crea algo nuevo según la sección en la que estés (como en Holded).
  Future<void> nuevo() async {
    _abiertaConN = true;
    final abierta = store.tarea(tareaId);
    await switch (seccion) {
      _ when abierta != null => abrirSubtrabajoRapido(context, abierta),
      Seccion.clientes => abrirClienteForm(context),
      Seccion.trabajadores => abrirTrabajadorForm(context),
      Seccion.finanzas => abrirDocumento(context, Documento(vence: masDias(hoy(), 30))),
      _ => abrirTareaForm(context, null),
    };
    _abiertaConN = false;
  }

  /// Atajo N, escuchado en todo el teclado (no depende de dónde esté el foco, que tras un clic puede quedar
  /// fuera de esta vista). Se ignora al escribir en un campo y con Ctrl/Cmd/Alt. Abre la ventana de nuevo
  /// de la sección; si la abrió una N y sigue arriba (sin un menú o diálogo encima), la cierra.
  bool _tecla(KeyEvent e) {
    final esT = e.logicalKey == LogicalKeyboardKey.keyT;
    if (e is! KeyDownEvent || (e.logicalKey != LogicalKeyboardKey.keyN && !esT) || !mounted) return false;
    final teclado = HardwareKeyboard.instance;
    if (teclado.isControlPressed || teclado.isMetaPressed || teclado.isAltPressed) return false;
    final foco = primaryFocus?.context;
    if (foco?.findAncestorStateOfType<EditableTextState>() != null) return false;
    final arriba = foco == null ? null : ModalRoute.of(foco);
    final aqui = ModalRoute.of(context);
    // T abre (o cierra) el menú «Crear» de la barra lateral, en cualquier vista.
    if (esT) {
      if (_crear.isOpen) {
        _crear.close();
        return true;
      }
      if (arriba == null || arriba == aqui) {
        _crear.open();
        return true;
      }
      return false;
    }
    if (_abiertaConN && arriba != null && arriba != aqui && arriba.settings.name == rutaPanel) {
      Navigator.of(context).pop();
      return true;
    }
    if (arriba == null || arriba == aqui) {
      nuevo();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: rolTrabajador,
    // Vista de trabajador: otra app, sin barra lateral. Esta se queda con su estado al volver.
    builder: (context, rol, _) => rol != null ? const ShellTrabajador() : _administrador(context),
  );

  Widget _administrador(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final compacta = ancho < 900;
    // Móvil: sin barra lateral; las secciones van en una barra abajo.
    final movil = ancho < 700;
    _visitadas.add(seccion);
    final enDetalle = clienteId != null || trabajadorId != null || tareaId != null;
    final pagina = Expanded(
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
                  key: ValueKey('detalle-$clienteId-$trabajadorId-$tareaId'),
                  activa: true,
                  child: RepaintBoundary(child: _detalle()),
                ),
            ],
          ),
        ),
      ),
    );
    return Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: P.fondo,
        body: movil
            ? Column(
                children: [
                  pagina,
                  ListenableBuilder(
                    listenable: store,
                    builder: (_, _) => _BarraInferior(seccion: seccion, onTap: ir, crear: _crear),
                  ),
                ],
              )
            // La barra va a la izquierda o, si se elige en Ajustes, a la derecha.
            : Row(
                textDirection: ajustes.barraDerecha ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  ListenableBuilder(
                    listenable: Listenable.merge([store, ajustes.cambioBarra]),
                    builder: (_, _) => _Barra(seccion: seccion, compacta: compacta, onTap: ir, crear: _crear),
                  ),
                  pagina,
                ],
              ),
      ),
    );
  }

  Widget _detalle() => clienteId != null
      ? ClienteDetalle(clienteId: clienteId!, onVolver: () => setState(() => clienteId = null))
      : tareaId != null
      ? TareaDetalle(
          tareaId: tareaId!,
          onVolver: () => setState(() => tareaId = null),
          onAbrir: (id) => setState(() => tareaId = id),
        )
      : TrabajadorDetalle(trabajadorId: trabajadorId!, onVolver: () => setState(() => trabajadorId = null));

  // Sin const: si no, el ListenableBuilder del store no las repinta al cambiar los datos.
  Widget _seccion(Seccion s) => switch (s) {
    Seccion.inicio => Resumen(onIr: ir, onTrabajador: (id) => setState(() => trabajadorId = id)),
    // ignore: prefer_const_constructors
    Seccion.planificacion => Planificacion(),
    Seccion.clientes => Clientes(onAbrir: (id) => setState(() => clienteId = id)),
    Seccion.trabajadores => Trabajadores(onAbrir: (id) => setState(() => trabajadorId = id)),
    Seccion.tareas => TareasPagina(onAbrir: (id) => setState(() => tareaId = id)),
    Seccion.finanzas => const VistaFinanzas(),
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

/// «Crear» arriba del menú, como en Jobber: al pulsarlo sale, a su derecha, una fila horizontal con el icono de cada
/// cosa que se puede dar de alta (cliente, trabajo, trabajador) desde cualquier sitio. Con la barra en solo
/// iconos, queda un botón con el plus.
class _BotonCrear extends StatefulWidget {
  final bool compacto;
  final MenuController menu;
  const _BotonCrear({required this.compacto, required this.menu});

  @override
  State<_BotonCrear> createState() => _BotonCrearState();
}

class _BotonCrearState extends State<_BotonCrear> {
  @override
  Widget build(BuildContext context) {
    // Se despliega hacia la derecha del plus; en ventanas estrechas, debajo.
    final alLado = MediaQuery.sizeOf(context).width >= 700;
    return MenuAnchor(
      controller: widget.menu,
      alignmentOffset: alLado ? const Offset(8, 0) : const Offset(0, 4),
      style: MenuStyle(
        alignment: alLado ? AlignmentDirectional.topEnd : null,
        backgroundColor: WidgetStatePropertyAll(P.superficie),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radio))),
      ),
      menuChildren: [
        _FilaCrear(
          cerrar: widget.menu.close,
          opciones: [
            (Icons.apartment_outlined, 'Cliente', () => abrirClienteForm(context)),
            (Icons.handyman_outlined, 'Trabajo', () => abrirTareaForm(context, null)),
            (Icons.badge_outlined, 'Trabajador', () => abrirTrabajadorForm(context)),
          ],
        ),
      ],
      builder: (context, menu, _) => Tooltip(
        message: 'Crear',
        child: SizedBox(
          height: 40,
          child: widget.compacto
              ? IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: P.morado,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
                  ),
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                  icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                )
              : FilledButton(
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                  // FittedBox: mientras la barra se estrecha, el contenido encoge en vez de desbordar.
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 20),
                        SizedBox(width: 6),
                        Text('Crear'),
                        SizedBox(width: 10),
                        _TeclaT(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// La «T» pequeña del botón Crear (como la «N» de los botones de «Nuevo»).
class _TeclaT extends StatelessWidget {
  const _TeclaT();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(4)),
    child: const Text('T', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

/// Las opciones de «Crear» en fila. La elegida (la primera al abrir; después, la del ratón o las flechas) va en
/// morado y las demás en neutro; Intro la abre.
class _FilaCrear extends StatefulWidget {
  final VoidCallback cerrar;
  final List<(IconData, String, VoidCallback)> opciones;
  const _FilaCrear({required this.cerrar, required this.opciones});

  @override
  State<_FilaCrear> createState() => _FilaCrearState();
}

class _FilaCrearState extends State<_FilaCrear> {
  int elegida = 0;

  void _abrir(int i) {
    widget.cerrar();
    widget.opciones[i].$3();
  }

  KeyEventResult _tecla(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final n = widget.opciones.length;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowDown) {
      setState(() => elegida = (elegida + 1) % n);
    } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowUp) {
      setState(() => elegida = (elegida - 1 + n) % n);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      _abrir(elegida);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _tecla,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (icono, texto, _)) in widget.opciones.indexed)
          MouseRegion(
            onEnter: (_) => setState(() => elegida = i),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _abrir(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 84,
                height: 68,
                // La sombra suave va solo en la elegida (ratón o flechas).
                decoration: BoxDecoration(
                  color: i == elegida ? P.hover : Colors.transparent,
                  borderRadius: BorderRadius.circular(P.radioControl),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icono, size: 24, color: i == elegida ? P.morado : P.texto),
                    const SizedBox(height: 6),
                    Text(
                      texto,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: i == elegida ? P.morado : P.texto,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
  final MenuController crear;
  const _Barra({required this.seccion, required this.compacta, required this.onTap, required this.crear});

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
                  const SizedBox(height: 18),
                _BotonCrear(compacto: iconos, menu: widget.crear),
                SizedBox(height: iconos ? 10 : 14),
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
                Builder(
                  builder: (context) =>
                      _fila(Icons.badge_outlined, 'Vista de trabajador', () => abrirVistaTrabajador(context)),
                ),
                Builder(builder: (context) => _fila(Icons.settings_outlined, 'Ajustes', () => abrirAjustes(context))),
                Builder(
                  builder: (context) => _fila(
                    null,
                    'Mi cuenta',
                    () => abrirMiCuenta(context),
                    lider: Avatar(inicialesCuenta(), P.tinta, size: 22 * escala, cuadrado: true),
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
      (Icons.handyman_outlined, 'Trabajos', Seccion.tareas, 0),
      (Icons.badge_outlined, 'Trabajadores', Seccion.trabajadores, 0),
      (Icons.euro_rounded, 'Finanzas', Seccion.finanzas, 0),
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

/// Barra de abajo en móvil: las secciones solo con icono (la activa sobre fondo morado suave), «Crear»
/// y «Más» (Simulaciones, vista de trabajador, Ajustes y Mi cuenta).
class _BarraInferior extends StatelessWidget {
  final Seccion seccion;
  final ValueChanged<Seccion> onTap;
  final MenuController crear;
  const _BarraInferior({required this.seccion, required this.onTap, required this.crear});

  @override
  Widget build(BuildContext context) {
    final vencidas = store.tareas
        .where((t) => !t.esPlantilla && t.activa && t.proximo != null && diasHasta(t.proximo!) < 0)
        .length;
    final items = [
      (Icons.home_outlined, 'Inicio', Seccion.inicio, 0),
      (Icons.calendar_month_outlined, 'Itinerario', Seccion.planificacion, vencidas),
      (Icons.apartment_outlined, 'Clientes', Seccion.clientes, 0),
      (Icons.handyman_outlined, 'Trabajos', Seccion.tareas, 0),
      (Icons.badge_outlined, 'Trabajadores', Seccion.trabajadores, 0),
      (Icons.euro_rounded, 'Finanzas', Seccion.finanzas, 0),
    ];
    return Container(
      decoration: BoxDecoration(
        color: P.barra,
        border: Border(top: BorderSide(color: P.borde)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              for (final (icono, texto, s, aviso) in items)
                Expanded(
                  child: Tooltip(
                    message: aviso > 0 ? '$texto · $aviso vencidos' : texto,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(P.radioControl),
                      splashFactory: NoSplash.splashFactory,
                      onTap: () => onTap(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: s == seccion ? P.moradoSuave : Colors.transparent,
                          borderRadius: BorderRadius.circular(P.radioControl),
                        ),
                        child: Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(icono, size: 22, color: s == seccion ? P.morado : P.textoSuave),
                              if (aviso > 0)
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
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              _BotonCrear(compacto: true, menu: crear),
              const SizedBox(width: 4),
              BotonMenu<int>(
                tooltip: 'Más',
                onSelected: (i) => switch (i) {
                  0 => abrirSimulaciones(context),
                  1 => abrirVistaTrabajador(context),
                  2 => abrirAjustes(context),
                  _ => abrirMiCuenta(context),
                },
                opciones: [
                  for (final (i, (icono, texto)) in const [
                    (Icons.science_outlined, 'Simulaciones'),
                    (Icons.badge_outlined, 'Vista de trabajador'),
                    (Icons.settings_outlined, 'Ajustes'),
                    (Icons.person_outline_rounded, 'Mi cuenta'),
                  ].indexed)
                    (
                      i,
                      Row(
                        children: [
                          Icon(icono, size: 18, color: P.textoSuave),
                          const SizedBox(width: 10),
                          Text(texto),
                        ],
                      ),
                    ),
                ],
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.more_horiz_rounded, size: 22, color: P.textoSuave),
                ),
              ),
            ],
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
