import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../marca.dart';

Future<void> abrirSimulaciones(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _Simulaciones());

class _Simulaciones extends StatefulWidget {
  const _Simulaciones();

  @override
  State<_Simulaciones> createState() => _SimulacionesState();
}

class _SimulacionesState extends State<_Simulaciones> {
  final _form = GlobalKey<FormState>();
  static final _nombres = [m('Trabajadores'), m('Clientes'), m('Trabajos')];
  static const _minimos = [0, 0, 0];
  static const _maximos = [100, 200, 1000];
  final _valores = [6, 8, 40];
  final _campos = [
    TextEditingController(text: '6'),
    TextEditingController(text: '8'),
    TextEditingController(text: '40'),
  ];
  final _simultaneos = TextEditingController(text: '2');
  int _modoFecha = 0; // hoy, un día, intervalo
  DateTime _desde = hoy(), _hasta = hoy();
  bool _solapar = false;
  bool _conSubtrabajos = false;
  double _cadaSubtrabajos = 3;
  String? _resultado;

  @override
  void dispose() {
    for (final campo in _campos) {
      campo.dispose();
    }
    _simultaneos.dispose();
    super.dispose();
  }

  Widget _cantidad(int i, double ancho) => SizedBox(
    width: ancho,
    child: Tarjeta(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _nombres[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 58,
                child: TextFormField(
                  controller: _campos[i],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  onChanged: (texto) {
                    final n = int.tryParse(texto);
                    if (n != null) setState(() => _valores[i] = n.clamp(_minimos[i], _maximos[i]));
                  },
                  validator: (texto) {
                    final n = int.tryParse(texto ?? '');
                    return n == null || n < _minimos[i] || n > _maximos[i] ? '${_minimos[i]}–${_maximos[i]}' : null;
                  },
                ),
              ),
            ],
          ),
          Slider(
            value: _valores[i].toDouble(),
            min: _minimos[i].toDouble(),
            max: _maximos[i].toDouble(),
            divisions: _maximos[i] - _minimos[i],
            label: '${_valores[i]}',
            semanticFormatterCallback: (valor) => '${valor.round()} ${_nombres[i].toLowerCase()}',
            onChanged: (valor) => setState(() {
              _valores[i] = valor.round();
              _campos[i].text = '${_valores[i]}';
            }),
          ),
          Text('De ${_minimos[i]} a ${_maximos[i]}', style: TextStyle(color: P.textoSuave, fontSize: 11.5)),
        ],
      ),
    ),
  );

  Future<void> _elegirFecha({required bool inicio}) async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: inicio ? _desde : _hasta,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (seleccionada == null || !mounted) return;
    setState(() {
      if (_modoFecha == 1) {
        _desde = _hasta = seleccionada;
      } else if (inicio) {
        _desde = seleccionada;
        if (_desde.isAfter(_hasta)) _hasta = _desde;
      } else {
        _hasta = seleccionada;
        if (_hasta.isBefore(_desde)) _desde = _hasta;
      }
    });
  }

  void _cambiarModoFecha(int modo) => setState(() {
    _modoFecha = modo;
    if (modo == 0) _desde = _hasta = hoy();
    if (modo == 1) _hasta = _desde;
  });

  Widget _botonFecha(String titulo, DateTime valor, {required bool inicio}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titulo, style: TextStyle(fontSize: 12, color: P.textoSuave)),
      const SizedBox(height: 4),
      SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          onPressed: () => _elegirFecha(inicio: inicio),
          icon: const Icon(Icons.calendar_today_rounded, size: 16),
          label: Text(fecha(valor)),
        ),
      ),
    ],
  );

  void _mostrarResultado(String mensaje) => setState(() => _resultado = mensaje);

  /// En la nube, una simulación sustituye lo que haya: se pregunta antes si hay datos reales.
  Future<bool> _puedeSustituir() async =>
      store.nube == null ||
      store.demo ||
      !store.tieneDatos ||
      await confirmar(
        context,
        'Esto sustituye los datos de tu empresa en la base de datos. ¿Continuar?',
        accion: 'Sustituir datos',
        icono: Icons.swap_horiz_rounded,
      );

  Future<void> _vaciarNube() async {
    if (!await confirmar(
      context,
      m('¿Borrar de la base de datos todos los clientes, trabajadores, trabajos y plantillas? Las cuentas se quedan.'),
      accion: 'Vaciar base',
    ))
      return;
    await store.vaciarNube();
    if (mounted) _mostrarResultado('Base de datos limpia.');
  }

  Future<void> _crearSimulacion() async {
    if (!_form.currentState!.validate()) {
      _mostrarResultado(m('Revisa las cantidades y los trabajos simultáneos.'));
      return;
    }
    if (!await _puedeSustituir()) return;
    final valores = _campos.map((c) => int.parse(c.text)).toList();
    final desde = _modoFecha == 0 ? hoy() : _desde;
    final hasta = _modoFecha == 2 ? _hasta : desde;
    store.cargarSimulacion(
      equipo: valores[0],
      cuentas: valores[1],
      cantidadTareas: valores[2],
      desde: desde,
      hasta: hasta,
      permitirSolapes: _solapar,
      trabajosSimultaneos: _solapar ? int.parse(_simultaneos.text) : 2,
      conSubtrabajos: _conSubtrabajos,
      cadaTantosConSubtrabajos: _cadaSubtrabajos.round(),
    );
    setState(() => _resultado = null);
  }

  Widget _estadoSimulacion() {
    final activa = store.demo;
    final trabajos = store.tareas.where((t) => !t.esPlantilla).length;
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: activa ? Color.lerp(P.superficie, P.verde, .07) : null,
      child: Row(
        children: [
          Icon(
            activa ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: activa ? P.verde : P.textoSuave,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activa ? 'Simulación activa' : 'Sin simulación activa',
                  style: TextStyle(fontWeight: FontWeight.w700, color: activa ? P.verde : P.texto),
                ),
                Text(
                  activa
                      ? m('${store.trabajadores.length} trabajadores · ${store.clientes.length} clientes · $trabajos trabajos${store.subtareas.isEmpty ? '' : ' · ${store.subtareas.length} subtrabajos'}')
                      : 'Crea una simulación para cargar datos de prueba.',
                  style: TextStyle(fontSize: 12, color: P.textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: P.fondo,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 820),
      child: SingleChildScrollView(
        padding: margenPagina,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DESARROLLO',
                          style: TextStyle(
                            color: P.morado,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                          ),
                        ),
                        Text(
                          'Simulaciones',
                          style: TextStyle(fontFamily: P.titulos, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: huecoVista),
              Bloque('Automática', [
                BotonAccion(
                  'Generar datos por defecto',
                  icono: Icons.auto_awesome_outlined,
                  onPressed: () async {
                    if (!await _puedeSustituir()) return;
                    store.cargarDemo(soloProximosDosDias: true);
                    _mostrarResultado('Datos de ejemplo cargados.');
                  },
                ),
              ], primero: true),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'A tu medida · volumen',
                      style: TextStyle(fontFamily: P.titulos, fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, box) {
                        final columnas = box.maxWidth >= 600
                            ? 3
                            : box.maxWidth >= 380
                            ? 2
                            : 1;
                        final ancho = (box.maxWidth - (columnas - 1) * 8) / columnas;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (var i = 0; i < _campos.length; i++) _cantidad(i, ancho)],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Tarjeta(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      m('Cuándo generar los trabajos'),
                      style: TextStyle(fontFamily: P.titulos, fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Pestanas(
                        opciones: const ['Hoy', 'Un día', 'Intervalo'],
                        seleccion: _modoFecha,
                        onChanged: _cambiarModoFecha,
                      ),
                    ),
                    if (_modoFecha != 0) ...[
                      const SizedBox(height: 10),
                      if (_modoFecha == 1)
                        _botonFecha('Día', _desde, inicio: true)
                      else
                        Row(
                          children: [
                            Expanded(child: _botonFecha('Desde', _desde, inicio: true)),
                            const SizedBox(width: 10),
                            Expanded(child: _botonFecha('Hasta', _hasta, inicio: false)),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Tarjeta(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Checkbox(value: _solapar, onChanged: (valor) => setState(() => _solapar = valor ?? false)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m('Crear trabajos que se solapan'), style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'Mismo día y misma hora para revisar el calendario.',
                            style: TextStyle(fontSize: 12, color: P.textoSuave),
                          ),
                        ],
                      ),
                    ),
                    if (_solapar) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 76,
                        child: TextFormField(
                          controller: _simultaneos,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(isDense: true, labelText: 'A la vez'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (texto) {
                            final n = int.tryParse(texto ?? '');
                            return n == null || n < 2 || n > 20 ? '2–20' : null;
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Tarjeta(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Switch(value: _conSubtrabajos, onChanged: (v) => setState(() => _conSubtrabajos = v)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Crear subtrabajos', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                m('Algunos trabajos se dividen en varios subtrabajos.'),
                                style: TextStyle(fontSize: 12, color: P.textoSuave),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_conSubtrabajos)
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _cadaSubtrabajos,
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: '${_cadaSubtrabajos.round()}',
                              semanticFormatterCallback: (v) => m('Uno de cada ${v.round()} trabajos'),
                              onChanged: (v) => setState(() => _cadaSubtrabajos = v),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Text(
                              _cadaSubtrabajos.round() == 1
                                  ? m('Todos los trabajos')
                                  : m('Uno de cada ${_cadaSubtrabajos.round()} trabajos'),
                              style: TextStyle(fontSize: 12.5, color: P.textoSuave),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (store.nube != null)
                    BotonAccion(
                      'Borrar datos de la base de datos',
                      icono: Icons.delete_outline_rounded,
                      onPressed: _vaciarNube,
                    )
                  else if (store.demo)
                    BotonAccion(
                      'Quitar datos',
                      icono: Icons.delete_outline_rounded,
                      onPressed: () async {
                        await store.quitarDemo();
                        if (mounted) _mostrarResultado('Datos anteriores restaurados.');
                      },
                    ),
                  BotonPrimario('Crear simulación', icono: Icons.auto_awesome_outlined, onPressed: _crearSimulacion),
                ],
              ),
              const SizedBox(height: 8),
              _estadoSimulacion(),
              if (_resultado != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_resultado!, style: TextStyle(color: P.texto)),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Cada simulación sustituye a la anterior. Al quitar los datos de ejemplo se recuperan tus datos originales.',
                style: TextStyle(color: P.textoSuave, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
