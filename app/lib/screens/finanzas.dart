import 'package:flutter/material.dart';

import '../finanzas.dart';
import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Finanzas básicas: facturas proforma y presupuestos (sin valor fiscal), resumen del mes y exportar.
class VistaFinanzas extends StatefulWidget {
  const VistaFinanzas({super.key});

  @override
  State<VistaFinanzas> createState() => _VistaFinanzasState();
}

class _VistaFinanzasState extends State<VistaFinanzas> {
  int pestana = 0;
  DateTime mes = DateTime(hoy().year, hoy().month);

  TipoDocumento get _tipo => pestana == 0 ? TipoDocumento.proforma : TipoDocumento.presupuesto;

  bool _delMes(Documento d) => d.fecha.year == mes.year && d.fecha.month == mes.month;

  void _aviso(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text(texto)));

  /// Crea las proformas de los trabajos con precio hechos en el mes que aún no se han cobrado.
  Future<void> _facturarLoHecho() async {
    final nuevas = finanzas.porFacturar(mes);
    if (nuevas.isEmpty) return _aviso('No hay trabajos con precio hechos en ${mesYAno(mes)} sin facturar.');
    final total = nuevas.fold(0.0, (s, d) => s + d.total);
    final una = nuevas.length == 1;
    final ok = await confirmar(
      context,
      'Se ${una ? 'creará 1 factura proforma' : 'crearán ${nuevas.length} facturas proforma'} con los trabajos '
      'hechos en ${mesYAno(mes)} (total ${euros(total)}).',
      accion: una ? 'Crear 1 factura' : 'Crear ${nuevas.length} facturas',
      icono: Icons.receipt_long_outlined,
      destructivo: false,
      nota: 'Podrás revisarlas y borrarlas después.',
    );
    if (!ok) return;
    try {
      for (final d in nuevas) {
        await finanzas.guardar(d);
      }
      _aviso('${nuevas.length} ${nuevas.length == 1 ? 'factura creada' : 'facturas creadas'}');
    } catch (e) {
      debugPrint('Pulpo: no se pudieron crear las facturas: $e');
      _aviso('No se pudieron crear todas las facturas. Inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([finanzas, store]),
    builder: (context, _) {
      final todos = finanzas.documentos;
      final lista = [
        for (final d in todos ?? const <Documento>[])
          if (d.tipo == _tipo && (pestana == 1 || _delMes(d))) d,
      ];
      return Padding(
        padding: margenPagina,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BarraVista(
              izquierda: [
                const TituloVista('Finanzas'),
                Pestanas(
                  opciones: const ['Facturas', 'Presupuestos'],
                  seleccion: pestana,
                  onChanged: (i) => setState(() => pestana = i),
                ),
              ],
              derecha: [
                if (pestana == 0)
                  BotonAccion(
                    'Facturar lo hecho',
                    icono: Icons.playlist_add_check_rounded,
                    tooltip: 'Crea las proformas de los trabajos con precio hechos en el mes',
                    onPressed: _facturarLoHecho,
                  ),
                BotonAccion(
                  'Exportar CSV',
                  icono: Icons.download_rounded,
                  tooltip: 'Para la gestoría',
                  onPressed: () => descargarCsv(lista, mes),
                ),
              ],
              principal: BotonPrimario(
                pestana == 0 ? 'Nueva factura' : 'Nuevo presupuesto',
                tecla: 'N',
                onPressed: () => abrirDocumento(context, Documento(tipo: _tipo, vence: _vencePorDefecto(_tipo))),
              ),
            ),
            const SizedBox(height: huecoVista),
            if (pestana == 0) ...[
              _Resumen(mes, finanzas.resumen(mes), (m) => setState(() => mes = m)),
              const SizedBox(height: huecoVista),
            ],
            Expanded(
              child: todos == null
                  ? const Center(child: CircularProgressIndicator())
                  : lista.isEmpty
                  ? Vacio(
                      icono: Icons.receipt_long_outlined,
                      titulo: pestana == 0 ? 'Sin facturas en ${mesYAno(mes)}' : 'Aún no hay presupuestos',
                      texto: pestana == 0
                          ? 'Crea una a mano o con «Facturar lo hecho» a partir de los trabajos con precio.'
                          : 'Prepara un presupuesto para un cliente y pásalo a factura cuando lo acepte.',
                      accion: FilledButton(
                        onPressed: () =>
                            abrirDocumento(context, Documento(tipo: _tipo, vence: _vencePorDefecto(_tipo))),
                        child: Text(pestana == 0 ? 'Crear la primera' : 'Crear el primero'),
                      ),
                    )
                  : _TablaDocumentos(lista),
            ),
          ],
        ),
      );
    },
  );
}

