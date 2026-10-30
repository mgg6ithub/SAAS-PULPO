import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activo.dart';
import 'iconos.dart';
import 'gravedad.dart';
import 'tipo_mantenimiento.dart';
import 'historicos.dart';
import 'plan.dart';
import 'planes.dart';
import '../screens/tabla_trabajos.dart';
import '../screens/tarea_detalle.dart';

/// Color del estado de un activo: el de su mantenimiento pendiente más grave (él y sus componentes).
/// Sin nada pendiente, verde: puede funcionar.
/// El estado de mantenimiento lo marca cada activo en su ficha (no sus OT).
TipoMantenimiento? gravedadDe(String activoId) => store.activo(activoId)?.tipo;
Color colorEstado(TipoMantenimiento? g) => g?.color ?? P.verde;
String textoEstado(TipoMantenimiento? g) => g?.etiqueta ?? 'Al día';

/// Filtro de la lista de Activos por estado: 0 = todos; 1.. = tipo de mantenimiento.
/// Fuera del estado para que «Ver más» de Inicio pueda dejarlo puesto antes de ir.
final filtroActivos = ValueNotifier(0);

/// Avisa a Activos de que vuelva a la lista (aunque el filtro no cambie), al llegar desde Inicio.
final _aLaLista = ValueNotifier(0);

/// Desde Inicio: Activos en la lista (nunca dentro de un activo abierto antes) con este filtro.
void abrirListaActivos(int filtro) {
  filtroActivos.value = filtro;
  _aLaLista.value++;
}
const _filtros = ['Todos', 'Preventivo', 'No crítico', 'Crítico'];

bool _pasaFiltro(TipoMantenimiento? g) => switch (filtroActivos.value) {
  0 => true,
  final f => g?.index == f - 1,
};

/// Sección «Activos» de iPultec: las máquinas con el color de su estado; al abrir una, su árbol de componentes.
class Activos extends StatefulWidget {
  const Activos({super.key});

  @override
  State<Activos> createState() => _ActivosState();
}

class _ActivosState extends State<Activos> {
  String q = '';
  String? abierto;

  @override
  void initState() {
    super.initState();
    filtroActivos.addListener(_cambio);
    _aLaLista.addListener(_cambio);
  }

  @override
  void dispose() {
    filtroActivos.removeListener(_cambio);
    _aLaLista.removeListener(_cambio);
    super.dispose();
  }

  void _cambio() => setState(() => abierto = null);

  @override
  Widget build(BuildContext context) {
    if (abierto != null) return ActivoDetalle(activoId: abierto!, onVolver: () => setState(() => abierto = null));
    final activos = store.hijosDe(null).where((a) {
      final t = '${a.tag} ${a.nombre} ${a.fabricante} ${a.modelo} ${a.division}'.toLowerCase();
      return t.contains(q.toLowerCase()) && _pasaFiltro(gravedadDe(a.id));
    }).toList();
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarraVista(
            izquierda: const [TituloVista('Activos')],
            derecha: const [],
            principal: BotonPrimario(
              'Nuevo activo',
              conIcono: true,
              icono: Icons.add_rounded,
              tecla: 'N',
              onPressed: () => abrirActivoForm(context),
            ),
          ),
          const SizedBox(height: 8),
          BarraVista(
            izquierda: [
              const SizedBox.shrink(),
              Pestanas(
                opciones: _filtros,
                colores: [null, for (final t in TipoMantenimiento.values) t.color],
                seleccion: filtroActivos.value,
                onChanged: (i) => filtroActivos.value = i,
              ),
            ],
            derecha: [
              Buscador(hint: 'Buscar activo…', onChanged: (v) => setState(() => q = v)),
            ],
          ),
          const SizedBox(height: huecoVista),
          Expanded(
            child: activos.isEmpty
                ? Vacio(
                    icono: Icons.precision_manufacturing_outlined,
                    titulo: q.isEmpty && filtroActivos.value == 0 ? 'Aún no tienes activos' : null,
                    texto: q.isEmpty && filtroActivos.value != 0
                        ? 'Ninguna máquina con este estado'
                        : q.isEmpty
                        ? 'Da de alta tus máquinas (camiones, compresores, prensas…) y sus componentes.'
                        : 'Ningún activo coincide con la búsqueda',
                    accion: q.isEmpty && filtroActivos.value == 0
                        ? FilledButton(
                            onPressed: () => abrirActivoForm(context),
                            child: const Text('Añadir el primero'),
                          )
                        : null,
                  )
                : _TablaActivos(activos, (id) {
                    // Al cambiar de vista con el ratón encima de un tipo, su aviso se quedaba pegado.
                    Tooltip.dismissAllToolTips();
                    setState(() => abierto = id);
                  }),
          ),
        ],
      ),
    );
  }
}

