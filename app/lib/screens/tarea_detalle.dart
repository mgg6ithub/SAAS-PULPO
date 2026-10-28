import 'package:flutter/material.dart';

import '../forms.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ficha de un trabajo con pestañas, como la de un cliente: Resumen (cifras y equipo) y Datos.
class TareaDetalle extends StatefulWidget {
  final String tareaId;
  final VoidCallback onVolver;
  const TareaDetalle({super.key, required this.tareaId, required this.onVolver});

  @override
  State<TareaDetalle> createState() => _TareaDetalleState();
}

class _TareaDetalleState extends State<TareaDetalle> {
  int pestana = 0;

  @override
  Widget build(BuildContext context) {
    final t = store.tareas.where((x) => x.id == widget.tareaId).firstOrNull;
    if (t == null) {
      // Se acaba de borrar: volvemos a la lista.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVolver());
      return const SizedBox();
    }
    final cliente = store.cliente(t.clienteId);

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
                  tooltip: 'Volver a Trabajos',
                  onPressed: widget.onVolver,
                  icon: Icon(Icons.arrow_back_rounded, size: 20, color: P.textoSuave),
                ),
                const SizedBox(width: 4),
                BarraTipo(t.tipo, alto: 40, color: t.colorBloque),
              ],
            ),
            titulo: t.nombre.isEmpty ? 'Sin nombre' : t.nombre,
            subtitulo: [t.tipo, cliente?.nombre ?? (t.esPlantilla ? 'Plantilla' : 'Sin cliente')].join(' · '),
            acciones: [
              pillEstado(t),
              const SizedBox(width: 4),
              BotonPrimario('Editar', onPressed: () => abrirTareaForm(context, t)),
            ],
          ),
          const SizedBox(height: 18),
          PestanasOscuras(
            opciones: const ['Resumen', 'Datos'],
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
                child: pestana == 0
                    ? _Resumen(t)
                    : SingleChildScrollView(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: _Datos(t)),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final Tarea t;
  const _Resumen(this.t);

  Widget _cifra(String etiqueta, String valor, String nota) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(etiqueta, style: TextStyle(fontSize: 12.5, color: P.textoSuave)),
      const SizedBox(height: 4),
      Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8)),
      Text(
        nota,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: P.textoSuave),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final equipo = [for (final id in t.trabajadorIds) ?store.trabajador(id)];
    final principal = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tarjeta(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Wrap(
            spacing: 48,
            runSpacing: 16,
            children: [
              _cifra(
                'Próximo',
                t.proximo == null ? '—' : relativo(t.proximo!),
                t.proximo == null ? 'sin fecha' : fecha(t.proximo),
              ),
              _cifra(
                'Último',
                t.ultimo == null ? '—' : relativo(t.ultimo!),
                t.ultimo == null ? 'sin registros' : fecha(t.ultimo),
              ),
              _cifra('Periodicidad', t.periodicidad.etiqueta, t.horario ?? 'sin hora'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SeccionTarjeta(
          titulo: 'Asignado a',
          children: equipo.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text('Nadie asignado todavía.', style: TextStyle(color: P.textoSuave, fontSize: 13)),
                  ),
                ]
              : [
                  for (final w in equipo)
                    FilaLista(
                      lider: Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 32),
                      titulo: w.nombreCompleto,
                      subtitulo: w.estadoHoy.etiqueta,
                    ),
                ],
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth <= 900) {
          return ListView(children: [principal, const SizedBox(height: 16), _Datos(t)]);
        }
        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: principal),
              const SizedBox(width: 16),
              SizedBox(width: 340, child: _Datos(t)),
            ],
          ),
        );
      },
    );
  }
}

/// Datos del trabajo en filas etiqueta-valor, como los del cliente.
class _Datos extends StatelessWidget {
  final Tarea t;
  const _Datos(this.t);

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
      titulo: 'Datos del trabajo',
      accion: Enlace('Editar', onTap: () => abrirTareaForm(context, t)),
      children: [
        dato('Cliente', store.cliente(t.clienteId)?.nombre ?? ''),
        dato('Ubicación', t.ubicacion),
        dato('Duración', '${t.duracionMin} min'),
        dato('Criticidad', t.criticidad.etiqueta),
        dato('Máquina', t.estadoMaquina.etiqueta),
        dato('Marca', t.marca),
        dato('Modelo', t.modelo),
        dato('Nº de serie', t.numeroSerie),
        dato('Instalación', t.instalacion == null ? '' : fecha(t.instalacion)),
        dato('Competencias', t.competencias.join(', ')),
        if (t.notas.isNotEmpty) dato('Notas', t.notas),
      ],
    );
  }
}
