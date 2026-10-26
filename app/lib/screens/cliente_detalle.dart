import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ficha de un cliente con pestañas (como la ficha de contacto de Holded):
/// Resumen (cifras y próximos), Mantenimientos (tabla) y Datos.
class ClienteDetalle extends StatefulWidget {
  final String clienteId;
  final VoidCallback onVolver;
  const ClienteDetalle({super.key, required this.clienteId, required this.onVolver});

  @override
  State<ClienteDetalle> createState() => _ClienteDetalleState();
}

class _ClienteDetalleState extends State<ClienteDetalle> {
  int pestana = 0;

  @override
  Widget build(BuildContext context) {
    final c = store.cliente(widget.clienteId);
    if (c == null) {
      // Se acaba de borrar: volvemos a la lista.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVolver());
      return const SizedBox();
    }
    final tareas = store.tareasDe(c.id)
      ..sort((a, b) => (a.proximo ?? DateTime(2100)).compareTo(b.proximo ?? DateTime(2100)));

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
                  tooltip: 'Volver a Clientes',
                  onPressed: widget.onVolver,
                  icon: Icon(Icons.arrow_back_rounded, size: 20, color: P.textoSuave),
                ),
                const SizedBox(width: 4),
                Hero(
                  tag: 'cliente-${c.id}',
                  child: Avatar(c.iniciales, colorPaleta(c.color), size: 40, cuadrado: true),
                ),
              ],
            ),
            titulo: c.nombre,
            subtitulo: [c.cif, c.ciudad].where((x) => x.isNotEmpty).join(' · '),
            acciones: [
              c.activa ? const Pill('Activo', P.verde, punto: true) : const Pill('Inactivo', P.gris, punto: true),
              const SizedBox(width: 4),
              OutlinedButton(onPressed: () => abrirClienteForm(context, c), child: const Text('Editar')),
              BotonPrimario('Nuevo trabajo', onPressed: () => abrirTareaForm(context, null, clienteId: c.id)),
            ],
          ),
          const SizedBox(height: 18),
          PestanasOscuras(
            opciones: const ['Resumen', 'Trabajos', 'Datos'],
            contadores: [null, tareas.length, null],
            seleccion: pestana,
            onChanged: (i) => setState(() => pestana = i),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (actual, anteriores) => Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
              child: KeyedSubtree(
                key: ValueKey(pestana),
                child: switch (pestana) {
                  0 => _Resumen(c, tareas, onVerTodo: () => setState(() => pestana = 1)),
                  1 => _Mantenimientos(c, tareas),
                  _ => SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: _Datos(c)),
                    ),
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final Cliente c;
  final List<Tarea> tareas;
  final VoidCallback onVerTodo;
  const _Resumen(this.c, this.tareas, {required this.onVerTodo});

  @override
  Widget build(BuildContext context) {
    final conFecha = tareas.where((t) => t.activa && t.proximo != null).toList();
    final vencidas = conFecha.where((t) => diasHasta(t.proximo!) < 0).length;
    final mes = conFecha.where((t) => diasHasta(t.proximo!) >= 0 && diasHasta(t.proximo!) <= 30).length;
    final hechos = tareas.where((t) => t.ultimo != null).map((t) => t.ultimo!).toList()..sort();
    final proximos = conFecha.take(6).toList();

    return SegunTamano(
      clave: (box) => box.maxWidth > 900,
      builder: (context, box) {
        final dosCol = box.maxWidth > 900;
        final principal = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Tarjeta(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Wrap(
                spacing: 48,
                runSpacing: 16,
                children: [
                  Cifra('Trabajos', tareas.length, nota: '${{for (final t in tareas) t.tipo}.length} tipos'),
                  Cifra(
                    'Vencidos',
                    vencidas,
                    color: vencidas > 0 ? P.rojo : null,
                    nota: vencidas > 0 ? '▼ requieren atención' : '▲ al día',
                    colorNota: vencidas > 0 ? P.rojo : P.verde,
                  ),
                  Cifra('Próximos 30 días', mes, nota: 'programados'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Última visita', style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
                      const SizedBox(height: 4),
                      Text(
                        hechos.isEmpty ? '—' : relativo(hechos.last),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8),
                      ),
                      Text(
                        hechos.isEmpty ? 'sin registros' : fecha(hechos.last),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: P.textoSuave),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SeccionTarjeta(
              titulo: 'Próximos mantenimientos',
              accion: tareas.isEmpty ? null : Enlace('Ver todos', onTap: onVerTodo),
              children: proximos.isEmpty
                  ? [
                      SizedBox(
                        height: 220,
                        child: Vacio(
                          icono: Icons.handyman_outlined,
                          texto: 'Este cliente aún no tiene mantenimientos.\nCréalos desde cero o a partir de una plantilla.',
                          accion: FilledButton(
                            onPressed: () => abrirTareaForm(context, null, clienteId: c.id),
                            child: const Text('Nuevo trabajo'),
                          ),
                        ),
                      ),
                    ]
                  : [
                      for (final t in proximos)
                        FilaLista(
                          lider: BarraTipo(t.tipo, alto: 32, color: t.colorBloque),
                          titulo: t.nombre,
                          subtitulo: [
                            fecha(t.proximo),
                            ?t.horario,
                            if (t.ubicacion.isNotEmpty) t.ubicacion,
                          ].join(' · '),
                          derecha: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AvataresTrabajadores(t.trabajadorIds, size: 24),
                              const SizedBox(width: 12),
                              pillEstado(t),
                            ],
                          ),
                          onTap: () => abrirTareaForm(context, t),
                        ),
                    ],
            ),
          ],
        );
        if (!dosCol) {
          return ListView(children: [principal, const SizedBox(height: 16), _Datos(c)]);
        }
        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: principal),
              const SizedBox(width: 16),
              SizedBox(width: 340, child: _Datos(c)),
            ],
          ),
        );
      },
    );
  }
}

