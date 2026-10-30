import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../nube.dart';
import '../plataforma_io.dart' if (dart.library.js_interop) '../plataforma_web.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../marca.dart';

/// Pestaña «Equipos» de la ficha de cliente: sus ascensores, calderas, extintores… con su estado y el
/// vencimiento legal más cercano.
class EquiposCliente extends StatelessWidget {
  final String clienteId;
  final double alto;
  const EquiposCliente(this.clienteId, {super.key, required this.alto});

  @override
  Widget build(BuildContext context) {
    final equipos = store.equiposDe(clienteId)..sort((a, b) => a.nombre.compareTo(b.nombre));
    if (equipos.isEmpty) {
      return Vacio(
        icono: Icons.precision_manufacturing_outlined,
        titulo: 'Sin equipos',
        texto: 'Da de alta sus ascensores, calderas o extintores para llevar\nsu historial, documentos y vencimientos legales.',
        accion: FilledButton(onPressed: () => abrirEquipoForm(context, clienteId), child: const Text('Nuevo equipo')),
      );
    }
    return SeccionTarjeta(
      alto: alto,
      titulo: 'Equipos',
      subtitulo: '${equipos.length} ${equipos.length == 1 ? 'equipo' : 'equipos'}',
      accion: Enlace('Nuevo equipo', onTap: () => abrirEquipoForm(context, clienteId)),
      children: [
        for (final e in equipos)
          FilaLista(
            lider: BarraTipo(e.tipo, alto: 32),
            titulo: e.nombre,
            subtitulo: [
              e.tipo,
              [e.marca, e.modelo].where((x) => x.isNotEmpty).join(' '),
              if (e.numeroSerie.isNotEmpty) 'Nº ${e.numeroSerie}',
              e.ubicacion,
            ].where((x) => x.isNotEmpty).join(' · '),
            derecha: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?_proximoVencimiento(e),
                const SizedBox(width: 8),
                Pill(e.estado.etiqueta, e.estado.color, punto: true),
              ],
            ),
            onTap: () => abrirEquipoForm(context, clienteId, e),
          ),
      ],
    );
  }

  /// El vencimiento por avisar más urgente: rojo si ya ha caducado, ámbar si está dentro del aviso.
  Widget? _proximoVencimiento(Equipo e) {
    final v = store.vencimientosDe(e.id).where((v) => v.avisar).firstOrNull;
    if (v == null) return null;
    return Pill('${v.nombre} ${relativo(v.vence)}', diasHasta(v.vence) < 0 ? P.rojo : P.ambar);
  }
}

Future<void> abrirEquipoForm(BuildContext context, String clienteId, [Equipo? e]) =>
    abrirPanel(context, EquipoForm(clienteId: clienteId, original: e));

const _avisos = [15, 30, 60, 90];

class EquipoForm extends StatefulWidget {
  final String clienteId;
  final Equipo? original;
  const EquipoForm({super.key, required this.clienteId, this.original});

  @override
  State<EquipoForm> createState() => _EquipoFormState();
}

class _EquipoFormState extends State<EquipoForm> {
  late final Equipo e = widget.original?.copia() ?? Equipo(id: store.nuevoId(), clienteId: widget.clienteId);
  late final nombre = TextEditingController(text: e.nombre)..addListener(() => setState(() {}));
  late final marca = TextEditingController(text: e.marca);
  late final modelo = TextEditingController(text: e.modelo);
  late final serie = TextEditingController(text: e.numeroSerie);
  late final ubicacion = TextEditingController(text: e.ubicacion);
  late final notas = TextEditingController(text: e.notas);

  /// Vencimientos en edición, cada uno con el campo de su nombre.
  late final vencimientos = [
    for (final v in store.vencimientosDe(e.id))
      (Vencimiento.fromJson(v.toJson()), TextEditingController(text: v.nombre)),
  ];
  bool intentoGuardar = false, subiendo = false;

  String? get error => intentoGuardar && nombre.text.trim().isEmpty ? 'Ponle un nombre' : null;

