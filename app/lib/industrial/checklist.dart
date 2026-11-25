import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Checklists de Pultec (DEV-052): el activo y el mantenimiento guardan sus pasos; cada OT se queda con su copia,
/// que el técnico marca en vivo y sale en el parte y en el histórico del activo.

/// La checklist de una OT: la suya si ya se empezó; si no, la de su mantenimiento o, si no tiene, la de su activo.
List<PasoChecklist> checklistDe(Tarea t) {
  if (t.checklist.isNotEmpty) return t.checklist;
  final plan = store.planes.where((p) => p.id == t.planId).firstOrNull;
  final pasos = plan != null && plan.checklist.isNotEmpty ? plan.checklist : store.activo(t.activoId)?.checklist ?? [];
  return [for (final p in pasos) PasoChecklist(p)];
}

/// «7 de 8» pasos hechos; null si la OT no tiene checklist.
String? progresoChecklist(Tarea t) {
  final c = checklistDe(t);
  return c.isEmpty ? null : '${c.where((p) => p.hecho).length} de ${c.length}';
}

String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Quién marcó un paso: el técnico o la oficina.
String quienMarco(String? por) => (por == null ? null : store.trabajador(por))?.nombre ?? 'Oficina';

/// Las checklists ya hechas en otros activos y mantenimientos, para reutilizarlas (sin repetir las iguales).
List<(String, List<String>)> checklistsGuardadas({String? salvo}) {
  final r = <(String, List<String>)>[];
  final vistas = <String>{};
  void poner(String nombre, List<String> pasos) {
    if (pasos.isEmpty || !vistas.add(pasos.join('\n'))) return;
    r.add((nombre, pasos));
  }

  for (final p in store.planes.where((p) => p.id != salvo)) {
    poner([p.nombre, store.activo(p.activoId)?.titulo].nonNulls.join(', '), p.checklist);
  }
  for (final a in store.activos.where((a) => a.id != salvo)) {
    poner(a.titulo, a.checklist);
  }
  return r;
}

/// Editor de los pasos de una checklist (formularios de activo y de mantenimiento): escribir, ordenar arrastrando,
/// quitar y copiar una ya hecha.
class EditorChecklist extends StatefulWidget {
  final List<String> pasos;
  final ValueChanged<List<String>> onChanged;

  /// Id del activo o mantenimiento que se edita, para no ofrecerse a sí mismo al copiar.
  final String? propio;

  /// Se abre editando (por defecto, solo si está vacía).
  final bool? abierta;

  /// «Listo» lo hace quien lo usa (p. ej. la orden vuelve a la lista para marcar); si no, se cierra aquí.
  final VoidCallback? onListo;
  const EditorChecklist(this.pasos, this.onChanged, {super.key, this.propio, this.abierta, this.onListo});

  @override
  State<EditorChecklist> createState() => _EditorChecklistState();
}

class _EditorChecklistState extends State<EditorChecklist> {
  late final _campos = [for (final p in widget.pasos) TextEditingController(text: p)];
  final _focos = <FocusNode>[];

  @override
  void dispose() {
    for (final c in _campos) {
      c.dispose();
    }
    for (final f in _focos) {
      f.dispose();
    }
    super.dispose();
  }

  void _avisar() => widget.onChanged([for (final c in _campos) c.text.trim()]..removeWhere((x) => x.isEmpty));

  void _anadir() {
    setState(() => _campos.add(TextEditingController()));
    final f = FocusNode();
    _focos.add(f);
    WidgetsBinding.instance.addPostFrameCallback((_) => f.requestFocus());
    _nuevo = f;
  }

  FocusNode? _nuevo;

  /// Editando los pasos; con «Listo» se cierra y quedan solo para leer («Editar» lo vuelve a abrir).
  late bool _editando = widget.abierta ?? _campos.isEmpty;

