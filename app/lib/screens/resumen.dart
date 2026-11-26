import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../estadisticas.dart';
import '../models.dart';
import '../shell.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'estadisticas.dart';
import 'intro_inicio.dart';
import 'planificacion.dart';
import 'tarea_card.dart';
import 'tareas.dart' show filtroFechaTrabajos, filtroCriticidadTrabajos, historicoTrabajos;
import '../marca.dart';
import '../nube.dart' show Nube;
import '../industrial/activos.dart' show abrirActivoForm;
import '../industrial/planes.dart' show abrirPlanForm;
// import '../industrial/foto_planta.dart'; // Foto de Inicio quitada de momento.
import '../industrial/tipo_mantenimiento.dart' show puntoTipo;
import '../industrial/vistazo.dart';

/// Inicio: saludo, cifras clave, lo pendiente, la carga del equipo y los próximos mantenimientos
/// como las tarjetas de la landing. Sin gráficas de relleno: solo lo que se mira cada mañana.
class Resumen extends StatelessWidget {
  final ValueChanged<Seccion> onIr;
  final ValueChanged<String> onTrabajador;

  /// Abre la ficha de un cliente (desde las estadísticas).
  final ValueChanged<String>? onCliente;

  /// Abre una orden de trabajo (desde las tarjetas por criticidad de Pultec).
  final ValueChanged<String>? onTarea;
  const Resumen({super.key, required this.onIr, required this.onTrabajador, this.onCliente, this.onTarea});

  @override
  Widget build(BuildContext context) {
    final activas = store.tareas.where((t) => !t.esPlantilla && t.activa).toList();
    final conFecha = activas.where((t) => t.proximo != null).toList();
    final vencidas = conFecha.where((t) => diasHasta(t.proximo!) < 0).toList();
    final hoyT = conFecha.where((t) => diasHasta(t.proximo!) == 0).toList();
    final semana = conFecha.where((t) => diasHasta(t.proximo!) >= 0 && diasHasta(t.proximo!) <= 7).toList();
    final hechas30 = activas.where((t) => t.ultimo != null && diasHasta(t.ultimo!) >= -30).length;
    final sinTrabajador = conFecha.where((t) => t.trabajadorIds.isEmpty && diasHasta(t.proximo!) <= 7).toList();
    // Antes de completar la guía, los pasos reflejan los datos; después quedan completados.
    final hayTarea = store.tareas.any((t) => !t.esPlantilla);
    final hayTrabajador = store.trabajadores.any((w) => w.activo);
    final hayTrabajoAsignado = store.tareas.any(
      (t) => !t.esPlantilla && t.trabajadorIds.any((id) => store.trabajador(id)?.activo == true),
    );
    // Pultec: la guía sale solo hasta completarla una vez en la empresa (se recuerda). Si luego se borra todo, no
    // vuelve: en su lugar, un aviso sencillo para empezar.
    final empresa = store.nube?.empresaId ?? 'local';
    final datosPultec = [store.activos.isNotEmpty, store.planes.isNotEmpty, hayTrabajador, hayTrabajoAsignado];
    if (industrial && !datosPultec.contains(false)) ajustes.marcarGuiaPultec(empresa);
    // `guiaOrganizar`: la guía antigua, ya completada en este navegador, también cuenta como hecha.
    final guiaHecha =
        industrial && (ajustes.guiaPultecHecha(empresa) || ajustes.guiaOrganizar || !datosPultec.contains(false));
    final pasos = industrial
        ? (guiaHecha ? const [true, true, true, true] : datosPultec)
        : ajustes.guiaOrganizar
        ? const [true, true, true, true]
        : [
            industrial ? store.activos.isNotEmpty : store.clientes.isNotEmpty,
            hayTarea,
            hayTarea && ajustes.guiaItinerario,
            hayTrabajador && hayTarea && ajustes.guiaOrganizar && hayTrabajoAsignado,
          ];

    // Solo se reconstruye al pasar de una a dos columnas; el resto del ancho lo resuelve la maquetación.
    // La primera vez de una cuenta nueva (Pultec, guía sin hacer), con la presentación animada.
    final vista = SegunTamano(
      clave: (box) => (P.mejorada, min(1080.0, box.maxWidth - margenPagina.horizontal) > 760, _columnasKpi(box), box.maxWidth > 1180),
      builder: (context, box) {
        final dosCol = min(1080.0, box.maxWidth - margenPagina.horizontal) > 760;
        // Vista mejorada (a todo el ancho): cifras en 4, 2 o 1 columnas según quepan sin cortar el texto, y las
        // órdenes con lo pendiente al lado solo si hay sitio de verdad; si no, una debajo de otra.
        final kpis = _columnasKpi(box);
        final alLado = P.mejorada ? box.maxWidth > 1180 : dosCol;
        // En pareja, las dos tarjetas miden lo mismo: lo que pida la más alta, sin huecos fijos.
        Widget par(Widget a, Widget b) => dosCol
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 16),
                    Expanded(child: b),
                  ],
                ),
              )
            : Column(children: [a, const SizedBox(height: 16), b]);

        // Vista mejorada: a todo el ancho (sin columna central ni huecos a los lados), con algo más de margen.
        final margen = P.mejorada ? margenPagina.left + 12 : margenPagina.left;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(margen, margenPagina.top + 16, margen, margenPagina.bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: P.mejorada ? double.infinity : 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(conFecha: conFecha, pasos: pasos),
                  const SizedBox(height: 16),
                  if (pasos.contains(false)) ...[
                    Aparecer(child: _PrimerosPasos(pasos, onIr: onIr)),
                    const SizedBox(height: 16),
                  ],
                  // Sin ningún trabajo todo serían ceros y paneles vacíos: en su lugar, cómo funciona Pultec.
                  if (!hayTarea && (industrial ? !guiaHecha : !ajustes.guiaOrganizar))
                    Aparecer(retraso: .75, child: _ComoFunciona(columnas: dosCol)),
                  // Guía ya hecha y sin órdenes (todo borrado, o solo activos): sin tutorial, solo cómo seguir.
                  if (industrial && !hayTarea && guiaHecha && !P.mejorada) const _SinMaquinas(),
                  // Pultec con la guía hecha: el panel siempre, aunque esté vacío (cifras a cero y, en lugar de las
                  // órdenes, cómo seguir), para que Inicio no se quede en blanco.
                  if (hayTarea || (industrial && guiaHecha && P.mejorada)) ...[
                    // Pultec: las cuatro cifras son de órdenes de trabajo; con su título, como «Estado de los activos».
                    // En la vista mejorada, sin título: las cifras van justo bajo la cabecera, como en la maqueta.
                    if (industrial && !P.mejorada) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Resumen de órdenes de trabajo',
                              style: TextStyle(
                                fontFamily: P.titulos,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.5,
                              ),
                            ),
                          ),
                          Enlace(
                            'Ver todas',
                            onTap: () {
                              filtroFechaTrabajos.value = 0;
                              onIr(Seccion.tareas);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    // Lo primero que hay que atender, encima de las cifras (solo se ve si hay alguna).
                    if (industrial && store.activos.isNotEmpty && (hayTarea || !P.mejorada))
                      IncidenciasAbiertas(onAbrir: onTarea ?? (_) {}, abajo: 16),
                    ValueListenableBuilder(
                      valueListenable: periodoInicio,
                      builder: (context, elegida, _) => _Kpis(
                        elegida: industrial ? elegida : 0,
                        hoy: hoyT.length,
                        semana: industrial
                            ? activas
                                  .where(
                                    (t) =>
                                        t.trabajadorIds.isEmpty &&
                                        (t.estado == EstadoTrabajo.pendiente || t.estado == EstadoTrabajo.enCurso),
                                  )
                                  .length
                            : semana.length,
                        vencidas: vencidas.length,
                        // Pultec: «Histórico», las órdenes cerradas (completadas y canceladas), como su pestaña.
                        hechas: industrial
                            ? activas.where((t) => !t.estado.abierta).length
                            : hechas30,
                        dosCol: dosCol,
                        columnas: kpis,
                        // Abre Órdenes de trabajo con ese filtro (Para hoy, Sin técnico, Vencidos, Hechos).
                        onTap: (f) {
                          // Pultec: «Histórico» abre el histórico; el resto, lo pendiente con su filtro.
                          historicoTrabajos.value = industrial && f == 4;
                          filtroFechaTrabajos.value = industrial && f == 4 ? 0 : f;
                          filtroCriticidadTrabajos.value = 0;
                          onIr(Seccion.tareas);
                        },
                      ),
                    ),
                    // Vista mejorada de Pultec: a la izquierda las órdenes por criticidad; a la derecha, lo pendiente
                    // y la carga del equipo.
                    if (industrial && P.mejorada && (store.activos.isNotEmpty || !hayTarea)) ...[
                      if (hayTarea) ...[
                        AvisosPreparacion(onAbrir: onCliente ?? (_) {}),
                        const SizedBox(height: 16),
                      ] else
                        const SizedBox(height: 16),
                      () {
                        final ordenes = !hayTarea ? const _SinMaquinas() : OrdenesPorCriticidad(
                          enColumnas: dosCol,
                          onAbrir: onTarea ?? (_) {},
                          onVerMas: (f) {
                            filtroFechaTrabajos.value = periodoInicio.value;
                            historicoTrabajos.value = false;
                            filtroCriticidadTrabajos.value = f;
                            onIr(Seccion.tareas);
                          },
                        );
                        final lado = [
                          // «Acciones pendientes» quitada en Pultec: repetía las cifras de arriba (vencidos, sin
                          // asignar) y llevaba a Órdenes de trabajo sin más.
                          // _Pendientes(vencidas: vencidas, sinTrabajador: sinTrabajador, onIr: onIr),
                          // const SizedBox(height: 16),
                          _CargaTrabajadores(onTrabajador: onTrabajador),
                          const SizedBox(height: 16),
                          _EstaSemana(onIr: onIr),
                        ];
                        // Las dos columnas acaban a la misma altura: la carga del equipo se estira hasta el final de
                        // las órdenes (o las órdenes hasta el final de la derecha), sin huecos abajo.
                        // Sin órdenes, ni carga del equipo ni semana: solo la tarjeta de cómo seguir, a todo el ancho.
                        if (!hayTarea) return ordenes;
                        return alLado
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Las órdenes, lo principal: más anchas que lo de al lado.
                                    Expanded(flex: 5, child: ordenes),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [...lado.take(lado.length - 1), Expanded(child: lado.last)],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [ordenes, const SizedBox(height: 16), ...lado],
                              );
                      }(),
                      // Mismo hueco entre todos los bloques de la vista mejorada.
                      const SizedBox(height: 16),
                    ] else if (industrial && store.activos.isNotEmpty) ...[
                      AvisosPreparacion(onAbrir: onCliente ?? (_) {}),
                      const SizedBox(height: 32),
                      VistazoActivos(
                        onAbrir: onTarea ?? (_) {},
                        onVerMas: (f) {
                          filtroFechaTrabajos.value = periodoInicio.value;
                          historicoTrabajos.value = false;
                          filtroCriticidadTrabajos.value = f;
                          onIr(Seccion.tareas);
                        },
                        columnas: dosCol ? 3 : 1,
                      ),
                      const SizedBox(height: 32),
                    ] else
                      const SizedBox(height: 16),
                    if (!(industrial && P.mejorada && store.activos.isNotEmpty)) ...[
                      par(
                        _Pendientes(vencidas: vencidas, sinTrabajador: sinTrabajador, onIr: onIr),
                        _CargaTrabajadores(onTrabajador: onTrabajador),
                      ),
                      const SizedBox(height: 32),
                    ],
                    // Pultec: lo próximo ya está en las órdenes por criticidad.
                    if (!industrial) _Proximos(conFecha, onIr: onIr, columnas: dosCol ? 2 : 1),
                    // Las estadísticas son de clientes y equipos: en Pultec su lugar lo ocupa el vistazo.
                    if (!industrial) ...[
                      const SizedBox(height: 32),
                      Estadisticas(dosCol: dosCol, onCliente: onCliente ?? (_) {}),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    return IntroInicioMarco(activa: industrial && !guiaHecha, child: vista);
  }
}

