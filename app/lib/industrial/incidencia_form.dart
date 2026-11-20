import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../forms.dart';
import '../informes.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../models.dart';
import 'incidencia.dart';
import 'mantenimientos.dart' show raizDe;

/// Crear una incidencia (técnico) o, con [original] aún abierta, corregirla entera.
class AvisoIncidenciaForm extends StatefulWidget {
  final String? tecnicoId, origenTrabajoId;
  final Incidencia? original;
  const AvisoIncidenciaForm({super.key, this.tecnicoId, this.origenTrabajoId, this.original});
  @override
  State<AvisoIncidenciaForm> createState() => _AvisoIncidenciaFormState();
}

class _AvisoIncidenciaFormState extends State<AvisoIncidenciaForm> {
  late final descripcion = TextEditingController()..addListener(() => setState(() {}));
  final claveActivo = GlobalKey(), claveDescripcion = GlobalKey();
  final fotos = <Uint8List>[];

  /// Editando: las fotos ya guardadas que se conservan.
  late final guardadas = [...?widget.original?.fotos];
  String? activoId, origenTrabajoId;
  String? get tecnicoId => widget.tecnicoId ?? store.nube?.trabajadorId;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    if (o != null) {
      descripcion.text = o.descripcion;
      activoId = o.activoId;
      origenTrabajoId = o.origenTrabajoId;
      gravedad = o.gravedad;
      return;
    }
    origenTrabajoId = widget.origenTrabajoId;
    activoId = store.tarea(origenTrabajoId ?? '')?.activoId;
  }

  int get _totalFotos => guardadas.length + fotos.length;

  String categoria = '';
  Gravedad gravedad = Gravedad.media;
  bool intentado = false, ocupada = false, leyendo = false;

  @override
  void dispose() {
    descripcion.dispose();
    super.dispose();
  }

  void _ir(GlobalKey key) {
    final c = key.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300));
  }

  Future<void> _fotos() async {
    final seleccion = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (seleccion == null || !mounted) return;
    setState(() => leyendo = true);
    try {
      for (final f in seleccion.files.take(maxFotosInforme - _totalFotos)) {
        if (f.bytes == null) continue;
        final foto = await comprimirFoto(f.bytes!);
        if (mounted) setState(() => fotos.add(foto));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer la foto.')));
      }
    } finally {
      if (mounted) setState(() => leyendo = false);
    }
  }

  Future<void> _guardar() async {
    if (ocupada || leyendo) return;
    setState(() => intentado = true);
    if (activoId == null || descripcion.text.trim().isEmpty) {
      _ir(activoId == null ? claveActivo : claveDescripcion);
      return;
    }
    setState(() => ocupada = true);
    final o = widget.original;
    if (o != null) return _guardarCambios(o);
    try {
      final i = Incidencia(
        id: store.nuevoId(),
        activoId: activoId!,
        tecnicoId: tecnicoId,
        origenTrabajoId: origenTrabajoId,
        // Sale de la orden de un mantenimiento: se vincula a él (al resolverla, ese mantenimiento vuelve a contar
        // desde cero). El administrador puede cambiarlo o quitarlo en la incidencia.
        planId: store.tarea(origenTrabajoId ?? '')?.planId,
        descripcion: descripcion.text.trim(),
        gravedad: gravedad,
        estado: EstadoIncidencia.abierta,
      );
      final nube = store.nube;
      if (nube != null) {
        await nube.crearIncidencia(i, categoria, fotos);
      } else {
        i.fotos = fotos.map(base64Encode).toList();
        store.guardarIncidencia(i);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incidencia enviada. Si se te ha olvidado algo, puedes editarla mientras siga abierta.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => ocupada = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la incidencia. Comprueba la conexión e inténtalo de nuevo.'),
          ),
        );
      }
    }
  }

  Future<void> _guardarCambios(Incidencia o) async {
    final i = o.copia()
      ..activoId = activoId!
      ..origenTrabajoId = origenTrabajoId
      ..descripcion = descripcion.text.trim()
      ..gravedad = gravedad;
    try {
      final nube = store.nube;
      if (nube != null) {
        await nube.editarIncidencia(o, guardadas, fotos);
      } else {
        store.guardarIncidencia(i..fotos = [...guardadas, ...fotos.map(base64Encode)]);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incidencia actualizada')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => ocupada = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar. Si ya la están revisando, ya no se puede cambiar.')),
        );
      }
    }
  }

  Widget _campoMenu(String etiqueta, Widget child, {double ancho = 280}) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: ancho),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 13, color: P.textoSuave)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    ),
  );

  Widget _cajaMenu(Widget child) => Container(
    constraints: const BoxConstraints(minHeight: 46),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: P.borde),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(child: child),
        const SizedBox(width: 6),
        Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave),
      ],
    ),
  );

  Widget _gravedad(Gravedad g) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 8, color: g.color),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          g.etiqueta,
          style: TextStyle(color: g.color),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  /// La OT es de la máquina del activo elegido (sin activo, todas valen).
  bool _deLaMaquina(Tarea t) {
    final r = raizDe(activoId);
    return r == null || store.ramaDe(r.id).contains(t.activoId);
  }

  Widget _categoria(String c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        switch (c) {
          'Mecánica' => Icons.settings_outlined,
          'Hidráulica' => Icons.water_drop_outlined,
          'Neumática' => Icons.air_rounded,
          'Automatización' => Icons.precision_manufacturing_outlined,
          'Soldadura' => Icons.local_fire_department_outlined,
          'Eléctrica' => Icons.bolt_outlined,
          'Bombas y bombeo' => Icons.water_outlined,
          'Calderas y quemadores' => Icons.whatshot_outlined,
          'Vehículos pesados' => Icons.local_shipping_outlined,
          'Instrumentación' => Icons.speed_outlined,
          'Lubricación' => Icons.oil_barrel_outlined,
          'Calderería' => Icons.construction_outlined,
          _ => Icons.category_outlined,
        },
        size: 20,
        color: P.textoSuave,
      ),
      const SizedBox(width: 8),
      Flexible(child: Text(c.isEmpty ? 'Cualquier categoría' : c, overflow: TextOverflow.ellipsis)),
    ],
  );

  /// Foto con una X arriba a la derecha para quitarla.
  Widget _conQuitar(Widget foto, String ayuda, VoidCallback quitar) => SizedBox(
    width: 84,
    height: 84,
    child: Stack(
      children: [
        foto,
        Positioned(
          top: 4,
          right: 4,
          child: Tooltip(
            message: ayuda,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: quitar,
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close_rounded, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    // Sin «INCIDENCIAS» encima: el título con el icono de incidencia en rojo y el botón «Crear incidencia», rojo.
    lider: Icon(Icons.report_outlined, size: 26, color: P.rojo),
    titulo: widget.original == null ? 'Crear incidencia' : 'Editar incidencia',
    // Se envía a la oficina: «Enviar» (o «Enviar cambios» al editarla).
    textoGuardar: widget.original == null ? 'Enviar' : 'Enviar cambios',
    iconoGuardar: Icons.send_rounded,
    colorGuardar: P.rojo,
    puedeGuardar: activoId != null && descripcion.text.trim().isNotEmpty,
    onGuardar: _guardar,
    avisos: [
      if (activoId == null) ('Te falta el activo o componente', () => _ir(claveActivo)),
      if (descripcion.text.trim().isEmpty) ('Te falta la descripción', () => _ir(claveDescripcion)),
    ],
    campos: [
      Bloque('Dónde', primero: true, [
        KeyedSubtree(
          key: claveActivo,
          child: _campoMenu(
            'Activo o componente',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectorActivo(activoId, (id) => setState(() {
                  activoId = id;
                  // La orden relacionada tiene que ser de esa máquina.
                  final origen = store.tarea(origenTrabajoId);
                  if (origen != null && !_deLaMaquina(origen)) origenTrabajoId = null;
                })),
                if (intentado && activoId == null)
                  Text('Te falta el activo o componente', style: TextStyle(color: P.rojo, fontSize: 12)),
              ],
            ),
            ancho: 360,
          ),
        ),
        const SizedBox(height: 10),
        _campoMenu(
          'Orden relacionada (opcional)',
          BotonMenu<String>(
            tooltip: '¿Durante qué orden has detectado la incidencia?',
            resaltarHover: false,
            relleno: EdgeInsets.zero,
            seleccionado: origenTrabajoId ?? '',
            opciones: [
              ('', const Text('Sin orden asociada')),
              // Solo las de la máquina elegida (y sus componentes).
              for (final t in store.tareas.where((t) => !t.esPlantilla && t.trabajadorIds.contains(tecnicoId) && _deLaMaquina(t)))
                (t.id, Text(t.nombre, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
            onSelected: (id) => setState(() {
              origenTrabajoId = id.isEmpty ? null : id;
              if (id.isNotEmpty) activoId = store.tarea(id)?.activoId;
            }),
            child: _cajaMenu(
              Text(
                store.tarea(origenTrabajoId ?? '')?.nombre ?? 'Sin orden asociada',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ancho: 360,
        ),
      ]),
      Bloque('Qué ocurre', [
        KeyedSubtree(
          key: claveDescripcion,
          child: campo(
            'Descripción',
            descripcion,
            lineas: 4,
            error: intentado && descripcion.text.trim().isEmpty ? 'Te falta la descripción' : null,
          ),
        ),
        _campoMenu(
          'Gravedad',
          BotonMenu<Gravedad>(
            tooltip: '¿Cómo de grave es la avería?',
            resaltarHover: false,
            relleno: EdgeInsets.zero,
            seleccionado: gravedad,
            opciones: [
              for (final g in const [Gravedad.media, Gravedad.grave]) (g, _gravedad(g)),
            ],
            onSelected: (g) => setState(() => gravedad = g),
            child: _cajaMenu(_gravedad(gravedad)),
          ),
        ),
        if (widget.original == null) const SizedBox(height: 10),
        if (widget.original == null) _campoMenu(
          'Categoría',
          BotonMenu<String>(
            tooltip: '¿Qué categoría debe tener el técnico?',
            resaltarHover: false,
            relleno: EdgeInsets.zero,
            seleccionado: categoria,
            opciones: [('', _categoria('')), for (final c in competencias) (c, _categoria(c))],
            onSelected: (c) => setState(() => categoria = c),
            child: _cajaMenu(_categoria(categoria)),
          ),
        ),
      ]),
      Bloque('Fotos', descripcion: 'Hasta $maxFotosInforme fotos de la avería.', [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in guardadas)
              _conQuitar(
                ClipRRect(borderRadius: BorderRadius.circular(P.radio), child: FotoGuardada(g, width: 84, height: 84)),
                'Quitar esta foto',
                () {
                  if (!ocupada) setState(() => guardadas.remove(g));
                },
              ),
            for (var n = 0; n < fotos.length; n++)
              _conQuitar(
                ClipRRect(
                  borderRadius: BorderRadius.circular(P.radio),
                  child: Image.memory(
                    fotos[n],
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    semanticLabel: 'Foto ${n + 1} de la avería',
                  ),
                ),
                'Quitar foto ${n + 1}',
                () {
                  if (!ocupada) setState(() => fotos.removeAt(n));
                },
              ),
            if (_totalFotos < maxFotosInforme)
              BotonAccion(
                'Añadir fotos',
                icono: Icons.add_a_photo_outlined,
                onPressed: () {
                  if (!ocupada && !leyendo) _fotos();
                },
              ),
          ],
        ),
      ]),
    ],
  );
}
