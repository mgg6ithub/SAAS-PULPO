import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'historial.dart';
import 'industrial/incidencia.dart';
import 'industrial/mantenimientos.dart' show abrirIncidenciaForm;
import 'marca.dart';
import 'models.dart';
import 'screens/vista_trabajador.dart' show FotoTecnico;
import 'forms.dart' show formulariosAbiertos;
import 'store.dart';
import 'theme.dart';
import 'widgets.dart' show Pestanas;

/// Un aviso para el administrador: qué ha pasado, en qué color (verde hecho, rojo urgente, ámbar pendiente),
/// cuándo y qué abre al pulsarlo.
class Aviso {
  final String id, titulo, detalle;
  final Color color;
  final DateTime cuando;
  final bool urgente;
  final String? tareaId, activoId;

  /// Aviso de una incidencia: al pulsarlo se abre para revisarla.
  final Incidencia? incidencia;

  /// De quién va el aviso, para poner su foto (null = de nadie en concreto).
  final String? trabajadorId;
  const Aviso({
    required this.id,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.cuando,
    this.urgente = false,
    this.tareaId,
    this.activoId,
    this.incidencia,
    this.trabajadorId,
  });
}

/// Días hacia atrás que se miran (lo de antes ya no es noticia).
const _dias = 14;

String _tecnico(String? id) => id == null ? 'Un técnico' : (store.trabajador(id)?.nombre ?? 'Un técnico');

String _activo(String? id) => store.activo(id)?.titulo ?? '';

