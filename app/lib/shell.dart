import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ajustes.dart';
import 'forms.dart';
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
                          child: KeyedSubtree(key: ValueKey('$seccion-$clienteId-$trabajadorId'), child: _pagina()),
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

/// Barra lateral gris claro, estrecha, con iconos de línea (estilo Holded).
class _Barra extends StatelessWidget {
  final Seccion seccion;
  final bool compacta;
  final ValueChanged<Seccion> onTap;
  final VoidCallback onNuevo;
  const _Barra({required this.seccion, required this.compacta, required this.onTap, required this.onNuevo});

  @override
  Widget build(BuildContext context) {
    final vencidas = store.tareas
        .where(
          (t) =>
              !t.esPlantilla &&
              t.activa &&
              t.proximo != null &&
              t.proximo!.isBefore(DateUtils.dateOnly(DateTime.now())),
        )
        .length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: compacta ? 64 : 232,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: P.barra,
        border: Border(right: BorderSide(color: P.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo + buscar + crear, como la fila superior de Holded.
          Row(
            mainAxisAlignment: compacta ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (!compacta) const SizedBox(width: 6),
              const _Logo(),
              if (!compacta) ...[
                const SizedBox(width: 8),
                const Text('Pulpo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.4)),
                const Spacer(),
                _IconoBarra(Icons.add_rounded, 'Crear (N)', onNuevo),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (!compacta) ...[const _SelectorEmpresa(), const SizedBox(height: 14)],
          _item(Icons.home_outlined, 'Inicio', Seccion.inicio),
          _item(Icons.calendar_month_outlined, 'Planificación', Seccion.planificacion, aviso: vencidas),
          _item(Icons.apartment_outlined, 'Clientes', Seccion.clientes),
          _item(Icons.badge_outlined, 'Trabajadores', Seccion.trabajadores),
          _item(Icons.handyman_outlined, 'Tareas', Seccion.tareas),
          const SizedBox(height: 14),
          if (!compacta) const _Descubre(),
          const Spacer(),
          if (compacta)
            IconButton(
              tooltip: 'Ocultar barra lateral',
              onPressed: ajustes.alternarBarra,
              icon: Icon(Icons.view_sidebar_outlined, color: P.textoSuave, size: 18),
            ),
          // Provisional: rellenar con datos de ejemplo para ver la app llena, y volver a dejarla limpia.
          _BotonDemo(compacta: compacta),
          const SizedBox(height: 6),
          Builder(
            builder: (context) => _fila(Icons.settings_outlined, 'Ajustes', () => abrirAjustes(context), flecha: true),
          ),
          const SizedBox(height: 2),
          Builder(
            builder: (context) => Tooltip(
              message: compacta ? 'Mi cuenta' : '',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => abrirAjustes(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(
                    mainAxisAlignment: compacta ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      Avatar('YO', const Color(0xFF3F3F46), size: 24, cuadrado: true),
                      if (!compacta) ...[
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Mi cuenta', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: P.textoSuave),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String texto, VoidCallback onTap, {bool flecha = false}) => Tooltip(
    message: compacta ? texto : '',
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: compacta ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icono, size: 18, color: P.textoSuave),
            if (!compacta) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(texto, style: TextStyle(fontSize: 13.5, color: P.texto)),
              ),
              if (flecha) Icon(Icons.chevron_right_rounded, size: 18, color: P.textoSuave),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _item(IconData icono, String texto, Seccion s, {int aviso = 0}) {
    final sel = s == seccion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: compacta ? texto : '',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: P.hover.withValues(alpha: .6),
          onTap: () => onTap(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? P.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: compacta ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(icono, size: 18, color: sel ? P.morado : P.textoSuave),
                if (!compacta) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      texto,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                        color: P.texto,
                      ),
                    ),
                  ),
                  if (aviso > 0)
                    Tooltip(
                      message: '$aviso vencidas',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: P.rojo, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '$aviso',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA78BFA), Color(0xFF6D28D9)],
      ),
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Text('🐙', style: TextStyle(fontSize: 14)),
  );
}

class _IconoBarra extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;
  const _IconoBarra(this.icono, this.tooltip, this.onTap);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icono, size: 18, color: P.textoSuave),
      ),
    ),
  );
}

/// Caja con la empresa activa. De momento solo hay una; prepara el multiempresa.
class _SelectorEmpresa extends StatelessWidget {
  const _SelectorEmpresa();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: P.borde),
    ),
    child: Row(
      children: [
        Avatar('MP', P.morado, size: 24, cuadrado: true),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Mi empresa',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Icon(Icons.unfold_more_rounded, size: 16, color: P.textoSuave),
      ],
    ),
  );
}

/// Tarjeta tintada de "lo que viene", como el "Descubre más" de Holded.
class _Descubre extends StatelessWidget {
  const _Descubre();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: P.moradoSuave,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: P.morado.withValues(alpha: .15)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Empresa propia',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: P.moradoOscuro),
              ),
              Text('Próximamente', style: TextStyle(fontSize: 11, color: P.moradoOscuro.withValues(alpha: .75))),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Botón provisional: rellena con la empresa de ejemplo o la quita y devuelve tus datos.
class _BotonDemo extends StatelessWidget {
  final bool compacta;
  const _BotonDemo({required this.compacta});

  @override
  Widget build(BuildContext context) {
    final demo = store.demo;
    final color = demo ? P.rojo : P.morado;
    final texto = demo ? 'Quitar datos de ejemplo' : 'Rellenar con datos';
    return Tooltip(
      message: compacta ? texto : '',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
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
              if (!compacta) ...[
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
