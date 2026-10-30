import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../forms.dart';
import '../informes.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'incidencia.dart';
import 'mantenimientos.dart';

class AvisoIncidenciaForm extends StatefulWidget {
  const AvisoIncidenciaForm({super.key});
  @override
  State<AvisoIncidenciaForm> createState() => _AvisoIncidenciaFormState();
}

class _AvisoIncidenciaFormState extends State<AvisoIncidenciaForm> {
  late final descripcion = TextEditingController()..addListener(() => setState(() {}));
  final claveActivo = GlobalKey(), claveDescripcion = GlobalKey();
  final fotos = <Uint8List>[];
  String? activoId;
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
      for (final f in seleccion.files.take(maxFotosInforme - fotos.length)) {
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
    try {
      final i = Incidencia(
        id: store.nuevoId(),
        activoId: activoId!,
        descripcion: descripcion.text.trim(),
        gravedad: gravedad,
        estado: EstadoIncidencia.conOt,
      );
      final nube = store.nube;
      if (nube != null) {
        await nube.crearIncidencia(i, categoria, fotos);
      } else {
        final ot = Tarea(
          id: store.nuevoId(),
          nombre: i.descripcion,
          notas: i.descripcion,
          activoId: activoId,
          tipoMantenimiento: gravedad.tipo,
          plantilla: false,
          periodicidad: Periodicidad.unica,
          proximo: hoy(),
          competencias: categoria.isEmpty ? [] : [categoria],
        );
        i.trabajoId = ot.id;
        i.fotos = fotos.map(base64Encode).toList();
        store.guardarTarea(ot);
        store.guardarIncidencia(i);
      }
      if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'Incidencias',
    titulo: 'Nueva incidencia',
    onGuardar: _guardar,
    avisos: [
      if (activoId == null) ('Te falta el activo o componente', () => _ir(claveActivo)),
      if (descripcion.text.trim().isEmpty) ('Te falta la descripción', () => _ir(claveDescripcion)),
    ],
    campos: [
      Bloque('Dónde', primero: true, [
        KeyedSubtree(
          key: claveActivo,
          child: BotonMenu<String>(
            tooltip: 'Elige el activo o componente de la avería',
            seleccionado: activoId,
            opciones: [for (final a in store.activos.where((a) => a.activo)) (a.id, Text(dondeEs(a.id)))],
            onSelected: (id) => setState(() => activoId = id),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Activo o componente',
                errorText: intentado && activoId == null ? 'Te falta el activo o componente' : null,
              ),
              child: Text(activoId == null ? 'Elegir…' : dondeEs(activoId)),
            ),
          ),
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
        BotonMenu<Gravedad>(
          tooltip: '¿Cómo de grave es la avería?',
          seleccionado: gravedad,
          opciones: [for (final g in Gravedad.values) (g, Text(g.etiqueta))],
          onSelected: (g) => setState(() => gravedad = g),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Gravedad'),
            child: Text(gravedad.etiqueta),
          ),
        ),
        const SizedBox(height: 10),
        BotonMenu<String>(
          tooltip: '¿Qué categoría debe tener el técnico?',
          seleccionado: categoria,
          opciones: [('', const Text('Cualquier categoría')), for (final c in competencias) (c, Text(c))],
          onSelected: (c) => setState(() => categoria = c),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Categoría'),
            child: Text(categoria.isEmpty ? 'Cualquier categoría' : categoria),
          ),
        ),
      ]),
      Bloque('Fotos', descripcion: 'Hasta $maxFotosInforme fotos de la avería.', [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 0; n < fotos.length; n++)
              SizedBox(
                width: 90,
                child: Column(
                  children: [
                    Image.memory(
                      fotos[n],
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      semanticLabel: 'Foto ${n + 1} de la avería',
                    ),
                    BotonAccion(
                      'Quitar',
                      tooltip: 'Quitar foto ${n + 1}',
                      onPressed: () {
                        if (!ocupada) setState(() => fotos.removeAt(n));
                      },
                    ),
                  ],
                ),
              ),
            if (fotos.length < maxFotosInforme)
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
