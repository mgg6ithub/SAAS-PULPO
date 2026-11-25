import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Pultec: grupos de técnicos. Un grupo es solo un nombre con técnicos dentro (un técnico puede estar en varios).
/// Una orden o un mantenimiento asignado a un grupo se reparte sola al técnico más libre.

/// Icono de grupo: tres personas, una delante y dos detrás.
const iconoGrupo = Icons.groups_rounded;

List<GrupoTecnicos> gruposOrdenados() => [...store.grupos]..sort((a, b) => a.nombre.compareTo(b.nombre));

Future<void> abrirGrupoForm(BuildContext context, [GrupoTecnicos? g]) => abrirPanel(context, GrupoForm(original: g));

/// Crear o editar un grupo: su nombre y qué técnicos están dentro.
class GrupoForm extends StatefulWidget {
  final GrupoTecnicos? original;
  const GrupoForm({super.key, this.original});

  @override
  State<GrupoForm> createState() => _GrupoFormState();
}

class _GrupoFormState extends State<GrupoForm> {
  late final g = widget.original ?? GrupoTecnicos(id: store.nuevoId());
  late final nombre = TextEditingController(text: g.nombre)..addListener(() => setState(() {}));
  late final miembros = {
    for (final w in store.trabajadores)
      if (w.enGrupo(g.id)) w.id,
  };
  bool intentado = false;

  String? get error {
    final n = nombre.text.trim();
    if (n.isEmpty) return intentado ? 'Ponle un nombre' : null;
    return store.nombreGrupoUsado(n, salvo: g.id) ? 'Ya hay un grupo con ese nombre' : null;
  }