  /// Vista de solo lectura: los pasos numerados y «Editar».
  Widget _cerrada() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, c) in _campos.where((c) => c.text.trim().isNotEmpty).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: P.textoSuave, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(c.text.trim(), style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        Enlace('Editar', onTap: () => setState(() => _editando = true)),
      ],
    ),
  );

  void _usar(List<String> pasos) {
    setState(() {
      for (final c in _campos) {
        c.dispose();
      }
      _campos
        ..clear()
        ..addAll([for (final p in pasos) TextEditingController(text: p)]);
    });
    _avisar();
  }

  @override
  Widget build(BuildContext context) {
    if (!_editando && _campos.any((c) => c.text.trim().isNotEmpty)) return _cerrada();
    final guardadas = checklistsGuardadas(salvo: widget.propio);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_campos.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (de, a) {
                setState(() => _campos.insert(a, _campos.removeAt(de)));
                _avisar();
              },
              children: [
                for (final (i, c) in _campos.indexed)
                  Padding(
                    key: ObjectKey(c),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: SizedBox(
                              width: 26,
                              child: Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: P.textoSuave, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: c,
                            focusNode: identical(c, _campos.last) ? _nuevo : null,
                            decoration: const InputDecoration(hintText: 'Describe el paso', isDense: true),
                            onChanged: (_) => _avisar(),
                            onSubmitted: (_) => _anadir(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar paso',
                          icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                          onPressed: () {
                            setState(() => _campos.removeAt(i).dispose());
                            _avisar();
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Enlace('Añadir paso', onTap: _anadir),
                    if (guardadas.isNotEmpty)
                      BotonMenu<int>(
                        tooltip: 'Copiar los pasos de otra checklist',
                        opciones: [
                          for (final (i, (nombre, pasos)) in guardadas.indexed)
                            (i, Text('$nombre (${pasos.length} ${pasos.length == 1 ? 'paso' : 'pasos'})')),
                        ],
                        onSelected: (i) => _usar(guardadas[i].$2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Usar una ya hecha',
                            style: TextStyle(color: P.morado, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Cierra la edición: los pasos quedan fijos hasta pulsar «Editar».
              if (_campos.any((c) => c.text.trim().isNotEmpty))
                BotonAccion(
                  'Listo',
                  icono: Icons.check_rounded,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      for (final c in _campos.where((c) => c.text.trim().isEmpty).toList()) {
                        _campos.remove(c);
                        c.dispose();
                      }
                      _editando = false;
                    });
                    _avisar();
                    widget.onListo?.call();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// La checklist de una OT con sus pasos: el técnico los marca en el momento (hora y quién) y puede dejar una nota.
/// Sin [puedeMarcar], solo se ve (la oficina, o la OT ya cerrada).
class ChecklistOt extends StatelessWidget {
  final Tarea t;
  final bool puedeMarcar;

  /// Quien marca: el id del técnico (null = la oficina).
  final String? por;

  /// Sin la tarjeta alrededor (dentro de un bloque de formulario).
  final bool sinTarjeta;
  const ChecklistOt(this.t, {super.key, this.puedeMarcar = false, this.por, this.sinTarjeta = false});

  Future<void> _guardar(BuildContext context, List<PasoChecklist> pasos) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.marcarChecklist(t, pasos);
    } catch (e) {
      debugPrint('Pultec: no se pudo guardar la checklist: $e');
      messenger.showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text('No se pudo guardar el paso.')),
      );
    }
  }

  List<PasoChecklist> _copia() => [for (final p in checklistDe(t)) PasoChecklist.fromJson(p.toJson())];

  void _marcar(BuildContext context, int i) {
    final pasos = _copia();
    final p = pasos[i]
      ..hecho = !pasos[i].hecho
      ..por = por;
    p.cuando = p.hecho ? DateTime.now() : null;
    _guardar(context, pasos);
  }

  Future<void> _nota(BuildContext context, int i) async {
    final pasos = _copia();
    final c = TextEditingController(text: pasos[i].nota);
    final r = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pasos[i].paso),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: c,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Nota del paso (opcional)'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    c.dispose();
    if (r == null || !context.mounted) return;
    pasos[i].nota = r;
    _guardar(context, pasos);
  }

  // Se repinta al marcar (aquí o en otro dispositivo, al recargar la orden).
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: store, builder: (context, _) => _lista(context));

  Widget _lista(BuildContext context) {
    final pasos = checklistDe(t);
    final hechos = pasos.where((p) => p.hecho).length;
    final filas = [
      Padding(
        padding: sinTarjeta ? const EdgeInsets.fromLTRB(0, 6, 0, 6) : const EdgeInsets.fromLTRB(18, 12, 18, 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pasos.isEmpty ? 0 : hechos / pasos.length,
            minHeight: 4,
            color: hechos == pasos.length ? P.verde : P.morado,
            backgroundColor: P.borde,
          ),
        ),
      ),
      for (final (i, p) in pasos.indexed)
        // Al pasar por encima, el fondo con las cuatro esquinas redondeadas (y un poco de aire alrededor).
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sinTarjeta ? 0 : 6, vertical: 1),
          child: InkWell(
            borderRadius: BorderRadius.circular(P.radioControl),
            onTap: puedeMarcar ? () => _marcar(context, i) : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      p.hecho ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color: p.hecho ? P.verde : P.textoSuave,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.paso, style: TextStyle(fontSize: 14, color: p.hecho ? P.textoSuave : null)),
                        // La línea de la hora siempre ocupa su sitio: al marcar, la fila no crece.
                        Text(
                          p.hecho && p.cuando != null ? '${_hora(p.cuando!)}, ${quienMarco(p.por)}' : ' ',
                          style: TextStyle(fontSize: 12, color: P.textoSuave),
                        ),
                        if (p.nota.isNotEmpty)
                          Text(
                            p.nota,
                            style: TextStyle(fontSize: 12.5, color: P.texto, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  if (puedeMarcar)
                    IconButton(
                      tooltip: p.nota.isEmpty ? 'Añadir nota' : 'Cambiar la nota',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.edit_note_rounded, size: 20, color: p.nota.isEmpty ? P.textoSuave : P.morado),
                      onPressed: () => _nota(context, i),
                    ),
                ],
              ),
            ),
          ),
        ),
    ];
    if (sinTarjeta) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filas);
    return SeccionTarjeta(titulo: 'Checklist', subtitulo: '$hechos de ${pasos.length}', children: filas);
  }
}

