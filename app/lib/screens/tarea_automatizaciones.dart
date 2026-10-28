import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Pestaña «Automatizaciones» de un trabajo: reglas que mandan emails cuando pasa algo de ese trabajo.
/// Maqueta: las reglas se guardan, pero el envío es simulado (se ve en «Vista previa»).
class TareaAutomatizaciones extends StatelessWidget {
  final Tarea t;
  const TareaAutomatizaciones(this.t, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SeccionTarjeta(
      alto: box.maxHeight,
      titulo: 'Automatizaciones',
      subtitulo: t.automatizaciones.isEmpty ? null : '${t.automatizaciones.length} por email',
      children: [
        if (t.automatizaciones.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Aún no hay ninguna. Crea una para avisar por email, por ejemplo, a los trabajadores un día antes.',
              style: TextStyle(color: P.textoSuave, fontSize: 13),
            ),
          )
        else
          for (final a in t.automatizaciones)
            FilaLista(
              lider: Switch(
                value: a.activa,
                onChanged: (v) {
                  a.activa = v;
                  store.guardarTarea(t);
                },
              ),
              titulo: a.nombre.isEmpty ? 'Sin nombre' : a.nombre,
              subtitulo: '${_cuando(a)} · ${_para(t, a).length} destinatarios',
              derecha: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () => _vistaPrevia(context, t, a), child: const Text('Vista previa')),
                  IconButton(
                    tooltip: 'Borrar',
                    onPressed: () async {
                      if (!await confirmar(context, '¿Borrar la automatización «${a.nombre}»?')) return;
                      t.automatizaciones.remove(a);
                      store.guardarTarea(t);
                    },
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: P.textoSuave),
                  ),
                ],
              ),
              onTap: () => abrirAutomatizacion(context, t, a),
            ),
      ],
    ),
  );
}

String _margen(Automatizacion a) =>
    '${a.cantidad} ${a.enHoras ? (a.cantidad == 1 ? 'hora' : 'horas') : (a.cantidad == 1 ? 'día' : 'días')}';

/// «1 día antes · 27/10 09:00», o solo el disparador si no depende de la fecha.
String _cuando(Automatizacion a) => switch (a.disparador) {
  Disparador.antes => '${_margen(a)} antes',
  Disparador.noHecho => '${_margen(a)} después sin hacerse',
  Disparador.alCompletar => 'Al completarse',
  Disparador.alAsignar => 'Al asignar',
};

/// Emails de los destinatarios (sin repetir). Los que no tienen email no salen.
List<String> _para(Tarea t, Automatizacion a) {
  final r = <String>{};
  if (a.aTrabajadores) {
    for (final id in t.trabajadorIds) {
      final e = store.trabajador(id)?.email.trim() ?? '';
      if (e.isNotEmpty) r.add(e);
    }
  }
  if (a.aCliente) {
    final e = store.cliente(t.clienteId)?.email.trim() ?? '';
    if (e.isNotEmpty) r.add(e);
  }
  r.addAll(a.extras);
  return r.toList();
}

/// Cuándo se mandaría, si el disparador depende de la fecha del trabajo.
DateTime? _envio(Tarea t, Automatizacion a) {
  if (!a.disparador.llevaMargen || t.proximo == null) return null;
  final base = t.proximo!.add(Duration(minutes: t.inicioMin ?? 9 * 60));
  final m = a.enHoras ? Duration(hours: a.cantidad) : Duration(days: a.cantidad);
  return a.disparador == Disparador.antes ? base.subtract(m) : base.add(m);
}

String _rellenar(String texto, Tarea t) {
  final trabajadores = [for (final id in t.trabajadorIds) ?store.trabajador(id)?.nombreCompleto].join(', ');
  return texto
      .replaceAll('{trabajo}', t.nombre)
      .replaceAll('{cliente}', store.cliente(t.clienteId)?.nombre ?? '')
      .replaceAll('{fecha}', fecha(t.proximo))
      .replaceAll('{trabajadores}', trabajadores);
}