  void guardar() {
    setState(() => intentoGuardar = true);
    if (error != null) return;
    e
      ..nombre = nombre.text.trim()
      ..marca = marca.text.trim()
      ..modelo = modelo.text.trim()
      ..numeroSerie = serie.text.trim()
      ..ubicacion = ubicacion.text.trim()
      ..notas = notas.text.trim();
    // Los documentos se guardan al momento: no se pisan con los de cuando se abrió la ventana.
    e.documentos = store.equipo(e.id)?.documentos ?? e.documentos;
    store.guardarEquipo(e);
    final quedan = {for (final (v, _) in vencimientos) v.id};
    for (final v in store.vencimientosDe(e.id).where((v) => !quedan.contains(v.id))) {
      store.borrarVencimiento(v.id);
    }
    for (final (v, c) in vencimientos) {
      v.nombre = c.text.trim().isEmpty ? 'Inspección' : c.text.trim();
      store.guardarVencimiento(v);
    }
    Navigator.pop(context);
  }

  Future<void> anadirDocumento() async {
    final nube = store.nube!;
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: Nube.extensionesDocumento,
      withData: true,
    );
    final f = r?.files.firstOrNull;
    if (f?.bytes == null) return;
    setState(() => subiendo = true);
    try {
      final ruta = await nube.subirDocumentoEquipo(e.id, f!.name, f.bytes!);
      _guardarDocumentos([...e.documentos.where((d) => d != ruta), ruta]);
    } catch (_) {
      if (mounted) avisar('No se pudo subir ${f!.name}');
    } finally {
      if (mounted) setState(() => subiendo = false);
    }
  }

  Future<void> quitarDocumento(String ruta) async {
    try {
      await store.nube!.borrarDocumentoEquipo(ruta);
    } catch (_) {}
    _guardarDocumentos([...e.documentos]..remove(ruta));
  }

  /// Los documentos se guardan al momento en el equipo ya creado, aunque luego se cancele la ventana.
  void _guardarDocumentos(List<String> docs) {
    setState(() => e.documentos = docs);
    final guardado = store.equipo(e.id);
    if (guardado != null) store.guardarEquipo(guardado..documentos = [...docs]);
  }

  void avisar(String texto) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    final existe = widget.original != null;
    final visitas = [
      for (final t in store.trabajosDe(e.id))
        for (final d in {...t.historial, ?t.ultimo}) (d, t),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final conNube = store.nube != null && !store.nube!.esTrabajador;
    return VentanaFormulario(
      etiqueta: store.cliente(widget.clienteId)?.nombre ?? 'Equipos',
      titulo: existe ? 'Editar equipo' : 'Nuevo equipo',
      tituloDesplazado: nombre.text,
      onGuardar: guardar,
      avisos: [if (error != null) ('Te falta el nombre', () {})],
      onBorrar: !existe
          ? null
          : () async {
              final nav = Navigator.of(context);
              if (await confirmar(context, m('¿Eliminar ${e.nombre}? Sus trabajos se quedan, sin equipo.'))) {
                for (final d in e.documentos) {
                  store.nube?.borrarDocumentoEquipo(d).catchError((_) {});
                }
                store.borrarEquipo(e.id);
                nav.pop();
              }
            },
      campos: [
        Bloque('Equipo', primero: true, descripcion: 'Qué es y cómo está ahora.', [
          campo('Nombre', nombre, hint: 'Ascensor 1, caldera del sótano…', error: error, obligatorio: true),
          dos(
            conMargen(
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: tipos.any((x) => x.nombre == e.tipo) ? e.tipo : null,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [for (final x in tipos) DropdownMenuItem(value: x.nombre, child: Text(x.nombre))],
                onChanged: (v) => setState(() => e.tipo = v!),
              ),
            ),
            conMargen(
              DropdownButtonFormField<EstadoMaquina>(
                isExpanded: true,
                initialValue: e.estado,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: [
                  for (final x in EstadoMaquina.values)
                    DropdownMenuItem(
                      value: x,
                      child: Row(children: [_punto(x.color), const SizedBox(width: 8), Text(x.etiqueta)]),
                    ),
                ],
                onChanged: (v) => setState(() => e.estado = v!),
              ),
            ),
          ),
        ]),
        Bloque('Ficha técnica', descripcion: 'Los datos de la placa y dónde está.', [
          dos(campo('Marca', marca), campo('Modelo', modelo)),
          dos(
            campo('Número de serie', serie),
            CampoFecha('Fecha de instalación', e.instalacion, (d) => setState(() => e.instalacion = d)),
          ),
          campo('Ubicación', ubicacion, hint: 'Sala de máquinas, planta 2…'),
        ]),
        Bloque(
          'Vencimientos legales',
          descripcion: m('Inspecciones y revisiones obligatorias. Pulpo avisa en Inicio antes de que caduquen.'),
          [
            for (final (v, c) in vencimientos)
              Row(
                key: ObjectKey(v),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(flex: 3, child: campo('Qué vence', c, hint: 'Inspección OCA')),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: CampoFecha('Vence el', v.vence, (d) => setState(() => v.vence = d))),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: conMargen(
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: v.avisarDias,
                        decoration: const InputDecoration(labelText: 'Avisar'),
                        items: [
                          for (final n in {..._avisos, v.avisarDias}.toList()..sort())
                            DropdownMenuItem(value: n, child: Text('$n días antes')),
                        ],
                        onChanged: (n) => setState(() => v.avisarDias = n!),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: IconButton(
                      tooltip: 'Quitar',
                      onPressed: () => setState(() => vencimientos.removeWhere((x) => x.$1 == v)),
                      icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                    ),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Enlace(
                'Añadir vencimiento',
                onTap: () => setState(
                  () => vencimientos.add((
                    Vencimiento(id: store.nuevoId(), equipoId: e.id, vence: masDias(hoy(), 365)),
                    TextEditingController(),
                  )),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        if (existe)
          Bloque(
            'Documentos',
            descripcion: 'Certificados, libro de mantenimiento y fotos (PDF o imagen). Se guardan al momento.',
            [
              if (!conNube)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Los documentos se guardan en la nube: entra con tu cuenta de administrador.',
                    style: TextStyle(fontSize: 13, color: P.textoSuave),
                  ),
                )
              else ...[
                for (final d in e.documentos)
                  FilaLista(
                    lider: _punto(d.endsWith('.pdf') ? P.rojo : P.azul),
                    titulo: d.split('/').last,
                    derecha: IconButton(
                      tooltip: 'Quitar',
                      onPressed: () => quitarDocumento(d),
                      icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                    ),
                    onTap: () async {
                      try {
                        await descargar(
                          await store.nube!.documentoEquipo(d),
                          d.split('/').last,
                          d.endsWith('.pdf') ? 'application/pdf' : 'image/*',
                        );
                      } catch (_) {
                        if (mounted) avisar('No se pudo abrir el documento');
                      }
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: subiendo
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Enlace('Añadir documento', onTap: anadirDocumento),
                  ),
                ),
              ],
            ],
          ),
        if (existe)
          Bloque('Historial', descripcion: 'Revisiones y averías hechas sobre este equipo.', [
            if (visitas.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  m('Aún no hay trabajos hechos. Enlaza un trabajo a este equipo desde el trabajo.'),
                  style: TextStyle(fontSize: 13, color: P.textoSuave),
                ),
              ),
            for (final (d, t) in visitas)
              FilaLista(
                lider: BarraTipo(t.tipo, alto: 28, color: t.colorBloque),
                titulo: t.nombre,
                subtitulo: [fecha(d), relativo(d)].join(' · '),
              ),
          ]),
        Bloque('Notas', [campo('Notas internas', notas, lineas: 3)]),
      ],
    );
  }
}

Widget _punto(Color c) => Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);
