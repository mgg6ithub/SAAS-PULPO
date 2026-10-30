import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'plan.dart';
import 'tipo_mantenimiento.dart';

/// Fila de un mantenimiento periódico en la ficha del activo; «Crear OT» abre la OT ya rellena para revisarla.
Widget filaPlan(BuildContext context, PlanMantenimiento p) => FilaLista(
  lider: Tooltip(message: p.tipo.etiqueta, child: puntoTipo(p.tipo.color)),
  titulo: p.nombre.isEmpty ? 'Sin nombre' : p.nombre,
  subtitulo: [
    p.cada,
    p.categoria,
    if (p.proximo != null) 'Próximo ${fecha(p.proximo!)}',
  ].where((x) => x.isNotEmpty).join(' · '),
  derecha: Enlace('Crear OT', onTap: () => abrirTareaForm(context, null, borrador: p.ot(store.nuevoId()))),
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
  late final repuestos = TextEditingController(text: p.repuestos);
  late final procedimiento = TextEditingController(text: p.procedimiento);
  bool intentoGuardar = false;

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
      intentoGuardar && _entero(dias) == null && _entero(horasC) == null ? 'Cada cuántos días u horas' : null;

  void guardar() {
    setState(() => intentoGuardar = true);
    if (errorNombre != null || errorCada != null) return;
    p
      ..nombre = nombre.text.trim()
      ..cadaDias = _entero(dias)
      ..cadaHoras = _entero(horasC)
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
        ]),
        Bloque('Cada cuánto', descripcion: 'Por días, por horas de uso o por lo que llegue antes.', [
          dos(
            campo('Cada (días)', dias, hint: '90', error: errorCada, obligatorio: true),
            campo('Cada (horas de uso)', horasC, hint: '500', obligatorio: true),
          ),
          const SizedBox(height: 16),
          dos(
            CampoFecha('Último hecho', p.ultimo, (d) {
              p.ultimo = d;
              _alCambiarDias();
            }, hasta: hoy()),
            CampoFecha('Próximo', p.proximo, (d) => setState(() => p.proximo = d)),
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
