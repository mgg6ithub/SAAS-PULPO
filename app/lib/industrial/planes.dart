import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'plan.dart';
import 'tipo_mantenimiento.dart';

/// Próximo de un mantenimiento: el puesto a mano o, si va por horas, estimado con el contador y el ritmo de uso
/// de su activo o componente.
DateTime? proximoPlan(PlanMantenimiento p) {
  if (p.proximo != null || p.cadaHoras == null) return p.proximo;
  final a = store.activo(p.activoId);
  if (a == null || a.usoDiario <= 0) return null;
  final quedan = p.cadaHoras! - (a.horas - (p.ultimoHoras ?? 0));
  if (quedan <= 0) return a.fechaLectura;
  final dias = (quedan / a.usoDiario).ceil();
  if (dias > 3652500) return null;
  return masDias(a.fechaLectura, dias);
}

/// Fila de un mantenimiento: lo que hay que hacer. «Asignar a técnico» crea su OT ya rellena para revisarla.
/// Con [conCodigo], el tag del activo o componente al que pertenece.
Widget filaPlan(BuildContext context, PlanMantenimiento p, {bool conCodigo = false}) => FilaLista(
  lider: Tooltip(message: p.tipo.etiqueta, child: puntoTipo(p.tipo.color)),
  titulo: p.nombre.isEmpty ? 'Sin nombre' : p.nombre,
  subtitulo: [
    p.descripcion,
    if (conCodigo) store.activo(p.activoId)?.titulo ?? '',
    p.cada,
    p.categoria,
    if (proximoPlan(p) != null) 'Próximo ${p.proximo == null ? '≈ ' : ''}${fecha(proximoPlan(p)!)}',
  ].where((x) => x.isNotEmpty).join(' · '),
  derecha: Enlace('Asignar a técnico', onTap: () => abrirTareaForm(context, null, borrador: p.ot(store.nuevoId()))),
  onTap: () => abrirPlanForm(context, activoId: p.activoId, original: p),
);

Future<void> abrirPlanForm(BuildContext context, {required String activoId, PlanMantenimiento? original}) =>
    abrirPanel(context, PlanForm(activoId: activoId, original: original));

/// Alta y edición de un mantenimiento periódico de un activo o componente.
class PlanForm extends StatefulWidget {
  final String activoId;
  final PlanMantenimiento? original;
  const PlanForm({super.key, required this.activoId, this.original});

  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  late final PlanMantenimiento p =
      widget.original?.copia() ?? PlanMantenimiento(id: store.nuevoId(), activoId: widget.activoId);
  late final nombre = TextEditingController(text: p.nombre)..addListener(() => setState(() {}));
  late final dias = TextEditingController(text: p.cadaDias?.toString() ?? '')..addListener(_alCambiarDias);
  late final horasC = TextEditingController(text: p.cadaHoras?.toString() ?? '')..addListener(() => setState(() {}));
  late final contador = TextEditingController(text: p.ultimoHoras == null ? '' : '${p.ultimoHoras}');
  late final descripcion = TextEditingController(text: p.descripcion);
  late final repuestos = TextEditingController(text: p.repuestos);
  late final procedimiento = TextEditingController(text: p.procedimiento);
  bool intentoGuardar = false;

  /// Cómo se programa: 0 = cada N días, 1 = cada N horas de uso, 2 = una fecha concreta.
  late int modo = p.cadaHoras != null
      ? 1
      : p.cadaDias == null && p.proximo != null
      ? 2
      : 0;
  static const _modos = ['Días', 'Horas de uso', 'Fecha concreta'];

  int? _entero(TextEditingController c) {
    final n = int.tryParse(c.text.trim());
    return n == null || n <= 0 ? null : n;
  }

  /// Con el último hecho, el próximo sale solo al cambiar cada cuántos días.
  void _alCambiarDias() => setState(() {
    final n = _entero(dias);
    if (p.ultimo != null && n != null) p.proximo = masDias(p.ultimo!, n);
  });

  String? get errorNombre => intentoGuardar && nombre.text.trim().isEmpty ? 'Ponle un nombre' : null;
  String? get errorCada =>
      intentoGuardar &&
          switch (modo) {
            0 => _entero(dias) == null,
            1 => _entero(horasC) == null,
            _ => p.proximo == null,
          }
      ? (modo == 2 ? 'Elige la fecha' : 'Cada cuánto toca')
      : null;

