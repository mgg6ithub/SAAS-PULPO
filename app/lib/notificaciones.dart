import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'industrial/incidencia.dart';
import 'industrial/mantenimientos.dart' show abrirIncidenciaForm;
import 'marca.dart';
import 'models.dart';
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

  /// 0 = Notificaciones, 1 = Historial (lo que se ha borrado en esta sesión, con «Deshacer»).
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
    listenable: Listenable.merge([store, store.ultimaAccion]),
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

  Widget _campana(int n, bool urgentes) => Tooltip(
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

  /// Lo borrado en esta sesión, lo último primero; cada uno con «Deshacer» mientras no se haya deshecho.
  Widget _historial() {
    final acciones = store.acciones;
    if (acciones.isEmpty) return _vacio('Aquí verás lo que borres mientras uses la app, para poder deshacerlo.');
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8),
      itemCount: acciones.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final a = acciones[i];
        final min = DateTime.now().difference(a.cuando).inMinutes;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(P.radioControl),
            border: Border(left: BorderSide(color: a.deshecha ? P.borde : P.rojo, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.texto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: a.deshecha ? P.textoSuave : P.texto,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      min < 1 ? 'Ahora' : (min < 60 ? 'Hace $min min' : hhmm(a.cuando.hour * 60 + a.cuando.minute)),
                      style: TextStyle(fontSize: 12, color: P.textoSuave),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              a.deshecha
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Deshecho', style: TextStyle(fontSize: 13, color: P.textoSuave)),
                    )
                  : TextButton(onPressed: () => store.deshacer(a), child: const Text('Deshacer')),
            ],
          ),
        );
      },
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