Future<void> _vistaPrevia(BuildContext context, Tarea t, Automatizacion a) {
  final para = _para(t, a);
  final envio = _envio(t, a);
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VISTA PREVIA · ENVÍO SIMULADO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: P.morado),
              ),
              const SizedBox(height: 8),
              Text(
                envio == null
                    ? _cuando(a)
                    : 'Se enviaría el ${fecha(envio)} a las ${hhmm(envio.hour * 60 + envio.minute)}',
                style: TextStyle(color: P.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text(
                'Para: ${para.isEmpty ? 'nadie (faltan emails)' : para.join(', ')}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                _rellenar(a.asunto, t),
                style: TextStyle(fontFamily: P.titulos, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(_rellenar(a.cuerpo, t), style: const TextStyle(fontSize: 13.5, height: 1.45)),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Crear ([original] null) o editar una automatización del trabajo.
Future<void> abrirAutomatizacion(BuildContext context, Tarea t, [Automatizacion? original]) =>
    abrirPanel(context, _AutomatizacionForm(t, original));

class _AutomatizacionForm extends StatefulWidget {
  final Tarea t;
  final Automatizacion? original;
  const _AutomatizacionForm(this.t, this.original);

  @override
  State<_AutomatizacionForm> createState() => _AutomatizacionFormState();
}

class _AutomatizacionFormState extends State<_AutomatizacionForm> {
  late final Automatizacion a = widget.original == null
      ? Automatizacion(
          id: store.nuevoId(),
          asunto: 'Mantenimiento: {trabajo}',
          cuerpo: 'Hola, recordatorio del trabajo «{trabajo}» ({cliente}) previsto para el {fecha}.',
        )
      : Automatizacion.fromJson(widget.original!.toJson());
  late final nombre = TextEditingController(text: a.nombre);
  late final asunto = TextEditingController(text: a.asunto);
  late final cuerpo = TextEditingController(text: a.cuerpo);
  late final cantidad = TextEditingController(text: '${a.cantidad}');
  late final extras = TextEditingController(text: a.extras.join(', '));
  bool intento = false;

  @override
  void dispose() {
    for (final c in [nombre, asunto, cuerpo, cantidad, extras]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    setState(() => intento = true);
    if (nombre.text.trim().isEmpty) return;
    a
      ..nombre = nombre.text.trim()
      ..asunto = asunto.text.trim()
      ..cuerpo = cuerpo.text.trim()
      ..cantidad = (int.tryParse(cantidad.text.trim()) ?? 1).clamp(0, 999)
      ..extras = [
        for (final e in extras.text.split(RegExp(r'[,;\s]+')))
          if (e.contains('@')) e,
      ];
    final lista = widget.t.automatizaciones;
    final i = lista.indexWhere((x) => x.id == a.id);
    i < 0 ? lista.add(a) : lista[i] = a;
    store.guardarTarea(widget.t);
    Navigator.pop(context);
  }

  Widget _check(String texto, bool valor, ValueChanged<bool> onChanged) => CheckboxListTile(
    value: valor,
    onChanged: (v) => setState(() => onChanged(v ?? false)),
    title: Text(texto, style: const TextStyle(fontSize: 13.5)),
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    dense: true,
  );

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'AUTOMATIZACIÓN',
    titulo: widget.original == null ? 'Nueva automatización' : 'Editar automatización',
    subtitulo: widget.t.nombre,
    onGuardar: _guardar,
    avisos: [if (nombre.text.trim().isEmpty) ('Ponle un nombre', () {})],
    campos: [
      Bloque('Nombre', primero: true, descripcion: 'Para reconocerla en la lista.', [
        campo(
          'Nombre',
          nombre,
          hint: 'Aviso a los trabajadores',
          obligatorio: true,
          error: intento && nombre.text.trim().isEmpty ? 'Ponle un nombre' : null,
        ),
      ]),
      Bloque('Cuándo', descripcion: 'Qué tiene que pasar para que se mande el email.', [
        etiqueta('Disparador'),
        BotonMenu<Disparador>(
          tooltip: 'Disparador',
          seleccionado: a.disparador,
          onSelected: (d) => setState(() => a.disparador = d),
          opciones: [for (final d in Disparador.values) (d, Text(d.etiqueta))],
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: P.borde),
            ),
            child: Row(
              children: [
                Text(a.disparador.etiqueta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Icon(Icons.unfold_more_rounded, size: 16, color: P.textoSuave),
              ],
            ),
          ),
        ),
        if (a.disparador.llevaMargen) ...[
          const SizedBox(height: 16),
          etiqueta(a.disparador == Disparador.antes ? 'Cuánto antes' : 'Cuánto después de la fecha'),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(controller: cantidad, keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Pestanas(
                opciones: const ['Días', 'Horas'],
                seleccion: a.enHoras ? 1 : 0,
                onChanged: (i) => setState(() => a.enHoras = i == 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ]),
      Bloque('Para quién', descripcion: 'Pueden ser varios. Los que no tengan email no recibirán nada.', [
        _check('Trabajadores asignados', a.aTrabajadores, (v) => a.aTrabajadores = v),
        _check('El cliente', a.aCliente, (v) => a.aCliente = v),
        const SizedBox(height: 8),
        campo('Otros emails', extras, hint: 'oficina@empresa.com, jefe@empresa.com'),
      ]),
      Bloque('Mensaje', descripcion: 'Puedes usar {trabajo}, {cliente}, {fecha} y {trabajadores}.', [
        campo('Asunto', asunto),
        campo('Texto', cuerpo, lineas: 6),
      ]),
    ],
  );
}
