import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../marca.dart';

/// Tipos de trabajo de la empresa: nombre, icono, color y la competencia que piden. «Otro» va siempre
/// el último y no se quita.
Future<void> abrirTipos(BuildContext context) => _dialogo(
  context,
  m('Tipos de trabajo'),
  m('Los que eliges al crear un trabajo. Cambiar el nombre cambia también sus trabajos.'),
  (context) => [
    for (final t in tipos) _FilaTipo(t, key: ValueKey(t.id)),
    const SizedBox(height: 8),
    Align(
      alignment: Alignment.centerLeft,
      child: Enlace(
        '+ Añadir tipo',
        onTap: () => store.guardarTipo(
          TipoInfo(store.nuevoId(), 'Nuevo tipo', 'otro', paleta[tipos.length % paleta.length], null),
        ),
      ),
    ),
  ],
);

/// Competencias de la empresa: lo que sabe hacer cada trabajador y lo que pide cada trabajo.
Future<void> abrirCompetencias(BuildContext context) => _dialogo(
  context,
  'Competencias',
  m('Pulpo solo asigna un trabajo a quien tiene sus competencias. Cambiar el nombre lo cambia en todas partes.'),
  (context) => [
    for (final c in competencias) _FilaCompetencia(c, key: ValueKey(c)),
    const SizedBox(height: 8),
    const _NuevaCompetencia(),
  ],
);

Future<void> _dialogo(
  BuildContext context,
  String titulo,
  String descripcion,
  List<Widget> Function(BuildContext) filas,
) => showDialog(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: P.fondo,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 22),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontFamily: P.titulos,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(CupertinoIcons.xmark, size: 19, color: P.textoSuave),
                ),
              ],
            ),
            Text(descripcion, style: TextStyle(fontSize: 13, color: P.textoSuave)),
            const SizedBox(height: 14),
            ...filas(context),
          ],
        ),
      ),
    ),
  ),
);

/// Campo de texto que guarda al salir de él o con Intro (no en cada letra: renombrar toca muchos trabajos).
class _CampoNombre extends StatefulWidget {
  final String valor;
  final ValueChanged<String> onGuardar;
  const _CampoNombre(this.valor, this.onGuardar);

  @override
  State<_CampoNombre> createState() => _CampoNombreState();
}

class _CampoNombreState extends State<_CampoNombre> {
  late final texto = TextEditingController(text: widget.valor);
  final foco = FocusNode();

  @override
  void initState() {
    super.initState();
    foco.addListener(() {
      if (!foco.hasFocus) _guardar();
    });
  }

  void _guardar() {
    final n = texto.text.trim();
    if (n.isEmpty) {
      texto.text = widget.valor;
    } else if (n != widget.valor) {
      widget.onGuardar(n);
    }
  }

  @override
  void dispose() {
    texto.dispose();
    foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: texto,
    focusNode: foco,
    onSubmitted: (_) => _guardar(),
    decoration: const InputDecoration(isDense: true),
  );
}

class _FilaTipo extends StatelessWidget {
  final TipoInfo t;
  const _FilaTipo(this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    final otro = t.id == tipos.last.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Icono: al pulsarlo, los que se pueden elegir.
          BotonMenu<String>(
            tooltip: 'Cambiar el icono',
            seleccionado: t.clave,
            onSelected: (k) => store.guardarTipo(t.cambiar(clave: k)),
            opciones: [for (final e in iconosTipo.entries) (e.key, Icon(e.value, size: 20, color: t.color))],
            child: IconoCuadro(t.icono, t.color, size: 36),
          ),
          // En móvil no cabe: el color se cambia desde un ordenador.
          if (!esMovil(context)) ...[
            const SizedBox(width: 6),
            BotonMenu<int>(
              tooltip: 'Cambiar el color',
              onSelected: (i) => store.guardarTipo(t.cambiar(color: paleta[i])),
              opciones: [
                for (final (i, c) in paleta.indexed)
                  (
                    i,
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                  ),
              ],
              child: SizedBox(
                width: 28,
                height: 36,
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: t.color, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(child: _CampoNombre(t.nombre, (n) => store.guardarTipo(t.cambiar(nombre: n)))),
          const SizedBox(width: 8),
          SizedBox(
            width: esMovil(context) ? 110 : 170,
            child: BotonMenu<String>(
              tooltip: 'Competencia que pide',
              seleccionado: t.competencia ?? '',
              onSelected: (c) =>
                  store.guardarTipo(c.isEmpty ? t.cambiar(sinCompetencia: true) : t.cambiar(competencia: c)),
              opciones: [
                ('', Text('Ninguna', style: TextStyle(color: P.textoSuave))),
                for (final c in competencias) (c, Text(c)),
              ],
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: P.hover, borderRadius: BorderRadius.circular(P.radioControl)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.competencia ?? 'Sin competencia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.competencia == null ? P.textoSuave : P.texto),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, size: 18, color: P.textoSuave),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: otro
                ? null
                : IconButton(
                    tooltip: m('Quitar (sus trabajos pasan a «${tipos.last.nombre}»)'),
                    onPressed: () async {
                      if (await confirmar(
                        context,
                        m('¿Quitar «${t.nombre}»? Sus trabajos pasan a «${tipos.last.nombre}».'),
                        accion: 'Quitar',
                      )) {
                        store.borrarTipo(t.id);
                      }
                    },
                    icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilaCompetencia extends StatelessWidget {
  final String c;
  const _FilaCompetencia(this.c, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: _CampoNombre(c, (n) => store.renombrarCompetencia(c, n))),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: 'Quitar',
            onPressed: () async {
              if (await confirmar(
                context,
                m('¿Quitar «$c»? Se quita también de trabajadores y trabajos.'),
                accion: 'Quitar',
              )) {
                store.borrarCompetencia(c);
              }
            },
            icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
          ),
        ),
      ],
    ),
  );
}

class _NuevaCompetencia extends StatefulWidget {
  const _NuevaCompetencia();

  @override
  State<_NuevaCompetencia> createState() => _NuevaCompetenciaState();
}

class _NuevaCompetenciaState extends State<_NuevaCompetencia> {
  final texto = TextEditingController();

  void _anadir() {
    store.anadirCompetencia(texto.text);
    texto.clear();
  }

  @override
  void dispose() {
    texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: texto,
          onSubmitted: (_) => _anadir(),
          decoration: const InputDecoration(isDense: true, hintText: 'Nueva competencia'),
        ),
      ),
      const SizedBox(width: 8),
      Enlace('Añadir', onTap: _anadir),
    ],
  );
}