  void guardar() {
    setState(() => intentoGuardar = true);
    if (errorNombre != null || errorCada != null) return;
    p
      ..nombre = nombre.text.trim()
      ..descripcion = descripcion.text.trim()
      ..cadaDias = modo == 0 ? _entero(dias) : null
      ..cadaHoras = modo == 1 ? _entero(horasC) : null
      ..ultimoHoras = double.tryParse(contador.text.trim().replaceAll(',', '.'))
      ..repuestos = repuestos.text.trim()
      ..procedimiento = procedimiento.text.trim();
    store.guardarPlan(p);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existe = widget.original != null;
    return VentanaFormulario(
      etiqueta: store.activo(p.activoId)?.titulo ?? 'Activo',
      titulo: existe ? 'Editar mantenimiento' : 'Nuevo mantenimiento',
      tituloDesplazado: nombre.text,
      bajoBotones: MenuTipoMantenimiento(p.tipo, (t) => setState(() => p.tipo = t)),
      onGuardar: guardar,
      avisos: [
        if (errorNombre != null) ('Te falta el nombre', () {}),
        if (errorCada != null) ('Te falta cada cuánto toca', () {}),
      ],
      onBorrar: !existe
          ? null
          : () async {
              final nav = Navigator.of(context);
              if (await confirmar(context, '¿Eliminar el mantenimiento ${p.nombre}? Sus OT se quedan.')) {
                store.borrarPlan(p.id);
                nav.pop();
              }
            },
      campos: [
        Bloque('Mantenimiento', primero: true, descripcion: 'Qué hay que hacer en este componente.', [
          campo('Nombre', nombre, hint: 'Cambio de aceite', error: errorNombre, obligatorio: true),
          campo('Breve descripción', descripcion, hint: 'Vaciar, cambiar filtro y rellenar'),
        ]),
        Bloque('Cada cuánto', descripcion: 'Por días, por horas de uso o en una fecha. Por horas, sin próximo, se estima con el contador.', [
          dos(
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiqueta('Programar por'),
                  BotonMenu<int>(
                    relleno: EdgeInsets.zero,
                    tooltip: 'Cómo se programa el mantenimiento',
                    seleccionado: modo,
                    opciones: [for (final (i, m) in _modos.indexed) (i, Text(m))],
                    onSelected: (m) => setState(() => modo = m),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        suffixIcon: Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave),
                      ),
                      child: Text(_modos[modo]),
                    ),
                  ),
                ],
              ),
            ),
            switch (modo) {
              0 => campo('Cada cuántos días', dias, hint: '90', error: errorCada, obligatorio: true),
              1 => campo('Cada cuántas horas', horasC, hint: '500', error: errorCada, obligatorio: true),
              _ => CampoFecha('Fecha', p.proximo, (d) => setState(() => p.proximo = d)),
            },
          ),
          const SizedBox(height: 16),
          dos(
            CampoFecha('Último hecho', p.ultimo, (d) {
              p.ultimo = d;
              _alCambiarDias();
            }, hasta: hoy()),
            modo == 2 ? const SizedBox() : CampoFecha('Próximo', p.proximo, (d) => setState(() => p.proximo = d)),
          ),
          dos(
            campo(
              'Contador en el último (h)',
              contador,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              hint: '0',
            ),
            const SizedBox(),
          ),
        ]),
        Bloque('Quién y cuánto', descripcion: 'Solo los técnicos de esta categoría pueden recibir la OT.', [
          dos(
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiqueta('Categoría de técnico'),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: p.categoria,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Cualquiera')),
                      for (final c in {...competencias, if (p.categoria.isNotEmpty) p.categoria})
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (c) => setState(() => p.categoria = c!),
                  ),
                ],
              ),
            ),
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiqueta('Duración'),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: p.duracionMin,
                    items: [
                      for (final m in {...duraciones, p.duracionMin}.toList()..sort())
                        DropdownMenuItem(value: m, child: Text(duracion(m))),
                    ],
                    onChanged: (m) => setState(() => p.duracionMin = m!),
                  ),
                ],
              ),
            ),
          ),
        ]),
        Bloque('Repuestos', descripcion: 'Piezas y consumibles que hacen falta.', [
          campo('Repuestos', repuestos, hint: 'Filtro de aceite, 12 l de aceite 15W40…', lineas: 3),
        ]),
        Bloque('Procedimiento', descripcion: 'Los pasos, para que cualquier técnico lo haga igual.', [
          campo('Procedimiento', procedimiento, lineas: 5),
        ]),
      ],
    );
  }
}