/// Todos los activos en orden de árbol, con su nivel (0 = activo, 1 = componente…).
List<(Activo, int)> arbolActivos() {
  final r = <(Activo, int)>[];
  void anadir(Activo a, int nivel) {
    r.add((a, nivel));
    for (final h in store.hijosDe(a.id)) {
      anadir(h, nivel + 1);
    }
  }

  for (final a in store.hijosDe(null)) {
    anadir(a, 0);
  }
  return r;
}

class _TablaActivos extends StatelessWidget {
  final List<Activo> activos;
  final ValueChanged<String> onAbrir;
  final bool componentes;
  const _TablaActivos(this.activos, this.onAbrir, {this.componentes = false});

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => (box.maxWidth > 980, box.maxWidth > 600),
    builder: (context, box) {
      final ancho = box.maxWidth > 980;
      // Móvil: el activo y el punto de su estado.
      final medio = box.maxWidth > 600;
      return Align(
        alignment: Alignment.topCenter,
        child: Tabla(
          columnas: [
            Col(componentes ? 'Componente' : 'Activo', flex: 3),
            if (ancho) const Col('Fabricante y modelo', flex: 2),
            if (ancho) const Col('División', flex: 2),
            if (ancho) const Col('Horas totales', ancho: 120, derecha: true),
            if (medio) const Col('Mantenimientos', ancho: 130, derecha: true),
            if (medio) const Col('Próximo mantenimiento', ancho: 160),
            const Col('Tipo de mantenimiento', ancho: 160),
            if (medio)
              Col(
                'Componentes',
                ancho: 32,
                derecha: true,
                cabecera: Tooltip(
                  message: 'Componentes',
                  child: Icon(Icons.account_tree_outlined, size: 18, color: P.textoSuave),
                ),
              ),
          ],
          filas: activos.length,
          celdas: (i) {
            final a = activos[i];
            final g = gravedadDe(a.id);
            return [
              Row(
                children: [
                  Tooltip(message: textoEstado(g), child: Icon(iconoIndustrial(a.icono), color: colorEstado(g), size: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: celdaTexto(a.titulo, negrita: true)),
                ],
              ),
              if (ancho) celdaTexto([a.fabricante, a.modelo].where((x) => x.isNotEmpty).join(' '), suave: true),
              if (ancho) celdaTexto(a.division, suave: true),
              if (ancho) Padding(padding: const EdgeInsets.only(right: 16), child: celdaTexto(horas(a.horas), suave: true)),
              if (medio)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: celdaTexto('${planesRama(a.id).length}', suave: true),
                ),
              if (medio)
                Tooltip(
                  message: 'El más cercano de sus mantenimientos y los de sus componentes.',
                  child: celdaTexto(proximaFecha(a), suave: true),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: g == null ? const Pill('Al día', P.verde, punto: true) : PillTipo(g),
              ),
              if (medio) celdaTexto('${store.ramaDe(a.id).length - 1}', suave: true),
            ];
          },
          onTap: (i) => onAbrir(activos[i].id),
          pie: pieTabla(
            activos.length,
            componentes
                ? (activos.length == 1 ? 'componente' : 'componentes')
                : (activos.length == 1 ? 'activo' : 'activos'),
          ),
        ),
      );
    },
  );
}

/// Mantenimientos del activo y de todos sus componentes.
List<PlanMantenimiento> planesRama(String id) {
  final rama = store.ramaDe(id);
  return store.planes.where((p) => rama.contains(p.activoId)).toList();
}

/// El mantenimiento activo que antes toca en el activo o sus componentes.
DateTime? proximoDe(String id) {
  DateTime? r;
  for (final p in planesRama(id).where((p) => p.activa)) {
    final d = proximoPlan(p);
    if (d != null && (r == null || d.isBefore(r))) r = d;
  }
  return r;
}