/// Avisos sacados de los datos, que llegan en tiempo real: OT completadas (o cerradas con problemas), incidencias
/// que comunican los técnicos y las órdenes de hoy o vencidas que nadie tiene. Lo más reciente primero.
List<Aviso> avisosAhora() {
  final h = hoy();
  final lista = <Aviso>[];
  for (final t in store.tareas) {
    if (t.esPlantilla || t.ultimo == null || diasHasta(t.ultimo!) < -_dias) continue;
    if (t.estado != EstadoTrabajo.realizado) continue;
    final quien = _tecnico(t.ejecutadoPor ?? t.trabajadorIds.firstOrNull);
    final problema = industrial && (t.resultado == 1 || t.resultado == 2) && !t.resultadoResuelto;
    lista.add(
      Aviso(
        id: 'ot-${t.id}-${t.ultimo!.toIso8601String().substring(0, 10)}',
        titulo: problema
            ? (t.resultado == 2 ? '$quien no pudo hacer ${t.nombre}' : '$quien cerró ${t.nombre} con incidencias')
            : '$quien completó ${t.nombre}',
        detalle: _activo(t.activoId),
        color: problema ? P.rojo : P.verde,
        urgente: problema,
        cuando: t.ultimo!,
        tareaId: t.id,
        trabajadorId: t.ejecutadoPor ?? t.trabajadorIds.firstOrNull,
      ),
    );
  }
  for (final i in store.incidencias) {
    if (store.estadoIncidencia(i) != EstadoIncidencia.abierta || i.creada.isBefore(masDias(h, -_dias))) continue;
    lista.add(
      Aviso(
        id: 'inc-${i.id}',
        titulo: '${_tecnico(i.tecnicoId)} comunicó una incidencia',
        detalle: [_activo(i.activoId), i.descripcion].where((x) => x.isNotEmpty).join(': '),
        color: P.rojo,
        urgente: true,
        cuando: i.creada,
        incidencia: i,
        trabajadorId: i.tecnicoId,
      ),
    );
    // Si quien la comunicó la corrige, otro aviso (uno por cada corrección).
    final e = i.editadaEl;
    if (e != null && !e.isBefore(masDias(h, -_dias))) {
      lista.add(
        Aviso(
          id: 'inc-${i.id}-editada-${e.millisecondsSinceEpoch}',
          titulo: '${_tecnico(i.tecnicoId)} modificó una incidencia',
          detalle: [_activo(i.activoId), i.descripcion].where((x) => x.isNotEmpty).join(': '),
          color: P.ambar,
          cuando: e,
          incidencia: i,
          trabajadorId: i.tecnicoId,
        ),
      );
    }
  }
  final sinTecnico = store.tareas
      .where(
        (t) =>
            !t.esPlantilla &&
            t.activa &&
            t.estado.abierta &&
            t.trabajadorIds.isEmpty &&
            t.proximo != null &&
            diasHasta(t.proximo!) <= 0,
      )
      .length;
  if (sinTecnico > 0) {
    lista.add(
      Aviso(
        // Cambia con el día y el número: si aparecen más, vuelve a avisar.
        id: 'sintecnico-${h.toIso8601String().substring(0, 10)}-$sinTecnico',
        titulo: industrial
            ? (sinTecnico == 1 ? '1 orden de hoy o vencida sin técnico' : '$sinTecnico órdenes de hoy o vencidas sin técnico')
            : (sinTecnico == 1 ? '1 trabajo de hoy o vencido sin técnico' : '$sinTecnico trabajos de hoy o vencidos sin técnico'),
        detalle: 'Asígnalos para que alguien los reciba',
        color: P.ambar,
        cuando: h,
      ),
    );
  }
  // Técnicos ausentes u ocupados con órdenes pendientes para esta semana (o vencidas): uno por técnico.
  final porTecnico = <Trabajador, List<Tarea>>{};
  for (final t in store.tareas) {
    if (t.esPlantilla || !t.activa || !t.estado.abierta || t.proximo == null || diasHasta(t.proximo!) > 7) continue;
    for (final id in t.trabajadorIds) {
      final w = store.trabajador(id);
      if (w != null && w.estadoHoy != EstadoHoy.disponible) (porTecnico[w] ??= []).add(t);
    }
  }
  for (final MapEntry(key: w, value: ots) in porTecnico.entries) {
    ots.sort((a, b) => a.proximo!.compareTo(b.proximo!));
    final estado = w.estadoHoy.etiqueta.toLowerCase();
    lista.add(
      Aviso(
        // Cambia con el día, el estado y las órdenes: si algo cambia, vuelve a avisar.
        id: 'tecnico-${w.id}-${h.toIso8601String().substring(0, 10)}-${w.estadoHoy.name}-${ots.length}',
        titulo: ots.length == 1
            ? '${w.nombre} está $estado y tiene la orden ${ots.first.nombre}'
            : '${w.nombre} está $estado y tiene ${ots.length} órdenes pendientes',
        detalle: [
          for (final t in ots.take(3)) '${t.nombre} (${fecha(t.proximo)})',
          if (ots.length > 3) 'y ${ots.length - 3} más',
        ].join(', '),
        color: w.estadoHoy == EstadoHoy.ausente ? P.rojo : P.ambar,
        urgente: w.estadoHoy == EstadoHoy.ausente,
        cuando: h,
        tareaId: ots.first.id,
        trabajadorId: w.id,
      ),
    );
  }
  return lista..sort((a, b) => b.cuando.compareTo(a.cuando));
}

/// Cuándo se vio cada aviso por primera vez con la app abierta: así lo que llega en vivo dice «Ahora» o
/// «Hace 5 min» y sale arriba, aunque la OT solo guarde el día.
final _vistoEn = <String, DateTime>{};

/// Campana abajo a la derecha (vista de administrador) con el número de avisos sin leer. Al pulsarla sube el
/// panel de avisos; lo que llega mientras tanto asoma un momento encima de la campana.
class Notificaciones extends StatefulWidget {
  final ValueChanged<String> onTarea, onActivo;
  final VoidCallback onSinTecnico;
  const Notificaciones({super.key, required this.onTarea, required this.onActivo, required this.onSinTecnico});

  @override
  State<Notificaciones> createState() => _NotificacionesState();
}

class _NotificacionesState extends State<Notificaciones> {
  bool abierto = false;

  /// 0 = Notificaciones, 1 = Historial.
  int pestana = 0;
  Set<String> leidos = {};
  Set<String>? _conocidos;
  Aviso? nuevo;
  Timer? _ocultar;
  SharedPreferences? _prefs;