/// Columnas de las cifras de Inicio en la vista mejorada: cada tarjeta necesita unos 270 px para no cortar
/// «Completados» ni su nota.
int _columnasKpi(BoxConstraints box) {
  final ancho = box.maxWidth - margenPagina.horizontal - 24;
  return ancho >= 4 * 270 + 48 ? 4 : (ancho >= 2 * 250 + 16 ? 2 : 1);
}

const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Para una cuenta sin trabajos: el ciclo de Pultec en tres tarjetas y qué cifras verá en Inicio.
/// Desaparece con el primer trabajo y deja paso a las cifras y los paneles.
/// Pultec sin órdenes de trabajo, con la guía ya hecha: un estado vacío sobrio en lugar del tutorial. Sin
/// máquinas, invita a dar de alta la primera; con máquinas, a crear su primer mantenimiento.
class _SinMaquinas extends StatelessWidget {
  const _SinMaquinas();

  @override
  Widget build(BuildContext context) {
    final primera = store.activos.where((a) => a.padreId == null).firstOrNull;
    return Tarjeta(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: primera == null
          ? Vacio(
              desplazable: false,
              icono: Marca.iconoCliente,
              titulo: 'Sin activos',
              texto:
                  'Da de alta un activo y sus mantenimientos: Pultec creará las órdenes de trabajo y avisará de lo que toca.',
              accion: BotonPrimario(
                'Crear un nuevo activo',
                conIcono: true,
                icono: Icons.add_rounded,
                onPressed: () => abrirActivoForm(context),
              ),
            )
          // Sin órdenes porque aún no hay mantenimientos (lo normal: cada mantenimiento crea su orden).
          : Vacio(
              desplazable: false,
              icono: Icons.content_paste_rounded,
              titulo: store.planes.isEmpty ? 'Sin mantenimientos ni órdenes de trabajo' : 'Sin órdenes de trabajo',
              texto: store.planes.isEmpty
                  ? 'Tus activos aún no tienen mantenimientos. Crea uno y Pultec generará sus órdenes de trabajo '
                        'para cuando toque.'
                  : 'Pultec generará las órdenes de trabajo de tus mantenimientos para cuando toque.',
              accion: BotonPrimario(
                'Mantenimiento',
                conIcono: true,
                icono: Icons.add_rounded,
                onPressed: () => abrirPlanForm(context, activoId: primera.id),
              ),
            ),
    );
  }
}

class _ComoFunciona extends StatelessWidget {
  final bool columnas;
  const _ComoFunciona({required this.columnas});

  @override
  Widget build(BuildContext context) {
    final etapas = industrial
        ? [
            (
              P.azul,
              'Tus activos',
              'Todo lo que necesite un mantenimiento: camiones, compresores, prensas o equipos informáticos, cada uno '
                  'con sus componentes.',
            ),
            (
              P.teal,
              'Sus mantenimientos',
              'Define qué hay que hacer en cada activo o componente y cada cuánto toca: por fecha o por horas de uso.',
            ),
            (
              P.ambar,
              'Órdenes de trabajo automáticas',
              'Pultec crea la orden de cada mantenimiento con su fecha y se la asigna al técnico o grupo que indiques.',
            ),
          ]
        : [
            (
              P.azul,
              m('Tus clientes'),
              'Cada edificio, local o instalación que mantienes, con su dirección en el mapa.',
            ),
            (
              P.teal,
              m('Sus trabajos'),
              m('Qué hay que revisar y cada cuánto. Pultec calcula cuándo toca y avisa de lo que vence.'),
            ),
            (
              P.ambar,
              m('Pultec organiza'),
              m('Reparte los trabajos entre tu equipo según lo que sabe hacer y traza la ruta del día.'),
            ),
          ];
    final tarjetas = [
      for (final (i, (_, titulo, texto)) in etapas.indexed)
        Aparecer(
          retraso: .85 + i * .14,
          child: Tarjeta(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El número de la etapa, grande y neutro.
              Text(
                '${i + 1}',
                style: TextStyle(
                  fontFamily: P.titulos,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: P.textoSuave,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                titulo,
                style: TextStyle(fontFamily: P.titulos, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -.2),
              ),
              const SizedBox(height: 4),
              Text(texto, style: TextStyle(fontSize: 13, height: 1.4, color: P.textoSuave)),
            ],
          ),
          ),
        ),
    ];
    // Pultec: los tres tipos de orden de trabajo, cada uno en su bloque con su punto de color.
    final tipos = [
      for (final (i, t) in TipoMantenimiento.values.indexed)
        Aparecer(
          retraso: 1.35 + i * .14,
          child: Tarjeta(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    puntoTipo(t.color),
                    const SizedBox(width: 8),
                    Text(t.etiqueta, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(t.descripcion, style: TextStyle(fontSize: 12.5, height: 1.4, color: P.textoSuave)),
              ],
            ),
          ),
        ),
    ];
    // De un bloque al siguiente, una flecha (en columna, hacia abajo).
    Widget flecha(int i) => Aparecer(
      retraso: .92 + i * .14,
      child: Icon(
        columnas ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
        size: 22,
        color: P.morado,
      ),
    );
    Widget titulo(String texto) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        texto,
        style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.3),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titulo(m('Cómo funciona Pultec')),
        if (columnas)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, t) in tarjetas.indexed) ...[
                  if (i > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Center(child: flecha(i - 1))),
                  Expanded(child: t),
                ],
              ],
            ),
          )
        else
          for (final (i, t) in tarjetas.indexed) ...[
            if (i > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: flecha(i - 1))),
            t,
          ],
        // Pultec: debajo, qué pasa al completar una orden, con su animación.
        if (industrial) ...[
          const SizedBox(height: 16),
          Aparecer(retraso: 1.22, child: _CicloOrden(columnas: columnas)),
        ],
        const SizedBox(height: 24),
        // Pultec: el color de cada orden de trabajo, que verá en Inicio en cuanto dé de alta sus activos.
        if (industrial) ...[
          titulo('El color de cada activo'),
          Aparecer(
            retraso: 1.3,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Las órdenes que salen de un mantenimiento son preventivas. Las que creas tú o salen de una '
                'incidencia pueden ser correctivas: no críticas o críticas.',
                style: TextStyle(fontSize: 13, height: 1.4, color: P.textoSuave),
              ),
            ),
          ),
          if (columnas)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, t) in tipos.indexed) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: t)],
                ],
              ),
            )
          else
            for (final (i, t) in tipos.indexed) ...[if (i > 0) const SizedBox(height: 12), t],
        ],
      ],
    );
  }
}