String proximaFecha(Activo a) {
  final d = proximoDe(a.id);
  return d == null ? '—' : fecha(d);
}

String horas(double h) => h == 0 ? '—' : '${h % 1 == 0 ? h.toInt() : h} h';

/// Ficha del activo y de cada componente: resumen, datos editables, OT e histórico propio.
class ActivoDetalle extends StatefulWidget {
  final String activoId;
  final VoidCallback onVolver;
  const ActivoDetalle({super.key, required this.activoId, required this.onVolver});

  @override
  State<ActivoDetalle> createState() => _ActivoDetalleState();
}

class _ActivoDetalleState extends State<ActivoDetalle> {
  late String elegido = widget.activoId;
  int pestana = 0;
  /// Sube al guardar o cancelar en Datos: el formulario vuelve a leer el activo.
  int vuelta = 0;
  String? tareaId;

  /// Qué enseña Resumen: 0 = mantenimientos (por defecto), 1 = subcomponentes.
  int vista = 0;

  void _abrir(String id) => setState(() {
    Tooltip.dismissAllToolTips();
    elegido = id;
    pestana = 0;
    vista = 0;
  });

  /// Mantenimientos del activo y de sus componentes; la columna Código dice de cuál es cada uno.
  Widget _mantenimientos(Activo a, List<PlanMantenimiento> planes) {
    if (planes.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Tarjeta(
          child: SizedBox(
            width: double.infinity,
            child: Text(
              'Aún no hay mantenimientos. Crea lo que hay que hacerle a este ${a.padreId == null ? 'activo' : 'componente'}: cada cuánto, quién y cómo.',
              style: TextStyle(fontSize: 13.5, color: P.textoSuave),
            ),
          ),
        ),
      );
    }
    final lista = [...planes]
      ..sort((x, y) => (proximoPlan(x) ?? DateTime(9999)).compareTo(proximoPlan(y) ?? DateTime(9999)));
    return TablaPlanes(lista, activoId: a.id);
  }

  /// Dato corto de la línea de resumen: etiqueta gris y valor en negrita.
  Widget _dato(String etiqueta, String valor) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '$etiqueta  ', style: TextStyle(color: P.textoSuave)),
        TextSpan(text: valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
    style: const TextStyle(fontSize: 13.5),
  );

  void _nuevaOt(Activo a) => abrirTareaForm(
    context,
    null,
    borrador: Tarea(
      id: store.nuevoId(),
      activoId: a.id,
      plantilla: false,
      tipoMantenimiento: TipoMantenimiento.preventivo,
      proximo: proximoDe(a.id) ?? hoy(),
      periodicidad: Periodicidad.unica,
      criticidad: Criticidad.rutinaria,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = store.activo(elegido) ?? store.activo(widget.activoId);
    if (a == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVolver());
      return const SizedBox();
    }
    if (tareaId != null) {
      return TareaDetalle(
        tareaId: tareaId!,
        onVolver: () => setState(() => tareaId = null),
        onAbrir: (id) => setState(() => tareaId = id),
      );
    }
    elegido = a.id;
    final padre = store.activo(a.padreId);
    final ots = store.otsDe(a.id).where((t) => !t.esPlantilla && t.activa).toList();
    final componentes = store.hijosDe(a.id);
    final planes = planesRama(a.id);
    final proximo = proximoDe(a.id);
    final g = gravedadDe(a.id);
    return Padding(
      padding: margenPagina,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cabecera(
            lider: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: padre == null ? 'Volver a Activos' : 'Volver a ${padre.titulo}',
                  onPressed: padre == null ? widget.onVolver : () => _abrir(padre.id),
                  icon: Icon(Icons.arrow_back_rounded, size: 20, color: P.textoSuave),
                ),
                const SizedBox(width: 4),
                Icon(iconoIndustrial(a.icono), size: 28, color: colorEstado(g)),
              ],
            ),
            titulo: a.titulo.isEmpty ? 'Activo' : a.titulo,
            subtitulo: [
              if (padre != null) 'Componente de ${padre.titulo}',
              a.fabricante,
              a.modelo,
            ].where((x) => x.isNotEmpty).join(' · '),
            acciones: [
              if (pestana == 2)
                BotonPrimario('Nueva orden de trabajo', conIcono: true, icono: Icons.add_rounded, onPressed: () => _nuevaOt(a)),
            ],
          ),
          const SizedBox(height: 18),
          PestanasOscuras(
            opciones: const ['Resumen', 'Datos', 'Órdenes de trabajo', 'Histórico'],
            seleccion: pestana,
            onChanged: (i) => setState(() {
              pestana = i;
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (actual, anteriores) => Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
              child: KeyedSubtree(
                key: ValueKey('$elegido-$pestana'),
                child: switch (pestana) {
                  0 => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Pill(textoEstado(g), colorEstado(g), punto: true),
                          _dato('Próximo', proximo == null ? 'Sin estimar' : '${relativo(proximo)} · ${fecha(proximo)}'),
                          _dato('Contador', horas(a.horas)),
                          _dato('Órdenes pendientes', '${ots.where(otPendiente).length}'),
                        ],
                      ),
                      const SizedBox(height: huecoVista),
                      Row(
                        children: [
                          const Spacer(),
                          Pestanas(
                            opciones: ['Mantenimientos · ${planes.length}', 'Subcomponentes · ${componentes.length}'],
                            seleccion: vista,
                            onChanged: (i) => setState(() => vista = i),
                          ),
                          const SizedBox(width: 12),
                          vista == 0
                              ? BotonPrimario(
                                  'Nuevo mantenimiento',
                                  conIcono: true,
                                  icono: Icons.add_rounded,
                                  onPressed: () => abrirPlanForm(context, activoId: a.id),
                                )
                              : BotonPrimario(
                                  'Nuevo componente',
                                  conIcono: true,
                                  icono: Icons.add_rounded,
                                  onPressed: () => abrirActivoForm(context, padreId: a.id),
                                ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: vista == 0
                            ? _mantenimientos(a, planes)
                            : componentes.isEmpty
                            ? Vacio(
                                icono: Icons.account_tree_outlined,
                                titulo: 'Sin componentes',
                                texto: 'Añade las piezas y los componentes de este ${a.padreId == null ? 'activo' : 'componente'}.',
                              )
                            : _TablaActivos(componentes, _abrir, componentes: true),
                      ),
                    ],
                  ),
                  1 => ActivoForm(
                    key: ValueKey('${a.id}-$vuelta-${jsonEncode(a.toJson())}'),
                    original: a,
                    incrustada: true,
                    onTerminar: () => setState(() => vuelta++),
                  ),
                  2 =>
                    ots.isEmpty
                        ? const Vacio(
                            icono: Icons.assignment_outlined,
                            titulo: 'Sin órdenes de trabajo',
                            texto: 'Las órdenes de este activo y sus componentes aparecerán aquí.',
                          )
                        : TablaTrabajos(
                            ots,
                            conCliente: false,
                            nombre: 'orden de trabajo',
                            onAbrir: (id) => setState(() => tareaId = id),
                          ),
                  _ => Historicos(activoId: a.id, incrustada: true),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> abrirActivoForm(BuildContext context, {Activo? original, String? padreId}) =>
    abrirPanel(context, ActivoForm(original: original, padreId: padreId));

/// Alta y edición de un activo o de un componente (con [padreId], dentro de un activo o de otro componente).
class ActivoForm extends StatefulWidget {
  final Activo? original;
  final String? padreId;
  final bool incrustada, soloLectura;
  final VoidCallback? onTerminar;
  const ActivoForm({
    super.key,
    this.original,
    this.padreId,
    this.incrustada = false,
    this.soloLectura = false,
    this.onTerminar,
  });

  @override
  State<ActivoForm> createState() => _ActivoFormState();
}

class _ActivoFormState extends State<ActivoForm> {
  late final Activo a = widget.original?.copia() ?? Activo(id: store.nuevoId(), padreId: widget.padreId);
  late final tag = TextEditingController(text: a.tag)..addListener(() => setState(() {}));
  late final nombre = TextEditingController(text: a.nombre)..addListener(() => setState(() {}));
  late final fabricante = TextEditingController(text: a.fabricante);
  late final modelo = TextEditingController(text: a.modelo);
  late final serie = TextEditingController(text: a.numeroSerie);
  late final division = TextEditingController(text: a.division);
  late final horasC = TextEditingController(text: a.horas == 0 ? '' : '${a.horas}')
    ..addListener(() => setState(() => a.fechaLectura = hoy()));
  late final ultimoContador = TextEditingController(text: '${a.horasUltimoMantenimiento}')..addListener(_actualizar);
  late final ritmo = TextEditingController(text: a.horasUso == 0 ? '' : '${a.horasUso}')..addListener(_actualizar);
  final _claveIdentificacion = GlobalKey(), _claveMantenimiento = GlobalKey();
  late final repuestos = TextEditingController(text: a.repuestos);
  late final notas = TextEditingController(text: a.notas);
  bool intentoGuardar = false;

  @override
  void dispose() {
    for (final c in [
      tag,
      nombre,
      fabricante,
      modelo,
      serie,
      division,
      horasC,
      repuestos,
      notas,
      ultimoContador,
      ritmo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _actualizar() => setState(() {});

  double? _valor(TextEditingController c, {double? vacio}) {
    var texto = c.text.trim().replaceAll(' ', '');
    if (texto.isEmpty) return vacio;
    if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(texto)) texto = texto.replaceAll('.', '');
    final n = double.tryParse(texto.replaceAll(',', '.'));
    return n != null && n.isFinite ? n : null;
  }

  Map<String, String> get _erroresMantenimiento {
    final errores = <String, String>{};
    final actual = _valor(horasC, vacio: 0);
    final uso = _valor(ritmo, vacio: 0);
    if (actual == null || actual < 0) errores['actual'] = 'Escribe un contador válido, desde 0';
    if (uso == null || uso < 0 || uso > (a.usoSemanal ? 168 : 24)) {
      errores['uso'] = a.usoSemanal ? 'Entre 0 y 168 horas semanales' : 'Entre 0 y 24 horas al día';
    }
    return errores;
  }

  void _irA(GlobalKey clave) => WidgetsBinding.instance.addPostFrameCallback((_) {
    final c = clave.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300), alignment: .1);
  });

  /// Desplegable con aspecto de campo (etiqueta encima y chevron), alineado con los campos de texto.
  Widget _menu<T>(
    String label, {
    required String tooltip,
    required T valor,
    required Map<T, String> opciones,
    required ValueChanged<T> onSelected,
  }) => conMargen(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        etiqueta(label),
        BotonMenu<T>(
          relleno: EdgeInsets.zero,
          tooltip: tooltip,
          seleccionado: valor,
          opciones: [for (final e in opciones.entries) (e.key, Text(e.value))],
          onSelected: onSelected,
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave),
            ),
            child: Text(opciones[valor]!),
          ),
        ),
      ],
    ),
  );

  /// Lectura del contador y ritmo de uso: datos del activo con los que se estiman sus mantenimientos por horas.
  /// Los mantenimientos van aparte (Resumen → Mantenimientos).
  Widget _mantenimiento() {
    final errores = intentoGuardar ? _erroresMantenimiento : <String, String>{};
    return KeyedSubtree(
      key: _claveMantenimiento,
      child: Bloque(
        'Contador y uso',
        descripcion: 'Con ellos se estiman los mantenimientos por horas de este activo o componente.',
        [
          dos(
            CampoFecha('Fecha de la lectura', a.fechaLectura, (d) => setState(() => a.fechaLectura = d), hasta: hoy()),
            campo(
              'Contador actual (h)',
              horasC,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              hint: '0',
              error: errores['actual'],
            ),
          ),
          dos(
            _menu<bool>(
              'Ritmo de uso',
              tooltip: 'Horas de uso diarias o semanales',
              valor: a.usoSemanal,
              opciones: const {false: 'Media por día natural', true: 'Total por semana'},
              onSelected: (v) => setState(() => a.usoSemanal = v),
            ),
            campo(
              a.usoSemanal ? 'Horas de uso por semana' : 'Horas de uso por día',
              ritmo,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              hint: 'Sin indicar',
              error: errores['uso'],
            ),
          ),
        ],
      ),
    );
  }

  bool get componente => a.padreId != null;
  String? get error =>
      intentoGuardar && tag.text.trim().isEmpty && nombre.text.trim().isEmpty ? 'Ponle un tag o un nombre' : null;

  void guardar() {
    setState(() => intentoGuardar = true);
    if (error != null) return _irA(_claveIdentificacion);
    if (_erroresMantenimiento.isNotEmpty) return _irA(_claveMantenimiento);
    a
      ..tag = tag.text.trim()
      ..nombre = nombre.text.trim()
      ..fabricante = fabricante.text.trim()
      ..modelo = modelo.text.trim()
      ..numeroSerie = serie.text.trim()
      ..division = division.text.trim()
      ..horas = _valor(horasC, vacio: 0) ?? 0
      ..horasUltimoMantenimiento = math.min(_valor(ultimoContador, vacio: 0) ?? 0, _valor(horasC, vacio: 0) ?? 0)
      ..horasUso = _valor(ritmo, vacio: 0) ?? 0
      ..repuestos = repuestos.text.trim()
      ..notas = notas.text.trim();
    store.guardarActivo(a);
    if (widget.incrustada) {
      widget.onTerminar?.call();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existe = widget.original != null;
    final padre = store.activo(a.padreId);
    final que = componente ? 'componente' : 'activo';
    return VentanaFormulario(
      incrustada: widget.incrustada,
      soloLectura: widget.soloLectura,
      onCancelar: widget.incrustada ? widget.onTerminar : null,
      etiqueta: padre?.titulo ?? 'Activos',
      titulo: existe ? 'Editar $que' : 'Nuevo $que',
      tituloDesplazado: [tag.text, nombre.text].where((x) => x.isNotEmpty).join(' · '),
      onGuardar: guardar,
      bajoBotones: MenuTipoMantenimiento(a.tipo, (t) => setState(() => a.tipo = t)),
      avisos: [
        if (error != null) ('Te falta el tag o el nombre', () => _irA(_claveIdentificacion)),
        if (intentoGuardar && _erroresMantenimiento.isNotEmpty)
          (_erroresMantenimiento.values.first, () => _irA(_claveMantenimiento)),
      ],
      onBorrar: !existe
          ? null
          : () async {
              final nav = Navigator.of(context);
              final n = store.ramaDe(a.id).length - 1;
              final con = n == 0 ? '' : ' y sus $n ${n == 1 ? 'componente' : 'componentes'}';
              if (await confirmar(context, '¿Eliminar ${a.titulo}$con? Sus OT se quedan, sin activo.')) {
                store.borrarActivo(a.id);
                if (widget.incrustada) {
                  widget.onTerminar?.call();
                } else {
                  nav.pop();
                }
              }
            },
      campos: [
        Bloque(
          componente ? 'Componente' : 'Activo',
          primero: true,
          descripcion: componente ? 'Qué pieza de la máquina es.' : 'Qué máquina es y cómo se identifica.',
          pie: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              etiqueta('Icono'),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final (clave, nombre, icono) in iconosIndustriales)
                    IconButton(
                      tooltip: nombre,
                      isSelected: a.icono == clave,
                      style: IconButton.styleFrom(
                        fixedSize: const Size(40, 40),
                        backgroundColor: a.icono == clave ? P.morado.withValues(alpha: .1) : Colors.transparent,
                        foregroundColor: a.icono == clave ? P.morado : P.textoSuave,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(P.radioControl)),
                      ),
                      onPressed: () => setState(() => a.icono = clave),
                      icon: Icon(icono, size: 22),
                    ),
                ],
              ),
            ],
          ),
          [
            dos(
              KeyedSubtree(
                key: _claveIdentificacion,
                child: campo('Tag', tag, hint: componente ? 'CAM-01-MOT' : 'CAM-01', error: error, obligatorio: true),
              ),
              campo('Nombre', nombre, hint: componente ? 'Motor' : 'Camión cisterna', obligatorio: true),
            ),
          ],
        ),
        Bloque('Ficha técnica', descripcion: 'Los datos de la placa.', [
          dos(campo('Fabricante', fabricante), campo('Modelo', modelo)),
          campo('Número de serie', serie),
          if (!componente) campo('División o actividad', division, hint: 'Limpieza de tanques, transporte…'),
        ]),
        _mantenimiento(),
        Bloque('Repuestos', descripcion: 'Piezas y consumibles que usa.', [campo('Repuestos', repuestos, lineas: 3)]),
        Bloque('Notas', [campo('Notas internas', notas, lineas: 3)]),
      ],
    );
  }
}