/// Los pasos de [antes] que siguen en [textos] conservan lo hecho (hora, quién, nota); los nuevos, sin hacer.
List<PasoChecklist> pasosConLoHecho(List<PasoChecklist> antes, List<String> textos) {
  final quedan = [...antes];
  return [
    for (final x in textos)
      if (quedan.indexWhere((p) => p.paso == x) case final i when i >= 0) quedan.removeAt(i) else PasoChecklist(x),
  ];
}

/// La checklist dentro de la orden: se marca y, con «Editar pasos», se cambian los pasos de esta orden (o se
/// añade una si no tenía). Se guarda sola al momento y el técnico la ve en vivo. Con [borrador] (orden aún sin
/// crear) solo cambia la orden: se guarda al crearla.
class ChecklistEnOt extends StatefulWidget {
  final Tarea t;
  final bool puedeMarcar, borrador;
  const ChecklistEnOt(this.t, {super.key, this.puedeMarcar = true, this.borrador = false});

  @override
  State<ChecklistEnOt> createState() => _ChecklistEnOtState();
}

class _ChecklistEnOtState extends State<ChecklistEnOt> {
  bool _editando = false;
  Timer? _espera;
  List<PasoChecklist>? _pendiente;

  @override
  void dispose() {
    if (_espera?.isActive ?? false) _guardar();
    super.dispose();
  }

  void _cambiar(List<String> textos) {
    final pasos = pasosConLoHecho(checklistDe(widget.t), textos);
    if (widget.borrador) {
      widget.t.checklist = pasos;
      return;
    }
    // Un momento después de dejar de escribir, no a cada letra.
    _pendiente = pasos;
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 600), _guardar);
  }

  Future<void> _guardar() async {
    _espera?.cancel();
    final pasos = _pendiente;
    _pendiente = null;
    if (pasos == null) return;
    try {
      await store.marcarChecklist(widget.t, pasos);
    } catch (e) {
      debugPrint('Pultec: no se pudo guardar la checklist: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editando) {
      return EditorChecklist(
        [for (final p in checklistDe(widget.t)) p.paso],
        _cambiar,
        propio: widget.t.planId,
        abierta: true,
        onListo: () {
          _guardar();
          setState(() => _editando = false);
        },
      );
    }
    final vacia = checklistDe(widget.t).isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!vacia) ChecklistOt(widget.t, puedeMarcar: widget.puedeMarcar && !widget.borrador, sinTarjeta: true),
          Enlace(vacia ? 'Añadir checklist' : 'Editar pasos', onTap: () => setState(() => _editando = true)),
        ],
      ),
    );
  }
}