/// Animaciones sin fin de la guía de Inicio (borde, huellas y ciclo de la orden). Las pruebas las apagan
/// (test/flutter_test_config.dart): con ellas `pumpAndSettle` no terminaría.
bool animacionesGuia = true;

/// Qué pasa al completar una orden, en dos bloques animados con un mismo reloj: en el primero la orden se marca
/// como completada y baja al histórico; entonces, en el segundo, nace la siguiente. Se repite sin parar. Con
/// «reducir movimiento», la escena final fija.
class _CicloOrden extends StatefulWidget {
  final bool columnas;
  const _CicloOrden({required this.columnas});

  @override
  State<_CicloOrden> createState() => _CicloOrdenState();
}

class _CicloOrdenState extends State<_CicloOrden> with SingleTickerProviderStateMixin {
  /// Alto de cada escena y de sus piezas.
  static const _alto = 132.0, _altoOrden = 58.0, _altoHistorico = 52.0;

  /// Fotograma que se ve con las animaciones apagadas: orden ya archivada y la siguiente creada.
  static const _fotoFija = .8;

  late final _reloj = AnimationController(vsync: this, duration: const Duration(milliseconds: 6500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!animacionesGuia || MediaQuery.disableAnimationsOf(context)) {
      _reloj
        ..stop()
        ..value = _fotoFija;
    } else if (!_reloj.isAnimating) {
      _reloj.repeat();
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  /// Avance (0 a 1, suave) entre los momentos [de] y [a] del ciclo.
  double _tramo(double de, double a, [Curve curva = Curves.easeInOutCubic]) =>
      curva.transform(((_reloj.value - de) / (a - de)).clamp(0.0, 1.0));

  /// Una orden en miniatura: círculo que se marca, nombre, cuándo y su estado.
  Widget _orden({required String cuando, required Widget estado, double hecha = 0, double brillo = 0}) => Container(
    height: _altoOrden,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(P.radioControl),
      border: Border.all(color: Color.lerp(P.borde, P.morado, brillo)!, width: 1 + brillo),
      boxShadow: [BoxShadow(color: P.morado.withValues(alpha: .18 * brillo), blurRadius: 14, spreadRadius: 1)],
    ),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(P.verde.withValues(alpha: 0), P.verde, hecha),
            border: Border.all(color: Color.lerp(P.borde, P.verde, hecha)!, width: 2),
          ),
          child: Transform.scale(scale: hecha, child: const Icon(Icons.check_rounded, size: 15, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cambio de aceite',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              Text(cuando, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: P.textoSuave)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        estado,
      ],
    ),
  );