DateTime? _vencePorDefecto(TipoDocumento t) => t == TipoDocumento.proforma ? masDias(hoy(), 30) : null;

/// Lo facturado, cobrado y pendiente del mes, con el mes a elegir.
class _Resumen extends StatelessWidget {
  final DateTime mes;
  final ResumenMes r;
  final ValueChanged<DateTime> cambiar;
  const _Resumen(this.mes, this.r, this.cambiar);

  @override
  Widget build(BuildContext context) => Tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${mesYAno(mes)[0].toUpperCase()}${mesYAno(mes).substring(1)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            NavegadorFecha(
              anterior: 'Mes anterior',
              siguiente: 'Mes siguiente',
              onAnterior: () => cambiar(DateTime(mes.year, mes.month - 1)),
              onHoy: () => cambiar(DateTime(hoy().year, hoy().month)),
              onSiguiente: () => cambiar(DateTime(mes.year, mes.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Importe('Facturado', r.facturado)),
            Expanded(
              child: _Importe(
                'Pendiente',
                r.pendiente,
                punto: P.ambar,
                ayuda: 'Lo que falta por cobrar, de todos los meses',
              ),
            ),
            Expanded(child: _Importe('Cobrado', r.cobrado, punto: P.verde)),
          ],
        ),
      ],
    ),
  );
}

class _Importe extends StatelessWidget {
  final String etiqueta;
  final double valor;
  final Color? punto;
  final String? ayuda;
  const _Importe(this.etiqueta, this.valor, {this.punto, this.ayuda});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: ayuda ?? '',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (punto != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: P.textoSuave),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            euros(valor),
            style: TextStyle(fontFamily: P.titulos, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.6),
          ),
        ),
      ],
    ),
  );
}

class _TablaDocumentos extends StatelessWidget {
  final List<Documento> docs;
  const _TablaDocumentos(this.docs);

  @override
  Widget build(BuildContext context) => SegunTamano(
    clave: (box) => box.maxWidth > 600,
    builder: (context, box) {
      final medio = box.maxWidth > 600;
      return Align(
        alignment: Alignment.topCenter,
        child: Tabla(
          columnas: [
            if (medio) const Col('Número', ancho: 120),
            const Col('Cliente', flex: 4),
            if (medio) const Col('Fecha', flex: 2),
            const Col('Total', flex: 2, derecha: true),
            const Col('Estado', ancho: 104, derecha: true),
          ],
          filas: docs.length,
          onTap: (i) => abrirDocumento(context, docs[i]),
          pie: pieTabla(docs.length, docs.length == 1 ? 'documento' : 'documentos'),
          celdas: (i) {
            final d = docs[i];
            return [
              if (medio) celdaTexto(d.codigo, negrita: true),
              celdaTexto(store.cliente(d.clienteId)?.nombre ?? 'Sin cliente', negrita: !medio),
              if (medio) celdaTexto(fecha(d.fecha), suave: true),
              Align(alignment: Alignment.centerRight, child: celdaTexto(euros(d.total))),
              Align(alignment: Alignment.centerRight, child: Pill(d.estado.etiqueta, d.estado.color, punto: true)),
            ];
          },
        ),
      );
    },
  );
}

/// Abre el presupuesto o la proforma para editarlo (una copia: no cambia nada hasta guardar).
Future<void> abrirDocumento(BuildContext context, Documento d) => abrirPanel(context, DocumentoForm(d));

/// Formulario de un presupuesto o una factura proforma: cliente, fechas, líneas, cobro y PDF.
class DocumentoForm extends StatefulWidget {
  final Documento original;
  const DocumentoForm(this.original, {super.key});

  @override
  State<DocumentoForm> createState() => _DocumentoFormState();
}