// ── Grupos de técnicos (Pultec) ──

/// Grupos de técnicos: nombre (no se repite) y área. Una OT asignada a un grupo se reparte al técnico más libre.
Future<void> abrirGrupos(BuildContext context) => _dialogo(
  context,
  'Grupos de técnicos',
  'Agrupa a tus técnicos (p. ej. «Hidráulica A»). Una orden asignada a un grupo se reparte sola al técnico más libre.',
  (context) => [
    for (final g in [...store.grupos]..sort((a, b) => a.nombre.compareTo(b.nombre)))
      _FilaGrupo(g, key: ValueKey('${g.id}-${g.nombre}')),
    const SizedBox(height: 8),
    const _NuevoGrupo(),
  ],
);

void _avisoNombreUsado(BuildContext context, String nombre) => ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(width: 360, content: Text('Ya hay un grupo llamado «$nombre»')),
);

class _FilaGrupo extends StatelessWidget {
  final GrupoTecnicos g;
  const _FilaGrupo(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final miembros = store.tecnicosDe(g.id);
    final otros = store.trabajadores.where((w) => w.activo && w.grupoId != g.id).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(P.radio),
        border: Border.all(color: P.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _CampoNombre(g.nombre, (nuevo) {
                  if (store.nombreGrupoUsado(nuevo, salvo: g.id)) return _avisoNombreUsado(context, nuevo);
                  store.guardarGrupo(g..nombre = nuevo);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: BotonMenu<String>(
                  relleno: EdgeInsets.zero,
                  tooltip: 'Área del grupo',
                  seleccionado: g.area,
                  opciones: [('', const Text('Sin área')), for (final c in competencias) (c, Text(c))],
                  onSelected: (a) => store.guardarGrupo(g..area = a),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      suffixIcon: Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave),
                    ),
                    child: Text(g.area.isEmpty ? 'Sin área' : g.area, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: 'Quitar grupo',
                  onPressed: () async {
                    if (await confirmar(
                      context,
                      '¿Quitar el grupo «${g.nombre}»? Sus técnicos se quedan sin grupo.',
                      accion: 'Quitar',
                    )) {
                      store.borrarGrupo(g.id);
                    }
                  },
                  icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Sus técnicos y, al final, el desplegable para meter más (los de otro grupo se cambian a este).
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final w in miembros)
                InputChip(
                  avatar: Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 20),
                  label: Text(w.nombreCompleto),
                  onDeleted: () => store.guardarTrabajador(w..grupoId = null),
                  deleteButtonTooltipMessage: 'Sacar del grupo',
                  backgroundColor: P.fondo,
                  side: BorderSide(color: P.borde),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
              if (otros.isNotEmpty)
                BotonMenu<String>(
                  tooltip: 'Meter un técnico en el grupo',
                  opciones: [
                    for (final w in otros)
                      (
                        w.id,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 20),
                            const SizedBox(width: 8),
                            Text(w.nombreCompleto),
                            if (store.grupo(w.grupoId) case final otro?) ...[
                              const SizedBox(width: 8),
                              Text(otro.nombre, style: TextStyle(color: P.textoSuave)),
                            ],
                          ],
                        ),
                      ),
                  ],
                  onSelected: (id) {
                    final w = store.trabajador(id);
                    if (w != null) store.guardarTrabajador(w..grupoId = g.id);
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
              else if (miembros.isEmpty)
                Text('Aún no hay técnicos', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NuevoGrupo extends StatefulWidget {
  const _NuevoGrupo();

  @override
  State<_NuevoGrupo> createState() => _NuevoGrupoState();
}

class _NuevoGrupoState extends State<_NuevoGrupo> {
  final texto = TextEditingController();

  void _anadir() {
    final n = texto.text.trim();
    if (n.isEmpty) return;
    if (store.nombreGrupoUsado(n)) return _avisoNombreUsado(context, n);
    store.guardarGrupo(GrupoTecnicos(id: store.nuevoId(), nombre: n));
    texto.clear();
  }

  @override
  void dispose() {
    texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: texto,
          onSubmitted: (_) => _anadir(),
          decoration: const InputDecoration(isDense: true, hintText: 'Nuevo grupo, p. ej. Hidráulica A'),
        ),
      ),
      const SizedBox(width: 8),
      Enlace('Añadir', onTap: _anadir),
    ],
  );
}