class _Mantenimientos extends StatelessWidget {
  final Cliente c;
  final List<Tarea> tareas;
  const _Mantenimientos(this.c, this.tareas);

  @override
  Widget build(BuildContext context) {
    if (tareas.isEmpty) {
      return Vacio(
        icono: Icons.handyman_outlined,
        titulo: 'Sin mantenimientos',
        texto: 'Crea el primero desde cero o a partir de una plantilla.',
        accion: FilledButton(
          onPressed: () => abrirTareaForm(context, null, clienteId: c.id),
          child: const Text('Nuevo trabajo'),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Tabla(
        columnas: const [
          Col('Equipo / trabajo', flex: 4),
          Col('Periodicidad', flex: 2),
          Col('Último', flex: 2),
          Col('Próximo', flex: 2),
          Col('Asignado a', ancho: 90),
          Col('Estado', ancho: 80, derecha: true),
        ],
        filas: tareas.length,
        onTap: (i) => abrirTareaForm(context, tareas[i]),
        pie: pieTabla(tareas.length, tareas.length == 1 ? 'mantenimiento' : 'mantenimientos'),
        celdas: (i) {
          final t = tareas[i];
          return [
            Row(
              children: [
                BarraTipo(t.tipo, alto: 28, color: t.colorBloque),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      celdaTexto(t.nombre, negrita: true),
                      Text(
                        [t.tipo, if (t.ubicacion.isNotEmpty) t.ubicacion].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: P.textoSuave),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            celdaTexto(t.periodicidad.etiqueta),
            celdaTexto(t.ultimo == null ? '' : fecha(t.ultimo), suave: true),
            celdaTexto(t.proximo == null ? '' : '${fecha(t.proximo)} · ${relativo(t.proximo!)}'),
            AvataresTrabajadores(t.trabajadorIds, size: 24),
            pillEstado(t),
          ];
        },
      ),
    );
  }
}

/// Datos del cliente en filas etiqueta-valor (como el panel "General" de Holded).
class _Datos extends StatelessWidget {
  final Cliente c;
  const _Datos(this.c);

  @override
  Widget build(BuildContext context) {
    Widget dato(String label, String valor) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: P.textoSuave, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              valor.trim().isEmpty ? '—' : valor,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: valor.trim().isEmpty ? P.textoSuave : P.texto),
            ),
          ),
        ],
      ),
    );
    return SeccionTarjeta(
      titulo: 'Datos del cliente',
      accion: Enlace('Editar', onTap: () => abrirClienteForm(context, c)),
      children: [
        dato('Persona de contacto', c.contacto),
        dato('Tel. contacto', c.telefonoContacto),
        dato('Teléfono', c.telefono),
        dato('Email', c.email),
        dato('CIF/NIF', c.cif),
        dato(
          'Dirección',
          [
            c.direccion,
            [c.cp, c.ciudad].where((x) => x.isNotEmpty).join(' '),
            c.provincia,
          ].where((x) => x.isNotEmpty).join(', '),
        ),
        dato('Cliente desde', fecha(c.fechaAlta)),
        if (c.notas.isNotEmpty) dato('Notas', c.notas),
      ],
    );
  }
}
