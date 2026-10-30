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
  }

  @override
  void dispose() {
    filtroActivos.removeListener(_cambio);
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
                : _TablaActivos(activos, (id) => setState(() => abierto = id)),
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
            if (medio) const Col('Horas restantes', ancho: 120),
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
              if (medio) Padding(padding: const EdgeInsets.only(left: 12), child: celdaTexto(horasRestantes(a), suave: true)),
              if (medio)
                Tooltip(
                  message: a.frecuencia == FrecuenciaActivo.horas
                      ? 'Fecha estimada según la lectura del contador y las horas de uso diarias o semanales.'
                      : 'Fecha del próximo mantenimiento.',
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

String horasRestantes(Activo a) {
  final h = a.horasRestantes;
  if (a.frecuencia != FrecuenciaActivo.horas || h == null) return '—';
  return '≈ ${h <= 0 ? '0' : h.toStringAsFixed(0)} h';
}

String proximaFecha(Activo a) {
  final d = a.proximoMantenimiento;
  if (d == null) return a.frecuencia == FrecuenciaActivo.horas ? 'Falta ritmo de uso' : '—';
  return '${a.frecuencia == FrecuenciaActivo.horas ? '≈ ' : ''}${fecha(d)}';
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
  bool editando = false;
  String? tareaId;

  void _abrir(String id) => setState(() {
    elegido = id;
    pestana = 0;
    editando = false;
  });

  Widget _cifra(String etiqueta, String valor, String nota) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(etiqueta, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
      const SizedBox(height: 4),
      Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8)),
      Text(nota, style: TextStyle(fontSize: 12, color: P.textoSuave)),
    ],
  );

  void _nuevaOt(Activo a) => abrirTareaForm(
    context,
    null,
    borrador: Tarea(
      id: store.nuevoId(),
      activoId: a.id,
      plantilla: false,
      tipoMantenimiento: TipoMantenimiento.preventivo,
      proximo: a.proximoMantenimiento ?? hoy(),
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
              if (pestana == 0)
                BotonPrimario(
                  'Nuevo componente',
                  conIcono: true,
                  icono: Icons.account_tree_outlined,
                  onPressed: () => abrirActivoForm(context, padreId: a.id),
                ),
              if (pestana == 1 && !editando)
                BotonPrimario('Editar', icono: Icons.edit_outlined, onPressed: () => setState(() => editando = true)),
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
              editando = false;
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
                      Tarjeta(
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Pill(textoEstado(g), colorEstado(g), punto: true),
                            _cifra(
                              'Próximo',
                              a.proximoMantenimiento == null ? 'Sin estimar' : '${a.frecuencia == FrecuenciaActivo.horas ? '≈ ' : ''}${relativo(a.proximoMantenimiento!)}',
                              proximaFecha(a),
                            ),
                            _cifra(
                              'Contador',
                              horas(a.horas),
                              a.frecuencia == FrecuenciaActivo.horas && a.horasRestantes != null
                                  ? horasRestantes(a)
                                  : 'Horas de uso',
                            ),
                            _cifra('Componentes', '${componentes.length}', 'Cada uno con su mantenimiento'),
                            _cifra(
                              'Órdenes pendientes',
                              '${ots.where(otPendiente).length}',
                              'Del activo y sus componentes',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: huecoVista),
                      Expanded(
                        child: componentes.isEmpty
                            ? Vacio(
                                icono: Icons.account_tree_outlined,
                                titulo: 'Sin componentes',
                                texto: 'Añade las piezas y los componentes de este activo.',
                              )
                            : _TablaActivos(componentes, _abrir, componentes: true),
                      ),
                    ],
                  ),
                  1 => ActivoForm(
                    key: ValueKey(editando ? '${a.id}-editar' : '${a.id}-${jsonEncode(a.toJson())}'),
                    original: a,
                    incrustada: true,
                    soloLectura: !editando,
                    onTerminar: () => setState(() => editando = false),
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
  late final cadaHoras = TextEditingController(text: a.cadaHoras?.toString() ?? '')..addListener(_actualizar);
  late final cadaMeses = TextEditingController(text: a.cadaMeses?.toString() ?? '')..addListener(_actualizar);
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
      cadaHoras,
      cadaMeses,
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
    if (a.frecuencia == FrecuenciaActivo.horas && (_valor(cadaHoras) == null || _valor(cadaHoras)! < .1)) {
      errores['intervalo'] = 'Indica un intervalo de al menos 0,1 horas';
    }
    if (a.frecuencia == FrecuenciaActivo.meses &&
        (int.tryParse(cadaMeses.text) == null || int.parse(cadaMeses.text) < 1 || int.parse(cadaMeses.text) > 1200)) {
      errores['intervalo'] = 'Indica de 1 a 1200 meses';
    }
    if (a.frecuencia == FrecuenciaActivo.fecha && a.fechaMantenimiento == null) {
      errores['fecha'] = 'Elige la próxima fecha';
    }
    return errores;
  }

  void _irA(GlobalKey clave) => WidgetsBinding.instance.addPostFrameCallback((_) {
    final c = clave.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300), alignment: .1);
  });

  Activo get _prevision => a.copia()
    ..horas = _valor(horasC, vacio: 0) ?? 0
    ..cadaHoras = _valor(cadaHoras)
    ..cadaMeses = int.tryParse(cadaMeses.text)
    ..horasUltimoMantenimiento = math.min(_valor(ultimoContador, vacio: 0) ?? 0, _valor(horasC, vacio: 0) ?? 0)
    ..horasUso = _valor(ritmo, vacio: 0) ?? 0;

  String get _estimacion {
    if (_erroresMantenimiento.isNotEmpty) return 'Completa los datos del mantenimiento para calcular la previsión.';
    final p = _prevision;
    final siguiente = p.proximoMantenimiento;
    if (p.frecuencia == FrecuenciaActivo.horas && (p.horasRestantes ?? 1) <= 0) {
      return 'El mantenimiento ya está vencido según la lectura del contador.';
    }
    if (siguiente == null) return 'Escribe las horas de uso por día o semana para calcular la fecha estimada.';
    final ahora = hoy();
    final dias = DateTime.utc(
      siguiente.year,
      siguiente.month,
      siguiente.day,
    ).difference(DateTime.utc(ahora.year, ahora.month, ahora.day)).inDays;
    final plazo = dias == 0
        ? 'hoy'
        : dias > 0
        ? 'en $dias días'
        : 'vencido hace ${-dias} días';
    return '${p.frecuencia == FrecuenciaActivo.horas ? 'Fecha estimada' : 'Próximo mantenimiento'}: '
        '${p.frecuencia == FrecuenciaActivo.horas ? '≈ ' : ''}${fecha(siguiente)} · $plazo.'
        '${p.frecuencia == FrecuenciaActivo.horas ? ' ${horasRestantes(p)} hasta el mantenimiento, según la última lectura.' : ''}';
  }

  static const _frecuencias = ['Sin definir', 'Horas de uso', 'Meses', 'Fecha concreta'];

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

  Widget _mantenimiento() {
    final errores = intentoGuardar ? _erroresMantenimiento : <String, String>{};
    return KeyedSubtree(
      key: _claveMantenimiento,
      child: Bloque(
        'Mantenimiento propio',
        descripcion: 'Este activo o componente tiene su propio intervalo, independiente del resto.',
        [
          // Tres filas de dos: cómo se programa y cada cuánto; lectura del contador; ritmo de uso.
          dos(
            _menu<FrecuenciaActivo>(
              'Programar por',
              tooltip: 'Cómo se programa el mantenimiento',
              valor: a.frecuencia,
              opciones: {for (final f in FrecuenciaActivo.values) f: _frecuencias[f.index]},
              onSelected: (f) => setState(() {
                a.frecuencia = f;
                if (f == FrecuenciaActivo.meses) a.ultimoMantenimiento ??= hoy();
              }),
            ),
            switch (a.frecuencia) {
              FrecuenciaActivo.horas => campo(
                'Cada cuántas horas',
                cadaHoras,
                teclado: const TextInputType.numberWithOptions(decimal: true),
                hint: '5000',
                error: errores['intervalo'],
                obligatorio: true,
              ),
              FrecuenciaActivo.meses => campo(
                'Cada cuántos meses',
                cadaMeses,
                teclado: TextInputType.number,
                hint: '3',
                error: errores['intervalo'],
                obligatorio: true,
              ),
              FrecuenciaActivo.fecha => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampoFecha(
                    'Próximo mantenimiento',
                    a.fechaMantenimiento,
                    (d) => setState(() => a.fechaMantenimiento = d),
                  ),
                  if (errores['fecha'] != null) Text(errores['fecha']!, style: const TextStyle(color: P.rojo)),
                ],
              ),
              FrecuenciaActivo.sinDefinir => const SizedBox(),
            },
          ),
          if (a.frecuencia == FrecuenciaActivo.meses)
            dos(
              CampoFecha(
                'Último mantenimiento',
                a.ultimoMantenimiento,
                (d) => setState(() => a.ultimoMantenimiento = d),
                hasta: hoy(),
              ),
              const SizedBox(),
            ),
          dos(
            CampoFecha('Fecha de la lectura', a.fechaLectura, (d) => setState(() => a.fechaLectura = d), hasta: hoy()),
            campo(
              'Contador actual (h)',
              horasC,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              hint: '0',
              error: errores['actual'],
              obligatorio: true,
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
              hint: a.usoSemanal ? '35' : '7',
              error: errores['uso'],
              obligatorio: true,
            ),
          ),
          if (a.frecuencia != FrecuenciaActivo.sinDefinir) Consejo(_estimacion),
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
      ..cadaHoras = a.frecuencia == FrecuenciaActivo.horas ? _valor(cadaHoras) : null
      ..cadaMeses = a.frecuencia == FrecuenciaActivo.meses ? int.tryParse(cadaMeses.text) : null
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
