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
import 'planificacion.dart';
import 'tarea_card.dart';
import '../marca.dart';
import '../industrial/activos.dart' show abrirActivoForm, abrirListaActivos;
import '../industrial/vistazo.dart';

/// Inicio: saludo, cifras clave, lo pendiente, la carga del equipo y los próximos mantenimientos
/// como las tarjetas de la landing. Sin gráficas de relleno: solo lo que se mira cada mañana.
class Resumen extends StatelessWidget {
  final ValueChanged<Seccion> onIr;
  final ValueChanged<String> onTrabajador;

  /// Abre la ficha de un cliente (desde las estadísticas).
  final ValueChanged<String>? onCliente;
  const Resumen({super.key, required this.onIr, required this.onTrabajador, this.onCliente});

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
    final pasos = ajustes.guiaOrganizar ? const [true, true, true, true] : [
      industrial ? store.activos.isNotEmpty : store.clientes.isNotEmpty,
      hayTarea,
      hayTarea && ajustes.guiaItinerario,
      hayTrabajador && hayTarea && ajustes.guiaOrganizar && hayTrabajoAsignado,
    ];

    // Solo se reconstruye al pasar de una a dos columnas; el resto del ancho lo resuelve la maquetación.
    return SegunTamano(
      clave: (box) => min(1080.0, box.maxWidth - margenPagina.horizontal) > 760,
      builder: (context, box) {
        final dosCol = min(1080.0, box.maxWidth - margenPagina.horizontal) > 760;
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

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            margenPagina.left,
            margenPagina.top + 16,
            margenPagina.right,
            margenPagina.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(conFecha: conFecha, pasos: pasos),
                  const SizedBox(height: 16),
                  if (pasos.contains(false)) ...[_PrimerosPasos(pasos, onIr: onIr), const SizedBox(height: 16)],
                  // Sin ningún trabajo todo serían ceros y paneles vacíos: en su lugar, cómo funciona Pulpo.
                  if (!hayTarea && !ajustes.guiaOrganizar) _ComoFunciona(columnas: dosCol),
                  if (hayTarea) ...[
                    _Kpis(
                      hoy: hoyT.length,
                      semana: semana.length,
                      vencidas: vencidas.length,
                      hechas: hechas30,
                      dosCol: dosCol,
                    ),
                    // iPultec: bajo las cifras, las máquinas por tipo de mantenimiento pendiente.
                    if (industrial && store.activos.isNotEmpty) ...[
                      AvisosPreparacion(onAbrir: onCliente ?? (_) {}),
                      const SizedBox(height: 32),
                      VistazoActivos(
                        onAbrir: onCliente ?? (_) {},
                        onVerMas: (f) {
                          abrirListaActivos(f);
                          onIr(Seccion.clientes);
                        },
                        columnas: dosCol ? 3 : 1,
                      ),
                      const SizedBox(height: 32),
                    ] else
                      const SizedBox(height: 16),
                    par(
                      _Pendientes(vencidas: vencidas, sinTrabajador: sinTrabajador, onIr: onIr),
                      _CargaTrabajadores(onTrabajador: onTrabajador),
                    ),
                    const SizedBox(height: 32),
                    _Proximos(conFecha, onIr: onIr, columnas: dosCol ? 2 : 1),
                    // Las estadísticas son de clientes y equipos: en iPultec su lugar lo ocupa el vistazo.
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
  }
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

/// Para una cuenta sin trabajos: el ciclo de Pulpo en tres tarjetas y qué cifras verá en Inicio.
/// Desaparece con el primer trabajo y deja paso a las cifras y los paneles.
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
              'Sus órdenes de trabajo',
              'Qué mantenimiento lleva cada componente, cada cuánto y de qué tipo. iPultec calcula cuándo toca y avisa de lo que vence.',
            ),
            (P.ambar, 'iPultec organiza', 'Reparte las órdenes de trabajo entre tus técnicos según su categoría.'),
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
              m('Qué hay que revisar y cada cuánto. Pulpo calcula cuándo toca y avisa de lo que vence.'),
            ),
            (
              P.ambar,
              m('Pulpo organiza'),
              m('Reparte los trabajos entre tu equipo según lo que sabe hacer y traza la ruta del día.'),
            ),
          ];
    final tarjetas = [
      for (final (i, (color, titulo, texto)) in etapas.indexed)
        Tarjeta(
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
    ];
    final cifras = [
      for (final (color, titulo, texto) in const [
        (P.azul, 'Para hoy', 'Los mantenimientos que tocan hoy, con su técnico.'),
        (P.teal, 'Esta semana', 'Lo que viene en los próximos 7 días.'),
        (P.rojo, 'Vencidos', 'Lo que se pasó de fecha, para recuperarlo antes.'),
        (P.verde, 'Hechos', 'Lo terminado en los últimos 30 días.'),
      ])
        Tarjeta(
          padding: const EdgeInsets.all(16),
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
                  const SizedBox(width: 8),
                  Text(titulo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Text(texto, style: TextStyle(fontSize: 12.5, height: 1.4, color: P.textoSuave)),
            ],
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            m('Cómo funciona Pulpo'),
            style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.3),
          ),
        ),
        if (columnas)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, t) in tarjetas.indexed) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: t)],
              ],
            ),
          )
        else
          for (final (i, t) in tarjetas.indexed) ...[if (i > 0) const SizedBox(height: 12), t],
        const SizedBox(height: 24),
        // iPultec: el color de cada máquina, que verá en Inicio en cuanto dé de alta sus activos.
        if (industrial) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'El color de cada máquina',
              style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.3),
            ),
          ),
          Tarjeta(child: LeyendaEstados(columnas: columnas)),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Lo que verás aquí',
            style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.3),
          ),
        ),
        // Avance de las cifras de Inicio: qué mide cada una, sin ceros.
        if (columnas)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in cifras.indexed) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: c)],
              ],
            ),
          )
        else
          for (final (i, c) in cifras.indexed) ...[if (i > 0) const SizedBox(height: 12), c],
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
    final pasos = [
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
                  'tipo (preventivo, correctivo no crítico o crítico). iPultec calcula cuándo toca.'
            : m(
                'Un mantenimiento que se repite: qué hay que revisar y cada cuánto. Pulpo calcula cuándo toca. '
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
        !hayTrabajador ? m('Añade un trabajador') : m('Deja que Pulpo organice tu primer trabajo'),
        !hayTrabajador
            ? m('Quién hace los mantenimientos. Indica qué sabe hacer y Pulpo le propondrá los trabajos que le encajan.')
            : m(
                Marca.mapa
                    ? 'Ve al itinerario y pulsa Organizar. Pulpo asignará el trabajo al técnico y trazará la ruta.'
                    : 'Ve al itinerario y pulsa Organizar. Pulpo asignará el trabajo al técnico según su categoría.',
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
            : (Icons.calendar_month_outlined, 'Itinerario', 'Organizar', Seccion.planificacion, _semanaDelTrabajo),
        null,
      ),
    ];
    final actual = hechos.indexOf(false);
    // Borde discontinuo: es una guía de paso, no una tarjeta de datos.
    return CustomPaint(
      foregroundPainter: BordeDiscontinuo(P.gris.withValues(alpha: .4), BorderRadius.circular(P.radio), separacion: 6),
      child: Tarjeta(
        color: P.superficie,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
        child: Column(
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
                    child: CustomPaint(
                      size: const Size(150, 30),
                      painter: _HuellasGuia(P.morado.withValues(alpha: .4)),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${hechos.where((h) => h).length} de ${pasos.length}',
                  style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (i, (titulo, detalle, ruta, boton)) in pasos.indexed)
              IntrinsicHeight(
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
          ],
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
          derecha: _cat('Itinerario'),
          onTap: () => onIr(Seccion.planificacion),
        ),
      if (sinTrabajador.isNotEmpty)
        FilaLista(
          lider: _punto(P.morado),
          titulo: m('${sinTrabajador.length} sin trabajador esta semana'),
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
      accion: filas.isEmpty ? null : Pill('${filas.length}', P.rojo),
      children: filas.isEmpty
          ? [
              const SizedBox(
                height: 140,
                child: Vacio(icono: Icons.task_alt_rounded, texto: 'Nada pendiente. ¡Todo al día!'),
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
      subtitulo: m('Trabajos asignados en los próximos 7 días'),
      sinFilas: true,
      children: [
        if (ws.isEmpty)
          SizedBox(
            height: 140,
            child: Vacio(icono: Marca.iconoTrabajador, texto: m('Aún no hay trabajadores')),
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
    // iPultec: tono de planta, sin saludo ni sol.
    if (industrial) return 'Estado de ${store.nube?.nombre ?? 'la planta'}';
    final h = _ahora.hour;
    return h >= 6 && h < 14 ? 'Buenos días' : (h >= 14 && h < 21 ? 'Buenas tardes' : 'Buenas noches');
  }

  String get fecha => 'Hoy es ${_dias[_ahora.weekday - 1]}, ${_ahora.day} de ${_meses[_ahora.month - 1]}';

  static String _mant(int n) => '$n ${n == 1 ? 'mantenimiento' : 'mantenimientos'}';

  /// Primera vez: bienvenida; con la guía a medias: lo que falta; después, el día (y por la noche, mañana).
  String get frase {
    final pasos = widget.pasos;
    final quedan = pasos.where((p) => !p).length;
    if (quedan == pasos.length) {
      return m('Te damos la bienvenida a Pulpo. En unos minutos tendrás tu mantenimiento en marcha.');
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
    return m('Todo al día. Pulpo te avisará cuando toque el siguiente mantenimiento.');
  }

  @override
  Widget build(BuildContext context) {
    // Desde el primer cliente, mostrar las cifras aunque la guía siga pendiente.
    final clientes = industrial ? store.hijosDe(null).length : store.clientes.length;
    final trabajos = store.tareas.where((t) => !t.esPlantilla).length;
    final trabajadores = store.trabajadores.length;
    final cifras = [
      (clientes, industrial ? (clientes == 1 ? 'activo' : 'activos') : m(clientes == 1 ? 'cliente' : 'clientes')),
      (trabajos, m(trabajos == 1 ? 'trabajo' : 'trabajos')),
      (trabajadores, m(trabajadores == 1 ? 'trabajador' : 'trabajadores')),
    ];
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
            // iPultec: color liso, más sobrio. Pulpo: claro a la izquierda y el morado del logo a la derecha.
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

/// Margen interior del bloque del saludo; la fecha de encima entra lo mismo para alinearse con él.
const _sangriaHero = 22.0;

/// Pasitos que caminan de izquierda a derecha en una onda (arriba y abajo), junto al título de la guía.
class _HuellasGuia extends CustomPainter {
  final Color color;
  const _HuellasGuia(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final relleno = Paint()..color = color;
    final centro = size.height / 2, ancho = size.width - 8, amplitud = size.height / 2 - 4;
    // Una onda completa y marcada: arriba en la primera mitad, abajo en la segunda.
    double y(double x) => centro - amplitud * sin(2 * pi * x / ancho);
    double pendiente(double x) => -amplitud * cos(2 * pi * x / ancho) * 2 * pi / ancho;
    final n = max(4, (ancho / 26).floor());
    for (var i = 0; i < n; i++) {
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
  bool shouldRepaint(_HuellasGuia old) => false;
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
  const _Kpis({
    required this.hoy,
    required this.semana,
    required this.vencidas,
    required this.hechas,
    required this.dosCol,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.today_rounded, 'Para hoy', hoy, P.morado, 'en agenda'),
      (Icons.date_range_rounded, 'Esta semana', semana, P.teal, 'próximos 7 días'),
      (
        Icons.warning_amber_rounded,
        'Vencidos',
        vencidas,
        P.rojo,
        vencidas == 0 ? '¡todo al día!' : 'requieren atención',
      ),
      (Icons.task_alt_rounded, 'Hechos', hechas, P.verde, 'últimos 30 días'),
    ];
    return Rejilla(
      columnas: dosCol ? 4 : 2,
      children: [
        for (final (icono, etiqueta, valor, color, nota) in items)
          // Tarjeta blanca con una barra de su color abajo del todo.
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: P.superficie,
              borderRadius: BorderRadius.circular(P.radio),
              border: Border.all(color: P.borde),
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
      ],
    );
  }
}

/// Punto de color para marcar una fila sin recurrir a un icono.
Widget _punto(Color c) => Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);