  /// Escena 1: la orden se completa y cae en el histórico.
  Widget _archivar() {
    final entra = _tramo(0, .08), hecha = _tramo(.14, .24, Curves.easeOutBack).clamp(0.0, 1.0);
    final baja = _tramo(.32, .48), sale = 1 - _tramo(.92, 1);
    final llega = _tramo(.44, .52), destello = sin(pi * _tramo(.42, .66, Curves.linear)).clamp(0.0, 1.0);
    return Opacity(
      opacity: sale,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _altoHistorico,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Color.lerp(P.hover, P.moradoSuave, destello),
                borderRadius: BorderRadius.circular(P.radioControl),
                border: Border.all(color: P.morado.withValues(alpha: .6 * destello)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Histórico', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  // Una marca por orden guardada; la nueva aparece al llegar.
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Transform.scale(
                        scale: i < 3 ? 1 : llega,
                        child: Container(
                          width: 6,
                          height: 18,
                          decoration: BoxDecoration(color: P.verde, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 4 + (_alto - _altoHistorico - 4) * baja,
            child: Opacity(
              opacity: entra * (1 - _tramo(.4, .48)),
              child: Transform.scale(
                scale: 1 - .22 * baja,
                child: _orden(
                  cuando: 'Hoy',
                  hecha: hecha,
                  estado: hecha < .5 ? const Pill('Pendiente', P.ambar) : const Pill('Completada', P.verde),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Escena 2: en el hueco aparece la orden siguiente.
  Widget _crear() {
    final nace = _tramo(.52, .68, Curves.easeOutBack), visible = _tramo(.52, .6);
    final brillo = (_tramo(.56, .66) - _tramo(.78, .9)).clamp(0.0, 1.0);
    final sale = 1 - _tramo(.92, 1);
    const arriba = (_alto - _altoOrden) / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // El hueco donde caerá: borde discontinuo mientras no está.
        Positioned(
          left: 0,
          right: 0,
          top: arriba,
          height: _altoOrden,
          child: Opacity(
            opacity: 1 - visible * sale,
            child: CustomPaint(
              painter: BordeDiscontinuo(P.textoSuave.withValues(alpha: .5), BorderRadius.circular(P.radioControl)),
              child: Center(
                child: Text('Siguiente orden', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: arriba - 26 * (1 - nace),
          child: Opacity(
            opacity: visible * sale,
            child: Transform.scale(
              scale: .86 + .14 * nace,
              child: _orden(cuando: 'Dentro de 30 días', brillo: brillo, estado: Pill('Nueva', P.morado)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bloque(Widget Function() escena, String titulo, String texto) => Tarjeta(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Es un dibujo de ejemplo: lo que cuenta ya lo dice el texto.
        ExcludeSemantics(
          child: RepaintBoundary(
            child: SizedBox(
              height: _alto,
              child: AnimatedBuilder(animation: _reloj, builder: (_, _) => escena()),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          titulo,
          style: TextStyle(fontFamily: P.titulos, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -.2),
        ),
        const SizedBox(height: 4),
        Text(texto, style: TextStyle(fontSize: 13, height: 1.4, color: P.textoSuave)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bloques = [
      _bloque(
        _archivar,
        'Se completa y pasa al histórico',
        'Cuando el técnico termina la orden, queda guardada en el histórico con lo que se hizo.',
      ),
      _bloque(
        _crear,
        'Y se crea la siguiente',
        'Pultec genera sola la nueva orden con su próxima fecha. No tienes que acordarte de nada.',
      ),
    ];
    Widget flecha(IconData icono) => Icon(icono, size: 22, color: P.morado);
    return widget.columnas
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: bloques[0]),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Center(child: flecha(Icons.chevron_right_rounded)),
                ),
                Expanded(child: bloques[1]),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bloques[0],
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: flecha(Icons.expand_more_rounded))),
              bloques[1],
            ],
          );
  }
}

/// Guía de primeros pasos (como la de Google Play Console): índice vertical con ticks que se marcan y
/// desmarcan solos según los datos. A la derecha de cada paso, dónde se hace en la app; solo el paso
/// en curso lleva su botón. Desaparece al completarla.
class _PrimerosPasos extends StatelessWidget {
  /// Hecho o no, por paso: cliente, trabajo, ver el itinerario, trabajador.
  final List<bool> hechos;
  final ValueChanged<Seccion> onIr;
  const _PrimerosPasos(this.hechos, {required this.onIr});

  /// Pasos de Pultec: máquina, su mantenimiento (la OT se crea sola), un técnico y asignarle la orden.
  List<(String, String, (IconData, String, String, Seccion)?, Widget?)>
  _pasosPultec(bool hayTrabajador) => [
    (
      'Da de alta tu primer activo',
      'Un camión, un compresor, una prensa… Pon su contador de horas y cuánto se usa: así Pultec sabe cuándo le '
          'toca cada mantenimiento por horas.',
      (Marca.iconoCliente, 'Activos', 'Nuevo activo', Seccion.clientes),
      null,
    ),
    (
      'Crea su primer mantenimiento',
      'Dentro del activo, «+ Mantenimiento»: qué hay que hacer y cada cuánto (días u horas). Pultec crea su orden '
          'de trabajo para la fecha que toca y, al completarla, la siguiente.',
      (Marca.iconoCliente, 'Activos', 'Mantenimiento', Seccion.clientes),
      null,
    ),
    (
      'Añade un técnico',
      'Quién hace los mantenimientos y de qué categoría es. Con eso Pultec le asigna sus órdenes.',
      (Marca.iconoTrabajador, 'Técnicos', 'Nuevo técnico', Seccion.trabajadores),
      null,
    ),
    (
      'Asigna la orden a un técnico',
      'En Órdenes de trabajo, elige quién la hace. Le llegará a su móvil con todo lo que necesita.',
      (Marca.iconoTrabajo, 'Órdenes de trabajo', 'Asignar', Seccion.tareas),
      null,
    ),
  ];

  /// Deja el itinerario en la semana del último trabajo, para organizar el día en que cae.
  void _semanaDelTrabajo() {
    final t = store.tareas.where((t) => !t.esPlantilla).lastOrNull;
    Planificacion.mostrarSemana(t?.proximo ?? hoy());
  }

  /// Abre el itinerario en la semana del último trabajo creado, para verlo en su día y su hora.
  void _verItinerario() {
    final t = store.tareas.lastWhere((t) => !t.esPlantilla);
    Planificacion.mostrarSemana(t.proximo ?? hoy());
    ajustes.marcarGuiaItinerario();
    onIr(Seccion.planificacion);
  }

  @override
  Widget build(BuildContext context) {
    // (título, explicación, ruta en la app, botón). Los pasos de crear no se hacen aquí: la ruta es un botón
    // que solo lleva a su sección; el formulario lo abre el usuario con el botón de allí, para que aprenda dónde
    // está. Ver el itinerario: su botón.
    final hayTrabajador = store.trabajadores.any((w) => w.activo);
    final pasos = industrial ? _pasosPultec(hayTrabajador) : [
      industrial
          ? (
              'Da de alta tu primer activo',
              'Un activo: un camión, un compresor, una prensa… Dentro, sus componentes con su tag, fabricante y modelo.',
              (Marca.iconoCliente, 'Activos', 'Nuevo activo', Seccion.clientes),
              null,
            )
          : (
              m('Crea tu primer cliente'),
              'A quien le haces el mantenimiento: una comunidad, una empresa, un local, una instalación…',
              (Marca.iconoCliente, m('Clientes'), m('Nuevo cliente'), Seccion.clientes),
              null,
            ),
      (
        m('Crea un trabajo'),
        industrial
            ? 'Un mantenimiento de un activo o de uno de sus componentes: qué hay que hacer, cada cuánto y de qué '
                  'tipo (preventivo, correctivo no crítico o crítico). Pultec calcula cuándo toca.'
            : m(
                'Un mantenimiento que se repite: qué hay que revisar y cada cuánto. Pultec calcula cuándo toca. '
                'También puedes crearlo desde la ficha del cliente.',
              ),
        (Marca.iconoTrabajo, m('Trabajos'), m('Nuevo trabajo'), Seccion.tareas),
        null,
      ),
      (
        m('Mira tu trabajo en el itinerario'),
        m(
          Marca.mapa
              ? 'El itinerario es tu semana: cada trabajo en su día y a su hora, y en el mapa.'
              : 'El itinerario es tu semana: cada trabajo en su día y a su hora.',
        ),
        null,
        BotonPrimario('Ir al itinerario', icono: Icons.calendar_month_outlined, onPressed: _verItinerario),
      ),
      (
        !hayTrabajador ? m('Añade un trabajador') : m('Deja que Pultec organice tu primer trabajo'),
        !hayTrabajador
            ? m('Quién hace los mantenimientos. Indica qué sabe hacer y Pultec le propondrá los trabajos que le encajan.')
            : m(
                Marca.mapa
                    ? 'Ve al itinerario y pulsa Organizar. Pultec asignará el trabajo al técnico y trazará la ruta.'
                    : 'Ve al itinerario y pulsa Organizar. Pultec asignará el trabajo al técnico según su categoría.',
              ),
        !hayTrabajador
            ? (Marca.iconoTrabajador, m('Trabajadores'), m('Nuevo trabajador'), Seccion.trabajadores)
            : (Icons.calendar_month_outlined, (industrial ? 'Planificación' : 'Itinerario'), 'Organizar', Seccion.planificacion),
        null,
      ),
    ];
    final actual = hechos.indexOf(false);
    // Borde discontinuo: es una guía de paso, no una tarjeta de datos. Parpadea en morado mientras esté la guía.
    return _BordeParpadeante(
      // La tarjeta blanca va metida hacia dentro: el borde discontinuo queda por fuera, con aire.
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Tarjeta(
        color: P.superficie,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
        child: Stack(
          children: [
            // Cuántos pasos van hechos, en la esquina de arriba a la derecha.
            Positioned(
              top: 2,
              right: 0,
              child: Text(
                '${hechos.where((h) => h).length} de ${pasos.length}',
                style: TextStyle(fontSize: 12.5, color: P.textoSuave),
              ),
            ),
            Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Primeros pasos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: P.titulos,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Pasitos que caminan hacia la derecha, en onda, junto al título (en móvil no caben).
                if (!esMovil(context))
                  const ExcludeSemantics(child: _HuellasAnimadas()),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 12),
            for (final (i, (titulo, detalle, ruta, boton)) in pasos.indexed)
              // En la presentación, los pasos entran de uno en uno.
              Aparecer(
                retraso: .2 + i * .14,
                child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Marca y, debajo, la línea que une con el siguiente paso.
                    SizedBox(
                      width: 20,
                      child: Column(
                        children: [
                          _MarcaPaso(hecho: hechos[i], actual: i == actual),
                          if (i < pasos.length - 1)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                color: P.borde,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                fontWeight: i == actual ? FontWeight.w600 : FontWeight.w500,
                                color: hechos[i] || i == actual ? P.texto : P.textoSuave,
                                decoration: hechos[i] ? TextDecoration.lineThrough : null,
                                decorationColor: P.textoSuave,
                              ),
                              child: Text(titulo),
                            ),
                            // El paso en curso, más abierto: explicación y, debajo, dónde se hace o su botón.
                            if (i == actual) ...[
                              const SizedBox(height: 4),
                              Text(detalle, style: TextStyle(fontSize: 13, height: 1.4, color: P.textoSuave)),
                              const SizedBox(height: 12),
                              if (ruta != null)
                                _Ruta(
                                  ruta.$1,
                                  ruta.$2,
                                  ruta.$3,
                                  mas: ruta.$4 != Seccion.planificacion,
                                  onTap: () {
                                    // Itinerario: se prepara la semana antes de entrar.
                                    if (ruta.$4 == Seccion.planificacion) _semanaDelTrabajo();
                                    onIr(ruta.$4);
                                  },
                                ),
                              ?boton,
                              const SizedBox(height: 6),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
          ],
        ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Dónde se hace un paso en la app, en una pastilla suave: icono y sección › acción. Al pulsarla lleva
/// a esa sección y abre su formulario, como si se hubiera pulsado allí.
class _Ruta extends StatelessWidget {
  final IconData icono;
  final String seccion, accion;
  final VoidCallback onTap;

  /// "+" delante de la acción, como en el botón de la sección.
  final bool mas;
  const _Ruta(this.icono, this.seccion, this.accion, {required this.onTap, this.mas = false});

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
    return Material(
      color: P.hover,
      borderRadius: BorderRadius.circular(P.radioControl),
      child: InkWell(
        borderRadius: BorderRadius.circular(P.radioControl),
        hoverColor: P.moradoSuave,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 15, color: P.textoSuave),
              const SizedBox(width: 6),
              Text(seccion, style: estilo),
              Icon(Icons.chevron_right_rounded, size: 16, color: P.textoSuave),
              if (mas) ...[Icon(Icons.add_rounded, size: 16, color: P.texto), const SizedBox(width: 3)],
              // En móvil, «Nueva orden de trabajo» puede no caber: se corta antes que desbordar.
              Flexible(
                child: Text(accion, maxLines: 1, overflow: TextOverflow.ellipsis, style: estilo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Borde discontinuo de «Primeros pasos»: pasa sin parar de neutro a morado y vuelve. Con «reducir movimiento»,
/// morado fijo.
class _BordeParpadeante extends StatefulWidget {
  final Widget child;
  const _BordeParpadeante({required this.child});

  @override
  State<_BordeParpadeante> createState() => _BordeParpadeanteState();
}

class _BordeParpadeanteState extends State<_BordeParpadeante> with SingleTickerProviderStateMixin {
  late final _latido = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!animacionesGuia || MediaQuery.disableAnimationsOf(context)) {
      _latido
        ..stop()
        ..value = 1;
    } else if (!_latido.isAnimating) {
      _latido.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _latido,
    // La tarjeta no se vuelve a pintar en cada paso del parpadeo: solo el borde.
    child: RepaintBoundary(child: widget.child),
    builder: (context, child) => CustomPaint(
      foregroundPainter: BordeDiscontinuo(
        Color.lerp(P.gris.withValues(alpha: .4), P.morado, Curves.easeInOut.transform(_latido.value))!,
        BorderRadius.circular(P.radio + 6),
        separacion: 6,
      ),
      child: child,
    ),
  );
}

/// Marca de un paso: tick verde si está hecho, anillo morado si es el actual, anillo gris si falta.
class _MarcaPaso extends StatelessWidget {
  final bool hecho, actual;
  const _MarcaPaso({required this.hecho, required this.actual});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: hecho
          ? const Icon(Icons.check_rounded, key: ValueKey(1), size: 18, color: P.verde)
          : Container(
              key: ValueKey(actual),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: actual ? P.morado : P.borde, width: 2),
              ),
            ),
    ),
  );
}

/// "Acciones pendientes": lo que necesita atención, con su categoría a la derecha.
class _Pendientes extends StatelessWidget {
  final List<Tarea> vencidas, sinTrabajador;
  final ValueChanged<Seccion> onIr;
  const _Pendientes({required this.vencidas, required this.sinTrabajador, required this.onIr});

  @override
  Widget build(BuildContext context) {
    final sinTareas = store.clientes.where((c) => c.activa && store.tareasDe(c.id).isEmpty).length;
    final averiadas = store.tareas.where((t) => !t.esPlantilla && t.estadoMaquina != EstadoMaquina.operativa).length;
    final ausentes = store.trabajadores.where((w) => w.activo && w.estadoHoy == EstadoHoy.ausente).length;
    final filas = [
      if (vencidas.isNotEmpty)
        FilaLista(
          lider: _punto(P.rojo),
          titulo: '${vencidas.length} ${vencidas.length == 1 ? 'mantenimiento vencido' : 'mantenimientos vencidos'}',
          derecha: _cat((industrial ? 'Planificación' : 'Itinerario')),
          onTap: () => onIr(Seccion.planificacion),
        ),
      if (sinTrabajador.isNotEmpty)
        FilaLista(
          lider: _punto(P.morado),
          titulo: '${sinTrabajador.length} sin asignar esta semana',
          derecha: _cat(m('Trabajos')),
          onTap: () => onIr(Seccion.tareas),
        ),
      if (store.vencimientosPorAvisar.isNotEmpty)
        FilaLista(
          lider: _punto(store.vencimientosPorAvisar.any((v) => diasHasta(v.vence) < 0) ? P.rojo : P.ambar),
          titulo:
              '${store.vencimientosPorAvisar.length} ${store.vencimientosPorAvisar.length == 1 ? 'vencimiento legal' : 'vencimientos legales'} por renovar',
          subtitulo: [
            for (final v in store.vencimientosPorAvisar.take(3)) '${v.nombre} ${store.equipo(v.equipoId)!.nombre}',
          ].join(' · '),
          derecha: _cat(m('Clientes')),
          onTap: () => onIr(Seccion.clientes),
        ),
      if (averiadas > 0)
        FilaLista(
          lider: _punto(P.ambar),
          titulo: '$averiadas ${averiadas == 1 ? 'equipo' : 'equipos'} en revisión o averiados',
          derecha: _cat(m('Trabajos')),
          onTap: () => onIr(Seccion.tareas),
        ),
      for (final e in equiposQueFallan(store))
        FilaLista(
          lider: _punto(P.rojo),
          titulo: '${e.nombre} falla demasiado',
          subtitulo: '${store.cliente(e.clienteId)?.nombre ?? ''} · 3 o más averías en un año',
          derecha: _cat(m('Clientes')),
          onTap: () => onIr(Seccion.clientes),
        ),
      for (final w in sobrecargados(store))
        FilaLista(
          lider: _punto(P.ambar),
          titulo: '${w.nombreCompleto} va sobrecargado',
          subtitulo: 'Más de 40 h asignadas en los próximos 7 días',
          derecha: _cat(m('Trabajadores')),
          onTap: () => onIr(Seccion.trabajadores),
        ),
      if (clientesOlvidados(store) case final olvidados when olvidados.isNotEmpty)
        FilaLista(
          lider: _punto(P.azul),
          titulo: m(
            '${olvidados.length} ${olvidados.length == 1 ? 'cliente' : 'clientes'} sin revisión desde hace más de un año',
          ),
          subtitulo: olvidados.take(3).map((c) => c.nombre).join(' · '),
          derecha: _cat(m('Clientes')),
          onTap: () => onIr(Seccion.clientes),
        ),
      if (sinTareas > 0)
        FilaLista(
          lider: _punto(P.azul),
          titulo: m('$sinTareas ${sinTareas == 1 ? 'cliente' : 'clientes'} sin mantenimientos'),
          derecha: _cat(m('Clientes')),
          onTap: () => onIr(Seccion.clientes),
        ),
      if (ausentes > 0)
        FilaLista(
          lider: _punto(P.gris),
          titulo: m('$ausentes ${ausentes == 1 ? 'trabajador ausente' : 'trabajadores ausentes'} hoy'),
          derecha: _cat(m('Trabajadores')),
          onTap: () => onIr(Seccion.trabajadores),
        ),
    ];
    return SeccionTarjeta(
      titulo: 'Acciones pendientes',
      icono: P.mejorada ? Icons.assignment_outlined : null,
      accion: filas.isEmpty ? null : Pill('${filas.length}', P.rojo),
      children: filas.isEmpty
          ? [
              // Alto mínimo, no fijo (como «Carga del equipo»): con el título del vacío no cabía en 170 y desbordaba.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 140),
                child: P.mejorada
                    ? const Vacio(
                        icono: Icons.check_rounded,
                        titulo: 'No hay acciones pendientes',
                        texto: 'Todo al día.',
                        desplazable: false,
                      )
                    : const Vacio(icono: Icons.task_alt_rounded, texto: 'Nada pendiente. ¡Todo al día!'),
              ),
            ]
          : filas,
    );
  }

  Widget _cat(String t) => Text(t, style: TextStyle(fontSize: 12, color: P.textoSuave));
}

/// Barra horizontal fina con su valor, para listas tipo "Cuentas de gasto" de Holded.
Widget _barra(double v, Color color) => ClipRRect(
  borderRadius: BorderRadius.circular(3),
  child: TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: v),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (_, x, _) => LinearProgressIndicator(value: x, minHeight: 6, color: color, backgroundColor: P.hover),
  ),
);

class _CargaTrabajadores extends StatelessWidget {
  final ValueChanged<String> onTrabajador;
  const _CargaTrabajadores({required this.onTrabajador});

  @override
  Widget build(BuildContext context) {
    final ws = store.trabajadores.where((w) => w.activo).toList();
    int carga(Trabajador w) => store.tareas
        .where(
          (t) => !t.esPlantilla && t.trabajadorIds.contains(w.id) && t.proximo != null && diasHasta(t.proximo!) <= 7,
        )
        .length;
    ws.sort((a, b) => carga(b) - carga(a));
    final maximo = max(1, ws.isEmpty ? 1 : carga(ws.first));
    return SeccionTarjeta(
      titulo: 'Carga del equipo',
      icono: P.mejorada ? Icons.groups_outlined : null,
      subtitulo: m('Trabajos asignados en los próximos 7 días'),
      sinFilas: true,
      children: [
        if (ws.isEmpty)
          // Alto mínimo, no fijo: en móvil el texto ocupa dos líneas y no cabría.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 140),
            child: Center(
              child: Vacio(icono: Marca.iconoTrabajador, texto: m('Aún no hay trabajadores'), desplazable: false),
            ),
          )
        else
          for (final w in ws.take(6))
            InkWell(
              onTap: () => onTrabajador(w.id),
              hoverColor: P.hoverFila,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 26),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: w.estadoHoy.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: P.superficie, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: Text(
                        w.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(child: _barra(carga(w) / maximo, colorPaleta(w.color))),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${carga(w)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Pultec, Inicio: órdenes de cada día de hoy a dentro de 6 días, con una barrita; al pulsar, a la Planificación.
/// Va la última de la columna derecha y se estira hasta el final de las órdenes (sin hueco vacío abajo).
class _EstaSemana extends StatelessWidget {
  final ValueChanged<Seccion> onIr;
  const _EstaSemana({required this.onIr});

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  Widget build(BuildContext context) {
    final h = hoy();
    final dias = [for (var i = 0; i < 7; i++) masDias(h, i)];
    final cuenta = {for (final d in dias) d: 0};
    for (final t in store.tareas) {
      if (t.esPlantilla || t.proximo == null) continue;
      final d = DateUtils.dateOnly(t.proximo!);
      if (cuenta.containsKey(d)) cuenta[d] = cuenta[d]! + 1;
    }
    final maximo = max(1, cuenta.values.fold(0, max));
    return SeccionTarjeta(
      titulo: 'Esta semana',
      icono: Icons.calendar_today_outlined,
      subtitulo: m('Trabajos programados cada día'),
      sinFilas: true,
      children: [
        for (final (i, d) in dias.indexed)
          InkWell(
            onTap: () => onIr(Seccion.planificacion),
            hoverColor: P.hoverFila,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: i == 0 ? 'Hoy' : i == 1 ? 'Mañana' : _dias[d.weekday - 1]),
                          TextSpan(
                            text: '  ${d.day}',
                            style: TextStyle(color: P.textoSuave, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
                  Expanded(child: _barra(cuenta[d]! / maximo, i == 0 ? P.morado : P.morado.withValues(alpha: .45))),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${cuenta[d]}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cuenta[d] == 0 ? P.textoSuave : P.texto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Próximos mantenimientos como los cuadraditos de la landing (lo vencido primero).
class _Proximos extends StatelessWidget {
  final List<Tarea> conFecha;
  final ValueChanged<Seccion> onIr;
  final int columnas;
  const _Proximos(this.conFecha, {required this.onIr, required this.columnas});

  @override
  Widget build(BuildContext context) {
    final lista = [...conFecha.where((t) => diasHasta(t.proximo!) <= 14)]
      ..sort((a, b) => a.proximo!.compareTo(b.proximo!));
    final ts = lista.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Próximos mantenimientos',
                style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
              ),
            ),
            Enlace('Ir al itinerario', onTap: () => onIr(Seccion.planificacion)),
          ],
        ),
        const SizedBox(height: 14),
        if (ts.isEmpty)
          const Tarjeta(
            child: SizedBox(
              height: 160,
              child: Vacio(icono: Icons.event_available_outlined, texto: 'Nada programado en las próximas dos semanas'),
            ),
          )
        else
          Rejilla(columnas: columnas, children: [for (final t in ts) TareaCard(t)]),
      ],
    );
  }
}

/// Cabecera de Inicio: la fecha en morado y las acciones fuera, justo encima de un bloque morado claro
/// (degradado desde la izquierda) con el saludo, una frase según el momento y tres cifras, sin botones.
/// Saludo, fecha y frase siguen a la hora: se revisan cada minuto.
class _Hero extends StatefulWidget {
  final List<Tarea> conFecha;

  /// Pasos de la guía hechos o no (ver [_PrimerosPasos]).
  final List<bool> pasos;
  const _Hero({required this.conFecha, required this.pasos});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  late final Timer _reloj;
  late DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Solo repinta si cambia la hora (saludo, frase) o el día (fecha).
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) {
      final n = DateTime.now();
      if (n.hour != _ahora.hour || n.day != _ahora.day) setState(() => _ahora = n);
    });
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  String get saludo {
    // Pultec: tono de planta, sin saludo ni sol.
    if (industrial) return store.nube?.nombre ?? 'Planta';
    final h = _ahora.hour;
    return h >= 6 && h < 14 ? 'Buenos días' : (h >= 14 && h < 21 ? 'Buenas tardes' : 'Buenas noches');
  }

  String get fecha => 'Hoy es ${_dias[_ahora.weekday - 1]}, ${_ahora.day} de ${_meses[_ahora.month - 1]}';

  static String _mant(int n) => '$n ${n == 1 ? 'mantenimiento' : 'mantenimientos'}';

  /// Primera vez: bienvenida; con la guía a medias: lo que falta; después, el día (y por la noche, mañana).
  String get frase {
    if (industrial && store.activos.isEmpty) return 'Aún no hay activos. Da de alta el primero para empezar.';
    if (industrial && !store.tareas.any((t) => !t.esPlantilla)) {
      return store.planes.isEmpty
          ? 'Aún no hay mantenimientos ni órdenes de trabajo.'
          : 'Aún no hay órdenes de trabajo.';
    }
    final pasos = widget.pasos;
    final quedan = pasos.where((p) => !p).length;
    if (quedan == pasos.length) {
      return m('Te damos la bienvenida a Pultec. En unos minutos tendrás tu mantenimiento en marcha.');
    }
    if (quedan == 1) return 'Ya casi está: solo te falta un paso.';
    if (quedan > 1) return 'Vas bien: en nada tendrás tu mantenimiento en marcha.';

    final hoyT = widget.conFecha.where((t) => diasHasta(t.proximo!) == 0).toList();
    final vencidas = widget.conFecha.where((t) => diasHasta(t.proximo!) < 0).length;
    final futuras = widget.conFecha.where((t) => diasHasta(t.proximo!) > 0).toList()
      ..sort((a, b) => a.proximo!.compareTo(b.proximo!));
    if (hoyT.isNotEmpty) {
      final horas = [for (final t in hoyT) ?t.inicioMin]..sort();
      return 'Hoy tienes ${_mant(hoyT.length)}${horas.isEmpty ? '' : ', el primero a las ${hhmm(horas.first)}'}.';
    }
    final manana = futuras.where((t) => diasHasta(t.proximo!) == 1).length;
    if (_ahora.hour >= 19 && manana > 0) return 'Por hoy, nada más. Mañana tienes ${_mant(manana)}.';
    if (vencidas > 0) return 'Hoy no hay nada programado: buen momento para ponerte al día con lo vencido.';
    if (futuras.isNotEmpty) {
      final d = futuras.first.proximo!;
      final cuando = diasHasta(d) == 1 ? 'mañana' : 'el ${_dias[d.weekday - 1]} ${d.day}';
      return 'Hoy no hay nada programado. El próximo mantenimiento es $cuando.';
    }
    return m('Todo al día. Pultec te avisará cuando toque el siguiente mantenimiento.');
  }

  @override
  Widget build(BuildContext context) {
    // Desde el primer cliente, mostrar las cifras aunque la guía siga pendiente.
    final clientes = industrial ? store.hijosDe(null).length : store.clientes.length;
    // Pultec: solo las órdenes vigentes (las de la pestaña Pendientes), no las del histórico.
    final trabajos = store.tareas.where((t) => !t.esPlantilla && (!industrial || t.estado.abierta)).length;
    final trabajadores = store.trabajadores.length;
    final cifras = [
      (clientes, industrial ? (clientes == 1 ? 'activo' : 'activos') : m(clientes == 1 ? 'cliente' : 'clientes')),
      (trabajos, m(trabajos == 1 ? 'trabajo' : 'trabajos')),
      (trabajadores, m(trabajadores == 1 ? 'trabajador' : 'trabajadores')),
    ];
    if (P.mejorada) return _mejorada(cifras, sinDatos: clientes == 0 && !ajustes.guiaOrganizar);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La fecha, pegada al bloque (abajo de la fila de botones) y alineada con el saludo de dentro.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: _sangriaHero),
                child: Text(
                  fecha,
                  style: TextStyle(color: P.morado, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(_sangriaHero, 18, _sangriaHero, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(P.radio),
            // Pultec: color liso, más sobrio. Pulcón: claro a la izquierda y el morado del logo a la derecha.
            color: industrial ? P.morado : null,
            gradient: industrial
                ? null
                : LinearGradient(
                    colors: [Color.lerp(P.morado, Colors.white, .22)!, Color.lerp(P.morado, Colors.white, .04)!],
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: saludo,
                  children: [
                    if (!industrial)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: ExcludeSemantics(
                            child: CustomPaint(size: const Size.square(36), painter: _IconoSaludo(_ahora.hour)),
                          ),
                        ),
                      ),
                  ],
                ),
                style: TextStyle(
                  fontFamily: P.titulos,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(frase, style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 14.5)),
              const SizedBox(height: 8),
              if (clientes == 0 && !ajustes.guiaOrganizar)
                const Text(
                  'Completa los primeros pasos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                )
              else
                Wrap(
                  spacing: 28,
                  runSpacing: 10,
                  children: [
                    for (final (n, texto) in cifras)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$n ',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            TextSpan(
                              text: texto,
                              style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .82)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

extension on _HeroState {
  /// Vista mejorada: sin bloque de color; fecha, título grande, la frase y las tres cifras en pastillas,
  /// con la ilustración de la planta a la derecha (Pultec), como la maqueta.
  Widget _mejorada(List<(int, String)> cifras, {required bool sinDatos}) {
    final iconos = industrial
        ? const [Marca.iconoCliente, Icons.assignment_outlined, Icons.groups_outlined]
        : [Marca.iconoCliente, Marca.iconoTrabajo, Marca.iconoTrabajador];
    // Presentación: fecha, nombre y frase se escriben uno detrás de otro; luego entran los bloques.
    const dFecha = IntroInicio.fecha;
    final dNombre = dFecha + this.fecha.length / 60 + .1;
    final dFrase = dNombre + saludo.length / 22 + .15;
    IntroInicio.resto = dFrase + frase.length / 90 + .15;
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Escribir(
          this.fecha,
          estilo: TextStyle(color: P.textoSuave, fontSize: 14, fontWeight: FontWeight.w500),
          desde: dFecha,
          porSegundo: 60,
        ),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final estilo = TextStyle(
            fontFamily: P.titulos,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.1,
            color: P.texto,
          );
          // Pultec: el nombre de la empresa se cambia escribiendo encima; se guarda solo.
          // Durante la presentación, se escribe solo; después, el campo editable.
          final nube = store.nube;
          return ValueListenableBuilder<double?>(
            valueListenable: IntroInicio.t,
            // Escrito el nombre, vuelve a ser editable aunque la presentación siga (el borde aún late).
            builder: (context, t, _) => t != null && t < IntroInicio.resto
                ? Escribir(saludo, estilo: estilo, desde: dNombre, porSegundo: 22)
                : industrial && nube != null && nube.esAdmin
                ? _NombreEmpresa(nube, estilo)
                : Text(saludo, style: estilo),
          );
        }),
        const SizedBox(height: 8),
        Escribir(frase, estilo: TextStyle(color: P.textoSuave, fontSize: 16), desde: dFrase, porSegundo: 90),
        const SizedBox(height: 18),
        if (sinDatos)
          Aparecer(
            child: Text(
              'Completa los primeros pasos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: P.texto),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (i, (n, etiqueta)) in cifras.indexed)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: P.superficie.withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(P.radioControl),
                    border: Border.all(color: P.borde),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconos[i], size: 19, color: P.textoSuave),
                      const SizedBox(width: 10),
                      Text('$n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: P.texto)),
                      const SizedBox(width: 6),
                      Text(etiqueta, style: TextStyle(fontSize: 14, color: P.textoSuave)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
    // Sin la foto de la planta, a su alto natural (un alto fijo desbordaba si la frase ocupaba dos líneas). Con ella
    // volvería un Stack con la foto a la derecha y el texto encima:
    // Foto de la planta quitada de momento (pedido 20/11/2026). Ocupaba algo más de la mitad derecha, hasta los
    // bordes de arriba y de la derecha, y se fundía con el fondo; el texto iba encima.
    // Positioned(
    //   top: -margenPagina.top - 16,
    //   right: -margenPagina.right - 12,
    //   bottom: -10,
    //   left: 0,
    //   child: const Align(
    //     alignment: Alignment.centerRight,
    //     child: FractionallySizedBox(widthFactor: .6, heightFactor: 1, child: FotoPlanta()),
    //   ),
    // ),
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: texto);
  }
}

/// Título de Inicio en Pultec: el nombre de la empresa, editable en el sitio (cursor de texto, sin subrayado ni
/// botón de guardar). Se guarda solo al dejar de escribir un momento o al salir del campo.
class _NombreEmpresa extends StatefulWidget {
  final Nube nube;
  final TextStyle estilo;
  const _NombreEmpresa(this.nube, this.estilo);

  @override
  State<_NombreEmpresa> createState() => _NombreEmpresaState();
}

class _NombreEmpresaState extends State<_NombreEmpresa> {
  late final _texto = TextEditingController(text: widget.nube.nombre);
  final _foco = FocusNode();
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _guardar();
    });
  }

  void _guardar() {
    _espera?.cancel();
    final nuevo = _texto.text.trim();
    // Vacío no vale: vuelve el nombre de antes.
    if (nuevo.isEmpty) {
      _texto.text = widget.nube.nombre;
      return;
    }
    if (nuevo != widget.nube.nombre) widget.nube.renombrar(nuevo);
  }

  @override
  void dispose() {
    _guardar();
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si el nombre cambia por otro lado (p. ej. el aviso del primer arranque) y no se está escribiendo, se pone.
    if (!_foco.hasFocus && _texto.text != widget.nube.nombre) _texto.text = widget.nube.nombre;
    return _campo();
  }

  Widget _campo() => TextField(
    controller: _texto,
    focusNode: _foco,
    style: widget.estilo,
    maxLines: 1,
    // Sin caja: ni borde (tampoco al pasar el ratón o escribir), ni fondo, ni márgenes del tema.
    decoration: const InputDecoration(
      hintText: 'Nombre de la empresa',
      isCollapsed: true,
      contentPadding: EdgeInsets.zero,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      hoverColor: Colors.transparent,
    ),
    onChanged: (_) {
      _espera?.cancel();
      _espera = Timer(const Duration(milliseconds: 800), _guardar);
    },
    onSubmitted: (_) => _foco.unfocus(),
  );
}

/// Margen interior del bloque del saludo; la fecha de encima entra lo mismo para alinearse con él.
const _sangriaHero = 22.0;

/// Las huellas de «Primeros pasos» caminando sin parar: la morada recorre el camino una y otra vez, y las demás
/// siguen a la vista. En la presentación, la primera vuelta las va sacando de una en una.
class _HuellasAnimadas extends StatefulWidget {
  const _HuellasAnimadas();

  @override
  State<_HuellasAnimadas> createState() => _HuellasAnimadasState();
}

class _HuellasAnimadasState extends State<_HuellasAnimadas> with SingleTickerProviderStateMixin {
  late final _paseo = AnimationController(vsync: this, duration: const Duration(milliseconds: 4400));
  bool _quietas = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quietas = !animacionesGuia || MediaQuery.disableAnimationsOf(context);
    if (_quietas) {
      _paseo.stop();
    } else if (!_paseo.isAnimating) {
      _paseo.repeat();
    }
  }

  @override
  void dispose() {
    _paseo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: Listenable.merge([_paseo, IntroInicio.t]),
      builder: (context, _) => CustomPaint(
        size: const Size(150, 30),
        painter: _HuellasGuia(
          P.morado.withValues(alpha: .4),
          t: IntroInicio.t.value,
          paseo: _quietas ? null : _paseo.value,
        ),
      ),
    ),
  );
}

/// Pasitos que caminan de izquierda a derecha en una onda (arriba y abajo), junto al título de la guía.
class _HuellasGuia extends CustomPainter {
  final Color color;

  /// Reloj de la presentación (null: sin presentación).
  final double? t;

  /// Por dónde va la vuelta que se repite, de 0 a 1 (null: huellas quietas).
  final double? paseo;
  const _HuellasGuia(this.color, {this.t, this.paseo});

  @override
  void paint(Canvas canvas, Size size) {
    final relleno = Paint()..color = color;
    final centro = size.height / 2, ancho = size.width - 8, amplitud = (size.height / 2 - 4) * .5;
    // Una onda completa y marcada: arriba en la primera mitad, abajo en la segunda.
    double y(double x) => centro - amplitud * sin(2 * pi * x / ancho);
    double pendiente(double x) => -amplitud * cos(2 * pi * x / ancho) * 2 * pi / ancho;
    // Pasos cortos, como al andar: uno cada ~15 px, alternando izquierda y derecha.
    final n = max(4, (ancho / 15).floor());
    final avance = IntroInicio.huellas(t, n);
    // Primera vuelta de la presentación: hasta que la última huella se apaga.
    final estrenando = avance != null && avance < n + 1.6;
    // Cuánto morado lleva una huella según lo que hace que pasó por ella (en huellas).
    double fuerza(double d) => d < 1 ? 1.0 : (1 - (d - 1) / .6).clamp(0.0, 1.0);
    for (var i = 0; i < n; i++) {
      if (estrenando) {
        // Invisible hasta su turno; al salir, opaca y morada; después, vuelve a como está siempre.
        final d = avance - i;
        if (d <= 0) continue;
        final c = Color.lerp(color, P.morado, fuerza(d))!;
        relleno.color = c.withValues(alpha: c.a * (d / .25).clamp(0.0, 1.0));
      } else if (paseo != null) {
        // Se repite sin desaparecer: solo el morado va pasando; al final, una pausa corta antes de volver.
        final d = paseo! * (n + 4) - i;
        final f = d <= 0 ? 0.0 : fuerza(d) * (d / .25).clamp(0.0, 1.0);
        relleno.color = Color.lerp(color, P.morado, f)!;
      } else {
        relleno.color = color;
      }
      final x = 4 + i * (ancho - 4) / (n - 1);
      canvas.save();
      canvas.translate(x, y(x));
      canvas.rotate(atan(pendiente(x)));
      // Pie izquierdo y derecho alternos, a cada lado del camino.
      canvas.translate(0, i.isEven ? -3.2 : 3.2);
      // Algo abierta hacia fuera, como un pie de verdad: planta delante (hacia la derecha) y talón detrás.
      canvas.rotate(i.isEven ? -.18 : .18);
      canvas.drawOval(Rect.fromCenter(center: const Offset(1.6, 0), width: 6.6, height: 4.2), relleno);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-4.2, 0), width: 3.4, height: 3.0), relleno);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HuellasGuia old) => old.t != t || old.paseo != paseo || old.color != color;
}

/// Ilustraciones vectoriales del saludo: amanecer, sol y luna con estrellas.
class _IconoSaludo extends CustomPainter {
  final int hora;
  const _IconoSaludo(this.hora);

  int get periodo => hora >= 6 && hora < 14 ? 0 : (hora >= 14 && hora < 21 ? 1 : 2);

  @override
  void paint(Canvas canvas, Size size) {
    final amanecer = periodo == 0;
    final noche = periodo == 2;
    final centro = Offset(18, amanecer ? 25 : 18);
    // Sin halo: solo el astro y sus rayos.
    final relleno = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: noche
            ? [Colors.white, Color.lerp(P.gris, Colors.white, .8)!]
            : [const Color(0xFFFFE066), const Color(0xFFFFC21A)],
      ).createShader(const Rect.fromLTWH(6, 6, 24, 26));
    final trazo = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    if (noche) {
      final luna = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: const Offset(17, 19), radius: 11)),
        Path()..addOval(Rect.fromCircle(center: const Offset(22, 14), radius: 10)),
      );
      canvas.drawPath(luna, relleno);
      void estrella(Offset centro, double radio) {
        canvas.drawPath(
          Path()
            ..moveTo(centro.dx, centro.dy - radio)
            ..quadraticBezierTo(centro.dx, centro.dy, centro.dx + radio, centro.dy)
            ..quadraticBezierTo(centro.dx, centro.dy, centro.dx, centro.dy + radio)
            ..quadraticBezierTo(centro.dx, centro.dy, centro.dx - radio, centro.dy)
            ..quadraticBezierTo(centro.dx, centro.dy, centro.dx, centro.dy - radio)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: .95),
        );
      }

      estrella(const Offset(27, 9), 3.5);
      estrella(const Offset(29, 25), 2);
      canvas.drawCircle(const Offset(10, 6), 1, Paint()..color = Colors.white.withValues(alpha: .7));
    } else if (amanecer) {
      canvas.drawPath(
        Path()
          ..arcTo(Rect.fromCircle(center: centro, radius: 8), pi, pi, false)
          ..close(),
        relleno,
      );
      for (var i = 1; i <= 5; i++) {
        final angulo = -pi + i * pi / 6;
        final direccion = Offset(cos(angulo), sin(angulo));
        // Rayos alternos: largos y cortos.
        canvas.drawLine(centro + direccion * 11, centro + direccion * (i.isOdd ? 16 : 13.5), trazo);
      }
      canvas.drawLine(const Offset(5, 26), const Offset(31, 26), trazo);
      canvas.drawLine(const Offset(10, 30), const Offset(26, 30), trazo..color = Colors.white.withValues(alpha: .5));
    } else {
      canvas.drawCircle(centro, 7.5, relleno);
      for (var i = 0; i < 8; i++) {
        final direccion = Offset(cos(i * pi / 4), sin(i * pi / 4));
        canvas.drawLine(centro + direccion * 10.5, centro + direccion * (i.isEven ? 16.5 : 13.5), trazo);
      }
    }
  }

  @override
  bool shouldRepaint(_IconoSaludo old) => old.periodo != periodo;
}

/// Cuatro cifras en tarjetas blancas: punto de color, etiqueta, número grande y una nota.
class _Kpis extends StatelessWidget {
  final int hoy, semana, vencidas, hechas;
  final bool dosCol;

  /// Columnas de las cifras en la vista mejorada (4, 2 o 1, según el ancho).
  final int columnas;
  final ValueChanged<int> onTap;

  /// Cifra marcada (Pultec: filtra las órdenes de debajo); 0 = ninguna.
  final int elegida;
  const _Kpis({
    this.elegida = 0,
    required this.onTap,
    required this.hoy,
    required this.semana,
    required this.vencidas,
    required this.hechas,
    required this.dosCol,
    this.columnas = 4,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.today_rounded, 'Para hoy', hoy, P.morado, 'en agenda'),
      industrial
          // Sin color, como «Sin asignar» en las columnas y filtros.
          ? (Icons.person_off_outlined, 'Sin asignar', semana, P.gris, 'órdenes por asignar')
          : (Icons.date_range_rounded, 'Esta semana', semana, P.teal, 'próximos 7 días'),
      (
        Icons.warning_amber_rounded,
        'Vencidos',
        vencidas,
        P.rojo,
        vencidas == 0 ? '¡todo al día!' : 'requieren atención',
      ),
      industrial
          ? (Icons.task_alt_rounded, 'Histórico', hechas, P.verde, 'órdenes cerradas')
          : (Icons.task_alt_rounded, 'Hechos', hechas, P.verde, 'últimos 30 días'),
    ];
    if (P.mejorada) {
      return Rejilla(
        columnas: columnas,
        hueco: 16,
        children: [
          for (final (i, (icono, etiqueta, valor, color, nota)) in items.indexed)
            _KpiMejorada(
              icono: icono,
              etiqueta: etiqueta,
              valor: valor,
              color: color,
              nota: nota,
              elegida: elegida == i + 1,
              onTap: () => onTap(i + 1),
            ),
        ],
      );
    }
    return Rejilla(
      columnas: dosCol ? 4 : 2,
      children: [
        for (final (i, (icono, etiqueta, valor, color, nota)) in items.indexed)
          // Tarjeta blanca con una barra de su color abajo del todo; al tocarla, abre esos trabajos.
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onTap(i + 1),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: P.superficie,
                  borderRadius: BorderRadius.circular(P.radio),
                  border: Border.all(color: elegida == i + 1 ? color : P.borde, width: elegida == i + 1 ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Cifra(
                              etiqueta,
                              valor,
                              nota: nota,
                              tamano: 32,
                              color: color == P.rojo && valor > 0 ? P.rojo : null,
                              punto: color,
                            ),
                          ),
                          // Icono arriba a la derecha para reconocer la cifra de un vistazo.
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle),
                            child: Icon(icono, size: 17, color: color),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 4, color: color),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cifra de Inicio en la vista mejorada: icono en un cuadro de su color a la izquierda, etiqueta, número
/// grande y nota; fondo con un leve tinte de su color, sombra y la barra de color abajo. Se marca al pasar.
class _KpiMejorada extends StatefulWidget {
  final IconData icono;
  final String etiqueta, nota;
  final int valor;
  final Color color;
  final bool elegida;
  final VoidCallback onTap;
  const _KpiMejorada({
    required this.icono,
    required this.etiqueta,
    required this.nota,
    required this.valor,
    required this.color,
    required this.elegida,
    required this.onTap,
  });

  @override
  State<_KpiMejorada> createState() => _KpiMejoradaState();
}

class _KpiMejoradaState extends State<_KpiMejorada> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(P.radio),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [P.superficie, Color.lerp(P.superficie, c, ajustes.oscuro ? .1 : .05)!],
            ),
            border: Border.all(
              color: widget.elegida ? c : (hover ? c.withValues(alpha: .4) : P.borde),
              width: widget.elegida ? 2 : 1,
            ),
            boxShadow: P.sombra,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(widget.icono, size: 26, color: c),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: P.texto),
                          ),
                          const SizedBox(height: 2),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: widget.valor.toDouble()),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => Text(
                              '${v.round()}',
                              style: TextStyle(
                                fontFamily: P.titulos,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                height: 1.15,
                                color: c == P.rojo && widget.valor > 0 ? P.rojo : P.texto,
                              ),
                            ),
                          ),
                          Text(
                            widget.nota,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: P.textoSuave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 4, color: c),
            ],
          ),
        ),
      ),
    );
  }
}

/// Punto de color para marcar una fila sin recurrir a un icono.
Widget _punto(Color c) => Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);