  String get _clave => 'avisos_leidos_${store.nube?.empresaId ?? 'local'}';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _prefs = p;
        leidos = {...?p.getStringList(_clave)};
      });
    });
    // Lo que ya había al abrir la app no es «nuevo»; lo que llegue después, sí.
    _conocidos = {for (final a in avisosAhora()) a.id};
    store.addListener(_alCambiar);
  }

  @override
  void dispose() {
    store.removeListener(_alCambiar);
    _ocultar?.cancel();
    super.dispose();
  }

  /// Lo que aparece ahora y no estaba: se apunta su hora y el más reciente asoma unos segundos.
  void _alCambiar() {
    final ids = {for (final a in avisosAhora()) a.id};
    final llegados = ids.difference(_conocidos ?? ids);
    _conocidos = ids;
    if (llegados.isEmpty || !mounted) return;
    final ahora = DateTime.now();
    for (final id in llegados) {
      _vistoEn[id] = ahora;
    }
    final a = _ordenados().firstWhere((a) => llegados.contains(a.id), orElse: () => _ordenados().first);
    setState(() => nuevo = abierto ? null : a);
    _ocultar?.cancel();
    _ocultar = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => nuevo = null);
    });
  }

  List<Aviso> _ordenados() {
    final l = avisosAhora();
    DateTime t(Aviso a) => _vistoEn[a.id] ?? a.cuando;
    return l..sort((a, b) => t(b).compareTo(t(a)));
  }

  void _guardar() => _prefs?.setStringList(_clave, leidos.toList());

  void _abrir(Aviso a) {
    setState(() {
      leidos.add(a.id);
      abierto = false;
    });
    _guardar();
    if (a.incidencia != null) {
      abrirIncidenciaForm(context, original: a.incidencia);
    } else if (a.tareaId != null) {
      widget.onTarea(a.tareaId!);
    } else if (a.activoId != null) {
      widget.onActivo(a.activoId!);
    } else {
      widget.onSinTecnico();
    }
  }

  String _cuando(Aviso a) {
    final v = _vistoEn[a.id];
    if (v != null) {
      final min = DateTime.now().difference(v).inMinutes;
      return min < 1 ? 'Ahora' : (min < 60 ? 'Hace $min min' : relativo(DateUtils.dateOnly(v)));
    }
    final d = diasHasta(DateUtils.dateOnly(a.cuando));
    if (d == 0 && (a.cuando.hour != 0 || a.cuando.minute != 0)) return hhmm(a.cuando.hour * 60 + a.cuando.minute);
    return d == 0 ? 'Hoy' : (d == -1 ? 'Ayer' : fecha(a.cuando));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, store.ultimaAccion, historial]),
    builder: (context, _) {
      final avisos = _ordenados();
      final sinLeer = avisos.where((a) => !leidos.contains(a.id)).toList();
      final urgentes = sinLeer.any((a) => a.urgente);
      final alto = MediaQuery.sizeOf(context).height;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Panel de avisos: sube y aparece sobre la campana.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: abierto
                ? Padding(
                    key: const ValueKey('panel'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _panel(avisos, sinLeer.length, (alto - 140).clamp(200.0, 560.0)),
                  )
                : nuevo != null
                ? Padding(
                    key: ValueKey(nuevo!.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(width: 340, child: _tarjeta(nuevo!, sombra: true)),
                  )
                : const SizedBox.shrink(key: ValueKey('nada')),
          ),
          _campana(sinLeer.length, urgentes),
        ],
      );
    },
  );

  /// La campana; da un latido (con un aro verde) cada vez que entra en ella algo recién creado.
  Widget _campana(int n, bool urgentes) => ValueListenableBuilder<int>(
    valueListenable: _llegadas,
    builder: (_, llegadas, child) => TweenAnimationBuilder<double>(
      key: ValueKey(llegadas),
      tween: Tween(begin: llegadas == 0 ? 1.0 : 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      builder: (_, t, child) {
        final latido = math.sin(math.pi * t);
        return Transform.scale(
          scale: 1 + .18 * latido,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (latido > 0) BoxShadow(color: P.verde.withValues(alpha: .35 * latido), spreadRadius: 6 * latido),
              ],
            ),
            child: child,
          ),
        );
      },
      child: child,
    ),
    child: _campanaSola(n, urgentes),
  );

  Widget _campanaSola(int n, bool urgentes) => Tooltip(
    message: n == 0 ? 'Notificaciones' : '$n sin leer',
    child: Semantics(
      button: true,
      label: 'Notificaciones, $n sin leer',
      child: Material(
        color: P.superficie,
        shape: CircleBorder(side: BorderSide(color: abierto ? P.morado : P.borde)),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => setState(() {
            abierto = !abierto;
            nuevo = null;
          }),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: P.sombra),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  n == 0 ? Icons.notifications_none_rounded : Icons.notifications_rounded,
                  size: 23,
                  color: abierto || n > 0 ? P.morado : P.textoSuave,
                ),
                if (n > 0)
                  Positioned(
                    top: 6,
                    right: 5,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: urgentes ? P.rojo : P.morado,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: P.superficie, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        n > 99 ? '99+' : '$n',
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _panel(List<Aviso> avisos, int sinLeer, double alto) => Container(
    width: 380,
    constraints: BoxConstraints(maxHeight: alto),
    decoration: BoxDecoration(
      color: P.superficie,
      borderRadius: BorderRadius.circular(P.radio),
      boxShadow: const [BoxShadow(color: Color(0x2414121F), blurRadius: 30, offset: Offset(0, 10))],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(P.radio),
      border: Border.all(color: P.borde),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Pestanas(
                opciones: const ['Notificaciones', 'Historial'],
                seleccion: pestana,
                compactas: true,
                onChanged: (i) => setState(() => pestana = i),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => setState(() => abierto = false),
                icon: Icon(CupertinoIcons.xmark, size: 17, color: P.textoSuave),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: P.borde),
        // Las dos pestañas, una encima de otra: el panel mide lo que la más alta y no cambia de tamaño al pasar.
        Flexible(
          child: IndexedStack(
            index: pestana,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sinLeer > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 6, 0),
                      child: Row(
                        children: [
                          Text('$sinLeer sin leer', style: TextStyle(fontSize: 13, color: P.textoSuave)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() => leidos.addAll(avisos.map((a) => a.id)));
                              _guardar();
                            },
                            child: const Text('Marcar todo leído'),
                          ),
                        ],
                      ),
                    ),
                  if (avisos.isEmpty)
                    _vacio('Todo al día. Aquí verás lo que hagan los técnicos y lo urgente.')
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: avisos.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => _tarjeta(avisos[i]),
                      ),
                    ),
                ],
              ),
              _historial(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _vacio(String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: TextStyle(color: P.textoSuave, fontSize: 14),
    ),
  );

  static IconData _iconoDe(String que) => switch (que) {
    'activo' || 'componente' => Marca.iconoCliente,
    'mantenimiento' => Icons.content_paste_rounded,
    'tecnico' => Icons.engineering_outlined,
    'orden' => Icons.assignment_outlined,
    'incidencia' => Icons.report_outlined,
    'grupo' => Icons.groups_outlined,
    _ => Icons.history_rounded,
  };

  static (Color, IconData) _marcaDe(Hecho h) => switch (h) {
    Hecho.creado => (P.verde, Icons.add_rounded),
    Hecho.cambiado => (P.morado, Icons.edit_rounded),
    Hecho.borrado => (P.rojo, Icons.delete_rounded),
    Hecho.completado => (P.verde, Icons.check_rounded),
  };

  /// Círculo con [centro] y, abajo a la derecha, un sello de color con lo que ha pasado.
  Widget _sellado(Widget centro, Color color, IconData sello) => SizedBox(
    width: 40,
    height: 38,
    child: Stack(
      children: [
        centro,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: P.superficie, width: 1.5),
            ),
            child: Icon(sello, size: 10.5, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  Widget _circulo(IconData icono, Color color) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
    child: Icon(icono, size: 18, color: color),
  );

  /// La foto (o las iniciales) de quien protagoniza el aviso; sin nadie, un círculo con lo que falta.
  Widget _retrato(Aviso a) {
    final w = a.trabajadorId == null ? null : store.trabajador(a.trabajadorId!);
    final sello = a.color == P.verde
        ? Icons.check_rounded
        : (a.incidencia != null ? Icons.priority_high_rounded : Icons.schedule_rounded);
    return _sellado(
      w == null ? _circulo(Icons.person_off_outlined, a.color) : FotoTecnico(w, size: 34),
      a.color,
      sello,
    );
  }

  /// Adónde lleva una línea del historial (null = a ningún sitio: ya no existe o no tiene ficha).
  VoidCallback? _irA(Registro r) {
    final id = r.id;
    if (id == null || r.hecho == Hecho.borrado) return null;
    final activo = switch (r.que) {
      'activo' || 'componente' => store.activo(id)?.id,
      'mantenimiento' => store.planes.where((p) => p.id == id).firstOrNull?.activoId,
      _ => null,
    };
    final tarea = r.que == 'orden' ? store.tarea(id)?.id : null;
    if (activo == null && tarea == null) return null;
    return () {
      setState(() => abierto = false);
      activo != null ? widget.onActivo(activo) : widget.onTarea(tarea!);
    };
  }

  String _hace(DateTime d) {
    final min = DateTime.now().difference(d).inMinutes;
    if (min < 1) return 'Ahora';
    if (min < 60) return 'Hace $min min';
    return hhmm(d.hour * 60 + d.minute);
  }

  String _dia(DateTime d) {
    final n = diasHasta(DateUtils.dateOnly(d));
    return n == 0 ? 'Hoy' : (n == -1 ? 'Ayer' : fecha(d));
  }

  /// Lo que se ha creado, cambiado, borrado y completado, por días y lo último primero. Lo borrado en esta sesión se
  /// puede deshacer.
  Widget _historial() {
    historial.usar(store.nube?.empresaId ?? 'local');
    final registros = historial.registros;
    if (registros.isEmpty) {
      return _vacio('Aquí verás lo que crees, cambies, borres o completes en la app durante el último mes.');
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      itemCount: registros.length,
      itemBuilder: (_, i) {
        final r = registros[i];
        final dia = _dia(r.cuando);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (i == 0 || _dia(registros[i - 1].cuando) != dia)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                child: Text(
                  dia,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: P.textoSuave),
                ),
              ),
            _linea(r),
          ],
        );
      },
    );
  }

  Widget _linea(Registro r) {
    final (color, sello) = _marcaDe(r.hecho);
    final accion = r.accion;
    final deshecho = r.deshecho || (accion is Accion && accion.deshecha);
    final w = r.que == 'tecnico' && r.id != null ? store.trabajador(r.id!) : null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(P.radioControl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        hoverColor: P.hoverFila,
        onTap: _irA(r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
          child: Row(
            children: [
              Opacity(
                opacity: deshecho ? .4 : 1,
                child: _sellado(w == null ? _circulo(_iconoDe(r.que), color) : FotoTecnico(w, size: 34), color, sello),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: deshecho ? P.textoSuave : P.texto,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deshecho ? 'Deshecho' : _hace(r.cuando),
                      style: TextStyle(fontSize: 12, color: P.textoSuave),
                    ),
                  ],
                ),
              ),
              // Al final de cada línea, la flecha para deshacer justo eso (si se puede).
              if (!deshecho && store.puedeDeshacer(r))
                IconButton(
                  tooltip: 'Deshacer',
                  onPressed: () => store.deshacerRegistro(r),
                  icon: Icon(Icons.undo_rounded, size: 19, color: P.morado),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bloque de un aviso: barrita de su color a la izquierda, qué pasó, dónde y cuándo. Sin leer, con fondo suave.
  Widget _tarjeta(Aviso a, {bool sombra = false}) {
    final leido = leidos.contains(a.id);
    return Material(
      color: leido ? P.superficie : Color.alphaBlend(a.color.withValues(alpha: .06), P.superficie),
      borderRadius: BorderRadius.circular(P.radioControl),
      clipBehavior: Clip.antiAlias,
      elevation: sombra ? 6 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: () => _abrir(a),
        hoverColor: P.hoverFila,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: a.color, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _retrato(a),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: leido ? FontWeight.w500 : FontWeight.w700,
                        color: P.texto,
                        height: 1.3,
                      ),
                    ),
                    if (a.detalle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        a.detalle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: P.textoSuave, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(_cuando(a), style: TextStyle(fontSize: 12, color: P.textoSuave)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso de abajo en el centro al borrar algo: qué se ha borrado y «Deshacer», durante 8 segundos.
/// Si se borra otra cosa, el aviso nuevo sustituye al anterior.
class AvisoDeshacer extends StatefulWidget {
  const AvisoDeshacer({super.key});

  @override
  State<AvisoDeshacer> createState() => _AvisoDeshacerState();
}

class _AvisoDeshacerState extends State<AvisoDeshacer> {
  Timer? _ocultar;

  @override
  void initState() {
    super.initState();
    store.ultimaAccion.addListener(_alCambiar);
  }

  @override
  void dispose() {
    store.ultimaAccion.removeListener(_alCambiar);
    _ocultar?.cancel();
    super.dispose();
  }

  void _alCambiar() {
    _ocultar?.cancel();
    if (store.ultimaAccion.value != null) {
      _ocultar = Timer(const Duration(seconds: 8), () => store.ultimaAccion.value = null);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Accion?>(
    valueListenable: store.ultimaAccion,
    builder: (context, a, _) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, an) => FadeTransition(
        opacity: an,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(an),
          child: child,
        ),
      ),
      child: a == null
          ? const SizedBox.shrink(key: ValueKey('nada'))
          : Semantics(
              key: ValueKey(a),
              liveRegion: true,
              child: Material(
                color: P.texto,
                borderRadius: BorderRadius.circular(P.radioControl),
                elevation: 6,
                shadowColor: Colors.black26,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520, minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            a.texto,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: P.superficie, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: P.moradoSuave),
                          onPressed: () => store.deshacer(a),
                          child: const Text('Deshacer', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}

/// Cuántas cosas recién creadas han entrado ya en la campana (cada una la hace latir).
final _llegadas = ValueNotifier<int>(0);

/// Al crear algo: sale en grande abajo en el centro unos instantes y después encoge y vuela hasta la campana de
/// abajo a la derecha, donde queda en el historial. Si se ha creado desde un formulario, espera a que se cierre
/// (así lleva ya el nombre definitivo y no tapa el «Guardar»). [derecha] y [abajo] dicen dónde está la campana.
class VueloCreado extends StatefulWidget {
  final double derecha, abajo;
  const VueloCreado({super.key, required this.derecha, required this.abajo});

  @override
  State<VueloCreado> createState() => _VueloCreadoState();
}

class _VueloCreadoState extends State<VueloCreado> with SingleTickerProviderStateMixin {
  late final _an = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  Registro? _pendiente, _volando;
  Timer? _espera;

  static const _ancho = 380.0;
  static const _campana = 48.0;
  static const _alto = 100.0;

  static const _nombres = {
    'activo': 'Activo',
    'componente': 'Componente',
    'mantenimiento': 'Mantenimiento',
    'tecnico': 'Técnico',
    'orden': 'Orden de trabajo',
    'incidencia': 'Incidencia',
    'grupo': 'Grupo',
  };

  @override
  void initState() {
    super.initState();
    historial.creado.addListener(_alCrear);
    formulariosAbiertos.addListener(_probar);
    _an.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      _llegadas.value++;
      if (mounted) setState(() => _volando = null);
      _probar();
    });
  }

  @override
  void dispose() {
    historial.creado.removeListener(_alCrear);
    formulariosAbiertos.removeListener(_probar);
    _espera?.cancel();
    _an.dispose();
    super.dispose();
  }

  void _alCrear() {
    final r = historial.creado.value;
    if (r == null) return;
    _pendiente = r;
    // Puede llegar en mitad de una construcción: se mira en el siguiente fotograma.
    WidgetsBinding.instance.addPostFrameCallback((_) => _probar());
  }

  /// Sale lo pendiente si no hay formularios abiertos ni otro vuelo (un poco después, para que el formulario
  /// termine de cerrarse).
  void _probar() {
    _espera?.cancel();
    if (_pendiente == null || _volando != null || formulariosAbiertos.value > 0) return;
    _espera = Timer(const Duration(milliseconds: 260), () {
      final r = _pendiente;
      if (!mounted || r == null || _volando != null || formulariosAbiertos.value > 0) return;
      _pendiente = null;
      // Sin animaciones (accesibilidad): solo el latido de la campana.
      if (MediaQuery.of(context).disableAnimations) {
        _llegadas.value++;
        return;
      }
      setState(() => _volando = r);
      _an.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _volando;
    if (r == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, caja) {
          final ancho = math.min(_ancho, caja.maxWidth - 32);
          // De abajo del todo en el centro (a la altura de «Cambios guardados») al centro de la campana.
          final desde = Offset(caja.maxWidth / 2, caja.maxHeight - (widget.abajo - 8) - _alto / 2);
          final hasta = Offset(
            caja.maxWidth - widget.derecha - _campana / 2,
            caja.maxHeight - widget.abajo - _campana / 2,
          );
          return AnimatedBuilder(
            animation: _an,
            builder: (context, child) {
              final t = _an.value;
              // 0–.16 entra; .16–.58 se queda a la vista; .58–1 vuela a la campana.
              final entrada = Curves.easeOutBack.transform((t / .16).clamp(0.0, 1.0));
              final vuelo = Curves.easeInCubic.transform(((t - .58) / .42).clamp(0.0, 1.0));
              // Un poco de arco: sube algo antes de bajar hacia la esquina.
              final p = Offset.lerp(desde, hasta, vuelo)! + Offset(0, -60 * math.sin(math.pi * vuelo));
              final escala = (.86 + .14 * entrada) * (1 - vuelo * (1 - _campana / ancho));
              final opacidad = (t / .1).clamp(0.0, 1.0) * (1 - ((vuelo - .75) / .25).clamp(0.0, 1.0));
              return Stack(
                children: [
                  Positioned(
                    left: p.dx - ancho / 2,
                    top: p.dy - _alto / 2,
                    width: ancho,
                    child: Opacity(
                      opacity: opacidad,
                      child: Transform.scale(scale: escala, child: child),
                    ),
                  ),
                ],
              );
            },
            child: _tarjeta(r),
          );
        },
      ),
    );
  }

  Widget _tarjeta(Registro r) {
    final tipo = _nombres[r.que] ?? 'Elemento';
    return Semantics(
      liveRegion: true,
      label: '$tipo creado: ${r.nombre}. Guardado en el historial',
      child: Container(
        height: _alto,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: P.superficie,
          borderRadius: BorderRadius.circular(P.radio),
          border: Border.all(color: P.borde),
          boxShadow: const [BoxShadow(color: Color(0x2414121F), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: P.verde.withValues(alpha: .12), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: P.verde, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$tipo creado'.toUpperCase(),
                    style: const TextStyle(fontSize: 11.5, letterSpacing: .6, fontWeight: FontWeight.w700, color: P.verde),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.nombre.isEmpty ? tipo : r.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: P.texto),
                  ),
                  const SizedBox(height: 2),
                  Text('Guardado en el historial', style: TextStyle(fontSize: 13, color: P.textoSuave)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso efímero abajo del todo en el centro al guardar un cambio: «Cambios guardados». En las fichas que se
/// guardan solas al escribir sale cuando se deja de teclear, no a cada letra. Si está el de «Deshacer», cede.
class AvisoGuardado extends StatefulWidget {
  const AvisoGuardado({super.key});

  @override
  State<AvisoGuardado> createState() => _AvisoGuardadoState();
}

class _AvisoGuardadoState extends State<AvisoGuardado> {
  Timer? _calma, _ocultar;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    historial.guardados.addListener(_alGuardar);
  }

  @override
  void dispose() {
    historial.guardados.removeListener(_alGuardar);
    _calma?.cancel();
    _ocultar?.cancel();
    super.dispose();
  }

  void _alGuardar() {
    _calma?.cancel();
    _calma = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _visible = true);
      _ocultar?.cancel();
      _ocultar = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Accion?>(
    valueListenable: store.ultimaAccion,
    builder: (context, deshacer, _) {
      final ver = _visible && deshacer == null;
      return IgnorePointer(
        child: AnimatedSlide(
          offset: ver ? Offset.zero : const Offset(0, .6),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: ver ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: Semantics(
              liveRegion: true,
              label: ver ? 'Cambios guardados' : null,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
                decoration: BoxDecoration(
                  color: P.texto,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(color: P.verde, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Cambios guardados',
                      style: TextStyle(color: P.superficie, fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
