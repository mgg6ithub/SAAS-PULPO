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
            if (ws.isEmpty)
              Text('Aún no hay técnicos.', style: TextStyle(color: P.textoSuave))
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in ws)
                      _PildoraTecnico(
                        w,
                        dentro: miembros.contains(w.id),
                        onTap: () => setState(() => miembros.contains(w.id) ? miembros.remove(w.id) : miembros.add(w.id)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Técnico que se mete o se saca del grupo con un toque: dentro, en morado con su check.
class _PildoraTecnico extends StatelessWidget {
  final Trabajador w;
  final bool dentro;
  final VoidCallback onTap;
  const _PildoraTecnico(this.w, {required this.dentro, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: dentro ? P.moradoSuave : P.superficie,
    shape: StadiumBorder(side: BorderSide(color: dentro ? P.morado.withValues(alpha: .45) : P.borde)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 24),
            const SizedBox(width: 8),
            Text(w.nombreCompleto, style: TextStyle(fontWeight: dentro ? FontWeight.w600 : FontWeight.w400)),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              child: dentro
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_rounded, size: 16, color: P.morado),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );
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

/// Filtro por grupo junto al buscador de técnicos: sin elegir, el icono de grupo; elegido, su nombre en morado.
class FiltroGrupo extends StatelessWidget {
  final String? valor;
  final ValueChanged<String?> onChanged;
  const FiltroGrupo(this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) {
    final g = store.grupo(valor);
    return BotonMenu<String>(
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
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(P.radioControl),
          border: Border.all(color: g == null ? P.borde : P.morado.withValues(alpha: .45)),
          color: g == null ? P.superficie : P.moradoSuave,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconoGrupo, size: 18, color: g == null ? P.textoSuave : P.morado),
            const SizedBox(width: 6),
            Text(
              g?.nombre ?? 'Grupo',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: g == null ? P.texto : P.morado,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 18, color: g == null ? P.textoSuave : P.morado),
          ],
        ),
      ),
    );
  }
}