  void guardar() {
    setState(() => intentado = true);
    if (nombre.text.trim().isEmpty || error != null) return;
    g.nombre = nombre.text.trim();
    for (final w in store.trabajadores) {
      w.grupoIds.remove(g.id);
      if (miembros.contains(w.id)) w.grupoIds.add(g.id);
    }
    // Una sola vez: guarda el grupo y, con él, los técnicos que han entrado o salido.
    store.guardarGrupo(g);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ws = store.trabajadores.where((w) => w.activo).toList()
      ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
    return VentanaFormulario(
      etiqueta: 'Grupos',
      titulo: widget.original == null ? 'Nuevo grupo' : 'Editar grupo',
      tituloDesplazado: nombre.text,
      puedeGuardar: nombre.text.trim().isNotEmpty && error == null,
      onGuardar: guardar,
      avisos: [if (error != null) (error!, () {})],
      onBorrar: widget.original == null
          ? null
          : () {
              store.deshacible('Has quitado el grupo «${g.nombre}»', () => store.borrarGrupo(g.id));
              Navigator.pop(context);
            },
      campos: [
        Bloque('Grupo', primero: true, [
          campo('Nombre', nombre, hint: 'Hidráulica A', error: error, obligatorio: true),
        ]),
        Bloque(
          'Técnicos',
          descripcion: 'Un técnico puede estar en varios grupos. Lo que se asigna al grupo va al más libre.',
          [
            // Solo los que están; los demás se añaden desde «+ Técnico».
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final w in ws.where((w) => miembros.contains(w.id)))
                    InputChip(
                      avatar: Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 22),
                      label: Text(w.nombreCompleto),
                      onDeleted: () => setState(() => miembros.remove(w.id)),
                      deleteButtonTooltipMessage: 'Sacar del grupo',
                      backgroundColor: P.superficie,
                      side: BorderSide(color: P.borde),
                      shape: const StadiumBorder(),
                    ),
                  if (ws.any((w) => !miembros.contains(w.id)))
                    // Ventana en el centro con los demás en cuadrícula (tres columnas), no un desplegable largo.
                    InkWell(
                      borderRadius: BorderRadius.circular(P.radioControl),
                      onTap: () async {
                        final nuevos = await elegirTecnicos(context, ws.where((w) => !miembros.contains(w.id)).toList());
                        if (nuevos.isNotEmpty) setState(() => miembros.addAll(nuevos));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: P.morado),
                            const SizedBox(width: 4),
                            Text('Técnico', style: TextStyle(color: P.morado, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  else if (ws.isEmpty)
                    Text('Aún no hay técnicos.', style: TextStyle(color: P.textoSuave)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Grupos de un técnico (en su ficha): se marcan o desmarcan varios; al final, crear uno nuevo.
class SelectorGrupos extends StatelessWidget {
  final List<String> ids;
  final ValueChanged<List<String>> onChanged;
  const SelectorGrupos(this.ids, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final g in gruposOrdenados())
          FilterChip(
            avatar: Icon(iconoGrupo, size: 16, color: ids.contains(g.id) ? P.morado : P.textoSuave),
            label: Text(g.nombre),
            selected: ids.contains(g.id),
            showCheckmark: false,
            selectedColor: P.moradoSuave,
            backgroundColor: P.superficie,
            side: BorderSide(color: ids.contains(g.id) ? P.morado.withValues(alpha: .45) : P.borde),
            shape: const StadiumBorder(),
            onSelected: (si) => onChanged(si ? [...ids, g.id] : [...ids]..remove(g.id)),
          ),
        Enlace('Nuevo grupo', onTap: () async {
          final g = await crearGrupoRapido(context);
          if (g != null) onChanged([...ids, g.id]);
        }),
      ],
    ),
  );
}

/// Filtro por grupo al final del buscador de técnicos: solo el icono de grupo (morado si hay uno elegido); al
/// tocarlo, el menú con los grupos.
class FiltroGrupo extends StatelessWidget {
  final String? valor;
  final ValueChanged<String?> onChanged;
  const FiltroGrupo(this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => BotonMenu<String>(
    tooltip: 'Filtrar por grupo',
    seleccionado: valor ?? '',
    opciones: [
      ('', const Text('Todos los grupos')),
      for (final x in gruposOrdenados())
        (
          x.id,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(iconoGrupo, size: 18, color: P.textoSuave), const SizedBox(width: 8), Text(x.nombre)],
          ),
        ),
    ],
    onSelected: (v) => onChanged(v.isEmpty ? null : v),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Icon(iconoGrupo, size: 20, color: store.grupo(valor) == null ? P.textoSuave : P.morado),
    ),
  );
}

/// Ventana centrada para elegir técnicos: buscador y cuadrícula de tres columnas; se marcan varios y «Añadir».
Future<Set<String>> elegirTecnicos(BuildContext context, List<Trabajador> ws) async =>
    await showDialog<Set<String>>(context: context, builder: (_) => _ElegirTecnicos(ws)) ?? {};

class _ElegirTecnicos extends StatefulWidget {
  final List<Trabajador> ws;
  const _ElegirTecnicos(this.ws);

  @override
  State<_ElegirTecnicos> createState() => _ElegirTecnicosState();
}

class _ElegirTecnicosState extends State<_ElegirTecnicos> {
  final elegidos = <String>{};
  String q = '';

  @override
  Widget build(BuildContext context) {
    final lista = widget.ws.where((w) => w.nombreCompleto.toLowerCase().contains(q.toLowerCase())).toList();
    final ancho = MediaQuery.sizeOf(context).width;
    final cols = ancho < 560 ? 1 : ancho < 760 ? 2 : 3;
    return Dialog(
      backgroundColor: P.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radio)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Añadir técnicos',
                      style: TextStyle(fontFamily: P.titulos, fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 20, color: P.textoSuave),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Buscador(hint: 'Buscar técnico…', width: double.infinity, onChanged: (v) => setState(() => q = v)),
              const SizedBox(height: 14),
              Flexible(
                child: lista.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Nadie con ese nombre.', textAlign: TextAlign.center, style: TextStyle(color: P.textoSuave)),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        itemCount: lista.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisExtent: 48,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (_, i) {
                          final w = lista[i];
                          final si = elegidos.contains(w.id);
                          return Material(
                            color: si ? P.moradoSuave : P.superficie,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(P.radioControl),
                              side: BorderSide(color: si ? P.morado.withValues(alpha: .45) : P.borde),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(P.radioControl),
                              onTap: () => setState(() => si ? elegidos.remove(w.id) : elegidos.add(w.id)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 26),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        w.nombreCompleto,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: si ? FontWeight.w600 : FontWeight.w400),
                                      ),
                                    ),
                                    if (si) Icon(Icons.check_rounded, size: 18, color: P.morado),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: elegidos.isEmpty ? null : () => Navigator.pop(context, elegidos),
                    child: Text(elegidos.isEmpty ? 'Añadir' : 'Añadir ${elegidos.length}'),
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