class _FilaLinea {
  final concepto = TextEditingController(), cantidad = TextEditingController(), precio = TextEditingController();
  double iva;
  final String? trabajoId;
  final DateTime? dia;
  _FilaLinea(Linea l) : iva = l.iva, trabajoId = l.trabajoId, dia = l.dia {
    concepto.text = l.concepto;
    cantidad.text = _texto(l.cantidad);
    precio.text = l.precio == 0 ? '' : _texto(l.precio);
  }

  Linea get linea => Linea(
    concepto: concepto.text.trim(),
    cantidad: _numero(cantidad.text) ?? 0,
    precio: _numero(precio.text) ?? 0,
    iva: iva,
    trabajoId: trabajoId,
    dia: dia,
  );

  void dispose() {
    for (final c in [concepto, cantidad, precio]) {
      c.dispose();
    }
  }
}

/// Número escrito con coma o punto decimal (null = no es un número).
double? _numero(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
String _texto(double v) => (v == v.roundToDouble() ? v.toInt().toString() : v.toString()).replaceAll('.', ',');

const _ivas = [21.0, 10.0, 4.0, 0.0];

class _DocumentoFormState extends State<DocumentoForm> {
  late final d = widget.original.copia();
  late final filas = [for (final l in d.lineas) _FilaLinea(l)];
  late final notas = TextEditingController(text: d.notas);
  bool intentado = false, guardando = false;

  @override
  void initState() {
    super.initState();
    if (filas.isEmpty) filas.add(_FilaLinea(Linea()));
  }

  @override
  void dispose() {
    for (final f in filas) {
      f.dispose();
    }
    notas.dispose();
    super.dispose();
  }

  List<Linea> get _lineas => [
    for (final f in filas)
      if (f.concepto.text.trim().isNotEmpty) f.linea,
  ];

  bool get _sinCliente => d.clienteId == null;
  bool get _sinLineas => _lineas.isEmpty;

  void _aviso(ScaffoldMessengerState m, String texto) =>
      m.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, width: 360, content: Text(texto)));

  Future<void> _guardar() async {
    if (guardando) return;
    if (_sinCliente || _sinLineas) return setState(() => intentado = true);
    setState(() => guardando = true);
    final m = ScaffoldMessenger.of(context);
    d
      ..lineas = _lineas
      ..notas = notas.text.trim();
    try {
      await finanzas.guardar(d);
    } catch (e) {
      debugPrint('Pulpo: no se pudo guardar el documento: $e');
      if (mounted) setState(() => guardando = false);
      return _aviso(m, 'No se pudo guardar. Inténtalo de nuevo.');
    }
    if (mounted) Navigator.pop(context);
    _aviso(m, '${d.tipo.etiqueta} ${d.codigo} guardada');
  }

  Future<void> _borrar() async {
    final m = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final que = d.tipo == TipoDocumento.proforma ? 'factura' : 'presupuesto';
    if (!await confirmar(
      context,
      '¿Eliminar ${que == 'factura' ? 'la factura' : 'el presupuesto'} ${d.codigo}?',
      accion: 'Eliminar $que',
    )) {
      return;
    }
    try {
      await finanzas.borrar(widget.original);
      nav.pop();
    } catch (e) {
      debugPrint('Pulpo: no se pudo borrar el documento: $e');
      _aviso(m, 'No se pudo borrar.');
    }
  }

  /// El presupuesto aceptado pasa a una factura proforma nueva con las mismas líneas.
  void _aFactura() {
    final f = Documento(
      clienteId: d.clienteId,
      vence: _vencePorDefecto(TipoDocumento.proforma),
      lineas: _lineas,
      notas: d.codigo == 'Nueva' ? notas.text.trim() : 'Según presupuesto ${d.codigo}',
    );
    Navigator.pop(context);
    abrirDocumento(context, f);
  }

  Widget _fila(int i) {
    final f = filas[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: f.concepto,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Concepto (p. ej. revisión trimestral)'),
                ),
              ),
              if (filas.length > 1)
                IconButton(
                  tooltip: 'Quitar línea',
                  onPressed: () => setState(() => filas.removeAt(i).dispose()),
                  icon: Icon(Icons.close_rounded, size: 18, color: P.textoSuave),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: f.cantidad,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Cant.'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: f.precio,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Precio', suffixText: '€'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Tooltip(
                  message: 'IVA de la línea',
                  child: DropdownButtonFormField<double>(
                    isExpanded: true,
                    initialValue: f.iva,
                    items: [
                      for (final v in {..._ivas, f.iva}) DropdownMenuItem(value: v, child: Text('${_texto(v)} %')),
                    ],
                    onChanged: (v) => setState(() => f.iva = v!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cliente = store.cliente(d.clienteId);
    final lineas = _lineas;
    final base = lineas.fold(0.0, (s, l) => s + l.base), cuota = lineas.fold(0.0, (s, l) => s + l.cuota);
    final proforma = d.tipo == TipoDocumento.proforma;
    return VentanaFormulario(
      etiqueta: d.tipo.etiqueta.toUpperCase(),
      titulo: d.codigo == 'Nueva' ? (proforma ? 'Nueva factura' : 'Nuevo presupuesto') : d.codigo,
      subtitulo: cliente?.nombre,
      onGuardar: _guardar,
      onBorrar: d.id == null ? null : _borrar,
      avisos: [
        if (intentado && _sinCliente) ('Elige el cliente', () {}),
        if (intentado && _sinLineas) ('Añade al menos una línea', () {}),
      ],
      campos: [
        Bloque('Cliente', primero: true, descripcion: 'A quién va.', [
          conMargen(SelectorCliente(d.clienteId, (id) => setState(() => d.clienteId = id))),
          if (intentado && _sinCliente) Text('Elige el cliente', style: TextStyle(color: P.rojo, fontSize: 12.5)),
        ]),
        Bloque(
          'Fechas',
          descripcion: proforma ? 'Cuándo se emite y hasta cuándo hay para pagarla.' : 'Cuándo se emite.',
          [
            dos(
              CampoFecha('Fecha', d.fecha, (f) => setState(() => d.fecha = f)),
              proforma ? CampoFecha('Vence', d.vence, (f) => setState(() => d.vence = f)) : const SizedBox(),
            ),
          ],
        ),
        Bloque('Líneas', descripcion: 'Qué se cobra: concepto, cantidad, precio sin IVA y su IVA.', [
          for (var i = 0; i < filas.length; i++) _fila(i),
          Align(
            alignment: Alignment.centerLeft,
            child: BotonAccion(
              'Añadir línea',
              icono: Icons.add_rounded,
              onPressed: () => setState(() => filas.add(_FilaLinea(Linea()))),
            ),
          ),
          if (intentado && _sinLineas)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Añade al menos una línea con concepto', style: TextStyle(color: P.rojo, fontSize: 12.5)),
            ),
          const SizedBox(height: 14),
          for (final (e, v, fuerte) in [('Base', base, false), ('IVA', cuota, false), ('Total', base + cuota, true)])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e, style: TextStyle(color: fuerte ? P.texto : P.textoSuave)),
                  ),
                  Text(
                    euros(v),
                    style: TextStyle(
                      fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500,
                      fontSize: fuerte ? 16 : 14,
                    ),
                  ),
                ],
              ),
            ),
        ]),
        if (proforma)
          Bloque('Cobro', descripcion: 'Márcala cobrada cuando llegue el pago.', [
            Pestanas(
              opciones: const ['Pendiente', 'Cobrada'],
              seleccion: d.cobradaEl == null ? 0 : 1,
              onChanged: (i) => setState(() => d.cobradaEl = i == 1 ? (d.cobradaEl ?? hoy()) : null),
            ),
            if (d.cobradaEl != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: CampoFecha('Cobrada el', d.cobradaEl, (f) => setState(() => d.cobradaEl = f), hasta: hoy()),
              ),
          ]),
        Bloque('Notas y documento', descripcion: 'Lo que quieras que ponga abajo, y el PDF para mandarlo.', [
          campo('Notas', notas, lineas: 2, hint: 'Ej.: Pago por transferencia a ES00 0000 0000 0000'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BotonAccion(
                'Descargar PDF',
                icono: Icons.download_rounded,
                onPressed: () => descargarDocumentoPdf(
                  d.copia()
                    ..lineas = lineas
                    ..notas = notas.text.trim(),
                ),
              ),
              if (!proforma) BotonAccion('Pasar a factura', icono: Icons.receipt_long_outlined, onPressed: _aFactura),
            ],
          ),
        ]),
      ],
    );
  }
}
