import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../forms.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> abrirSimulaciones(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _Simulaciones());

class _Simulaciones extends StatefulWidget {
  const _Simulaciones();

  @override
  State<_Simulaciones> createState() => _SimulacionesState();
}

class _SimulacionesState extends State<_Simulaciones> {
  final _form = GlobalKey<FormState>();
  static const _nombres = ['Trabajadores', 'Clientes', 'Trabajos', 'Días a simular'];
  static const _minimos = [0, 1, 0, 1];
  static const _maximos = [100, 200, 1000, 90];
  final _valores = [6, 8, 40, 30];
  final _campos = [
    TextEditingController(text: '6'),
    TextEditingController(text: '8'),
    TextEditingController(text: '40'),
    TextEditingController(text: '30'),
  ];
  String? _resultado;

  @override
  void dispose() {
    for (final campo in _campos) {
      campo.dispose();
    }
    super.dispose();
  }

  void _generar(VoidCallback accion) {
    accion();
    setState(() {
      final tareas = store.tareas.where((t) => !t.esPlantilla).length;
      _resultado =
          'Simulación activa: ${store.trabajadores.length} trabajadores · '
          '${store.clientes.length} clientes · $tareas trabajos';
    });
  }

  Widget _cantidad(int i) => Padding(
    padding: const EdgeInsets.only(bottom: huecoVista),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_nombres[i], style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              width: 90,
              child: TextFormField(
                controller: _campos[i],
                textAlign: TextAlign.center,
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
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
        Text('De ${_minimos[i]} a ${_maximos[i]}', style: TextStyle(color: P.textoSuave, fontSize: 12)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: P.fondo,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
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
                  onPressed: () => _generar(store.cargarDemo),
                ),
              ], primero: true),
              Bloque('A tu medida', [
                for (var i = 0; i < _campos.length; i++) Semantics(label: _nombres[i], child: _cantidad(i)),
                BotonPrimario(
                  'Crear simulación',
                  onPressed: () {
                    if (!_form.currentState!.validate()) {
                      setState(() => _resultado = 'Revisa las cantidades: deben estar dentro de los rangos indicados.');
                      return;
                    }
                    final valores = _campos.map((c) => int.parse(c.text)).toList();
                    _generar(
                      () => store.cargarSimulacion(
                        equipo: valores[0],
                        cuentas: valores[1],
                        cantidadTareas: valores[2],
                        dias: valores[3],
                      ),
                    );
                  },
                ),
              ]),
              if (_resultado != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: huecoVista),
                    child: Text(_resultado!, style: TextStyle(color: P.texto)),
                  ),
                ),
              if (store.demo)
                BotonAccion(
                  'Quitar datos de ejemplo',
                  icono: Icons.undo_rounded,
                  onPressed: () async {
                    await store.quitarDemo();
                    if (mounted) setState(() => _resultado = 'Datos anteriores restaurados.');
                  },
                ),
              const SizedBox(height: huecoVista),
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
