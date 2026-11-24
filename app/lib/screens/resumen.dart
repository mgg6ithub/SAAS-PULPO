import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../estadisticas.dart';
import '../forms.dart';
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
                        IncidenciasAbiertas(onAbrir: onTarea ?? (_) {}),
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
                      const SizedBox(height: 32),
                    ] else if (industrial && store.activos.isNotEmpty) ...[
                      AvisosPreparacion(onAbrir: onCliente ?? (_) {}),
                      const SizedBox(height: 32),
                      // Lo primero que hay que atender: partes con incidencia o sin hacer.
                      IncidenciasAbiertas(onAbrir: onTarea ?? (_) {}),
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
              icono: Icons.layers_outlined,
              titulo: 'Sin máquinas',
              texto:
                  'Da de alta un activo y sus mantenimientos: Pultec creará las órdenes de trabajo y avisará de lo que toca.',
              accion: BotonPrimario(
                'Activo',
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
                  ? 'Tus máquinas aún no tienen mantenimientos. Crea uno y Pultec generará sus órdenes de trabajo '
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
            (P.azul, 'Tus activos', 'Cada máquina (camión, compresor, prensa…) con sus componentes y subcomponentes.'),
            (
              P.teal,
              'Sus mantenimientos',
              'Qué mantenimiento lleva cada componente y cada cuánto: por fecha o por horas de uso.',
            ),
            (
              P.ambar,
              'Órdenes de trabajo automáticas',
              'Pultec las crea cuando toca cada mantenimiento y las reparte entre tus técnicos según su categoría.',
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
      for (final (i, (color, titulo, texto)) in etapas.indexed)
        Aparecer(
          retraso: .85 + i * .14,
          child: Tarjeta(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barrita de color en lugar de icono, con el número de la etapa.
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 4,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${i + 1}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
        color: P.textoSuave,
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
        const SizedBox(height: 24),
        // Pultec: el color de cada orden de trabajo, que verá en Inicio en cuanto dé de alta sus activos.
        if (industrial) ...[
          titulo('El color de cada máquina'),
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

/// Guía de primeros pasos (como la de Google Play Console): índice vertical con ticks que se marcan y
/// desmarcan solos según los datos. A la derecha de cada paso, dónde se hace en la app; solo el paso
/// en curso lleva su botón. Desaparece al completarla.
class _PrimerosPasos extends StatelessWidget {
  /// Hecho o no, por paso: cliente, trabajo, ver el itinerario, trabajador.
  final List<bool> hechos;
  final ValueChanged<Seccion> onIr;
  const _PrimerosPasos(this.hechos, {required this.onIr});

  /// Pasos de Pultec: máquina, su mantenimiento (la OT se crea sola), un técnico y asignarle la orden.
  List<(String, String, (IconData, String, String, Seccion, Future<void> Function(BuildContext))?, Widget?)>
  _pasosPultec(bool hayTrabajador) => [
    (
      'Da de alta tu primera máquina',
      'Un camión, un compresor, una prensa… Pon su contador de horas y cuánto se usa: así Pultec sabe cuándo le '
          'toca cada mantenimiento por horas.',
      (Marca.iconoCliente, 'Activos', 'Nuevo activo', Seccion.clientes, (c) async => abrirActivoForm(c)),
      null,
    ),
    (
      'Crea su primer mantenimiento',
      'Dentro del activo, «+ Mantenimiento»: qué hay que hacer y cada cuánto (días u horas). Pultec crea su orden '
          'de trabajo para la fecha que toca y, al completarla, la siguiente.',
      (
        Marca.iconoCliente,
        'Activos',
        'Mantenimiento',
        Seccion.clientes,
        (c) async {
          final a = store.activos.where((a) => a.padreId == null).firstOrNull;
          if (a != null) await abrirPlanForm(c, activoId: a.id);
        },
      ),
      null,
    ),
    (
      'Añade un técnico',
      'Quién hace los mantenimientos y de qué categoría es. Con eso Pultec le asigna sus órdenes.',
      (
        Marca.iconoTrabajador,
        'Técnicos',
        'Nuevo técnico',
        Seccion.trabajadores,
        (c) async => abrirTrabajadorForm(c, null, const []),
      ),
      null,
    ),
    (
      'Asigna la orden a un técnico',
      'En Órdenes de trabajo, elige quién la hace. Le llegará a su móvil con todo lo que necesita.',
      (Marca.iconoTrabajo, 'Órdenes de trabajo', 'Asignar', Seccion.tareas, (c) async {}),
      null,
    ),
  ];

  /// Deja el itinerario en la semana del último trabajo, para organizar el día en que cae.
  Future<void> _semanaDelTrabajo(BuildContext context) async {
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
    // que lleva a su sección y abre el formulario, para que se aprenda dónde está. Ver el itinerario: su botón.
    final hayTrabajador = store.trabajadores.any((w) => w.activo);
    final pasos = industrial ? _pasosPultec(hayTrabajador) : [
      industrial
          ? (
              'Da de alta tu primera máquina',
              'Un activo: un camión, un compresor, una prensa… Dentro, sus componentes con su tag, fabricante y modelo.',
              (Marca.iconoCliente, 'Activos', 'Nuevo activo', Seccion.clientes, (c) => abrirActivoForm(c)),
              null,
            )
          : (
              m('Crea tu primer cliente'),
              'A quien le haces el mantenimiento: una comunidad, una empresa, un local, una instalación…',
              (Marca.iconoCliente, m('Clientes'), m('Nuevo cliente'), Seccion.clientes, abrirClienteForm),
              null,
            ),
      (
        m('Crea un trabajo'),
        industrial
            ? 'Un mantenimiento de una máquina o de uno de sus componentes: qué hay que hacer, cada cuánto y de qué '
                  'tipo (preventivo, correctivo no crítico o crítico). Pultec calcula cuándo toca.'
            : m(
                'Un mantenimiento que se repite: qué hay que revisar y cada cuánto. Pultec calcula cuándo toca. '
                'También puedes crearlo desde la ficha del cliente.',
              ),
        (Marca.iconoTrabajo, m('Trabajos'), m('Nuevo trabajo'), Seccion.tareas, (c) => abrirTareaForm(c, null)),
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
            // Con las competencias de los trabajos ya creados, Organizar podrá asignar el primero.
            ? (
                Marca.iconoTrabajador,
                m('Trabajadores'),
                m('Nuevo trabajador'),
                Seccion.trabajadores,
                (c) => abrirTrabajadorForm(
                  c,
                  null,
                  {for (final t in store.tareas.where((t) => !t.esPlantilla)) ...t.competencias}.toList(),
                ),
              )
            : (Icons.calendar_month_outlined, (industrial ? 'Planificación' : 'Itinerario'), 'Organizar', Seccion.planificacion, _semanaDelTrabajo),
        null,
      ),
    ];
    final actual = hechos.indexOf(false);
    // Borde discontinuo: es una guía de paso, no una tarjeta de datos.
    // En la presentación, el borde late entre neutro y morado mientras se recorren los pasos.
    return ValueListenableBuilder<double?>(
      valueListenable: IntroInicio.t,
      builder: (context, t, child) => CustomPaint(
        foregroundPainter: BordeDiscontinuo(
          Color.lerp(P.gris.withValues(alpha: .4), P.morado, IntroInicio.latido(t))!,
          BorderRadius.circular(P.radio + 6),
          separacion: 6,
        ),
        child: child,
      ),
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
                  ExcludeSemantics(
                    // En la presentación, las huellas salen de una en una (la del momento, más morada).
                    child: ValueListenableBuilder<double?>(
                      valueListenable: IntroInicio.t,
                      builder: (context, t, _) => CustomPaint(
                        size: const Size(150, 30),
                        painter: _HuellasGuia(P.morado.withValues(alpha: .4), t: t),
                      ),
                    ),
                  ),
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
                                  onTap: () async {
                                    // Itinerario: se prepara la semana antes de entrar.
                                    if (ruta.$4 == Seccion.planificacion) {
                                      await ruta.$5(context);
                                      onIr(ruta.$4);
                                      return;
                                    }
                                    // Crear: primero se entra en la sección y, tras un momento para que se vea
                                    // dónde estamos, se abre el formulario como si se hubiera pulsado allí.
                                    onIr(ruta.$4);
                                    await Future.delayed(const Duration(milliseconds: 900));
                                    if (context.mounted) ruta.$5(context);
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
              SizedBox(
                height: P.mejorada ? 170 : 140,
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
    if (industrial && store.activos.isEmpty) return 'Aún no hay máquinas. Da de alta la primera para empezar.';
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
    final dNombre = dFecha + this.fecha.length / 45 + .15;
    final dFrase = dNombre + saludo.length / 14 + .2;
    IntroInicio.resto = dFrase + frase.length / 90 + .15;
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Escribir(
          this.fecha,
          estilo: TextStyle(color: P.textoSuave, fontSize: 14, fontWeight: FontWeight.w500),
          desde: dFecha,
          porSegundo: 45,
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
            builder: (context, t, _) => t != null
                ? Escribir(saludo, estilo: estilo, desde: dNombre, porSegundo: 14)
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

/// Pasitos que caminan de izquierda a derecha en una onda (arriba y abajo), junto al título de la guía.
class _HuellasGuia extends CustomPainter {
  final Color color;

  /// Reloj de la presentación (null: todas las huellas tal cual).
  final double? t;
  const _HuellasGuia(this.color, {this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final relleno = Paint()..color = color;
    final centro = size.height / 2, ancho = size.width - 8, amplitud = size.height / 2 - 4;
    // Una onda completa y marcada: arriba en la primera mitad, abajo en la segunda.
    double y(double x) => centro - amplitud * sin(2 * pi * x / ancho);
    double pendiente(double x) => -amplitud * cos(2 * pi * x / ancho) * 2 * pi / ancho;
    final n = max(4, (ancho / 26).floor());
    final avance = IntroInicio.huellas(t, n);
    for (var i = 0; i < n; i++) {
      // Presentación: invisible hasta su turno; al salir, opaca y morada; después, vuelve a como está siempre.
      if (avance != null) {
        final d = avance - i;
        if (d <= 0) continue;
        final fuerte = d < 1 ? 1.0 : (1 - (d - 1) / .6).clamp(0.0, 1.0);
        final c = Color.lerp(color, P.morado, fuerte)!;
        relleno.color = c.withValues(alpha: c.a * (d / .25).clamp(0.0, 1.0));
      } else {
        relleno.color = color;
      }
      final x = 4 + i * (ancho - 4) / (n - 1);
      canvas.save();
      canvas.translate(x, y(x));
      canvas.rotate(atan(pendiente(x)));
      // Pie izquierdo y derecho alternos, a cada lado del camino.
      canvas.translate(0, i.isEven ? -3.6 : 3.6);
      // Planta delante (hacia la derecha) y talón detrás: se ve hacia dónde camina.
      canvas.drawOval(Rect.fromCenter(center: const Offset(2, 0), width: 8.5, height: 5.4), relleno);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-5.5, 0), width: 4.4, height: 3.8), relleno);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HuellasGuia old) => old.t != t || old.color != color;
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
