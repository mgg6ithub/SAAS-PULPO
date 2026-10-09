import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

// ── Ventana de formulario ──
// Por defecto sale en el centro desde abajo (como una hoja de iOS) y se puede
// arrastrar. Con su botón se acopla a la derecha y vuelve a ser ventana.
// El modo elegido se recuerda para la siguiente vez.

bool _acoplada = false;

Future<void> abrirPanel(BuildContext context, Widget panel) => showGeneralDialog(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Cerrar',
  barrierColor: P.texto.withValues(alpha: .25),
  transitionDuration: const Duration(milliseconds: 380),
  pageBuilder: (c, a, b) => panel,
  transitionBuilder: (c, a, b, child) => SlideTransition(
    position: Tween(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
    child: child,
  ),
);

class VentanaFormulario extends StatefulWidget {
  final String titulo;
  final String? subtitulo;

  /// Texto pequeño en mayúsculas encima del título ("CLIENTE", "TAREA").
  final String? etiqueta;
  final List<Widget> campos;
  final VoidCallback onGuardar;
  final VoidCallback? onBorrar;

  /// Panel fijo dentro de una vista (p. ej. a la derecha del trabajador), no una ventana flotante.
  final bool incrustada;
  const VentanaFormulario({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.etiqueta,
    required this.campos,
    required this.onGuardar,
    this.onBorrar,
    this.incrustada = false,
  });

  @override
  State<VentanaFormulario> createState() => _VentanaFormularioState();
}

class _VentanaFormularioState extends State<VentanaFormulario> {
  bool acoplada = _acoplada;
  Offset desplazamiento = Offset.zero;
  bool arrastrando = false;

  void alternar() => setState(() {
    acoplada = _acoplada = !acoplada;
    desplazamiento = Offset.zero;
  });

  @override
  Widget build(BuildContext context) {
    if (widget.incrustada) {
      return Material(
        color: P.superficie,
        shape: Border(left: BorderSide(color: P.borde)),
        child: Column(
          children: [
            _cabecera(),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.campos),
              ),
            ),
            const Divider(),
            _pie(),
          ],
        ),
      );
    }
    final pantalla = MediaQuery.sizeOf(context);
    final ancho = min(acoplada ? 580.0 : 620.0, pantalla.width);
    final alto = acoplada ? pantalla.height : min(pantalla.height - 48, 720.0);
    var left = pantalla.width - ancho;
    var top = 0.0;
    if (!acoplada) {
      // Que la cabecera nunca se salga de la pantalla al arrastrar.
      left = ((pantalla.width - ancho) / 2 + desplazamiento.dx).clamp(120 - ancho, pantalla.width - 120).toDouble();
      top = ((pantalla.height - alto) / 2 + desplazamiento.dy).clamp(0, pantalla.height - 80).toDouble();
    }
    return Stack(
      children: [
        AnimatedPositioned(
          duration: arrastrando ? Duration.zero : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          left: left,
          top: top,
          width: ancho,
          height: alto,
          child: Material(
            color: P.superficie,
            elevation: 24,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(acoplada ? 0 : 14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _cabecera(),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.campos),
                  ),
                ),
                const Divider(),
                _pie(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cabecera() => MouseRegion(
    cursor: acoplada || widget.incrustada ? MouseCursor.defer : SystemMouseCursors.move,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: acoplada || widget.incrustada ? null : (_) => setState(() => arrastrando = true),
      onPanUpdate: acoplada || widget.incrustada ? null : (d) => setState(() => desplazamiento += d.delta),
      onPanEnd: acoplada || widget.incrustada ? null : (_) => setState(() => arrastrando = false),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, acoplada || widget.incrustada ? 24 : 10, 12, 18),
        child: Column(
          children: [
            if (!acoplada && !widget.incrustada)
              Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: P.borde, borderRadius: BorderRadius.circular(3)),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.etiqueta != null)
                        Text(
                          widget.etiqueta!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                            color: P.morado,
                          ),
                        ),
                      Text(
                        widget.titulo,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.4),
                      ),
                      if (widget.subtitulo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(widget.subtitulo!, style: TextStyle(color: P.textoSuave, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
                if (!widget.incrustada) ...[
                  IconButton(
                    tooltip: acoplada ? 'Volver a ventana' : 'Acoplar a la derecha',
                    onPressed: alternar,
                    icon: Icon(acoplada ? Icons.web_asset_rounded : Icons.view_sidebar_outlined, color: P.textoSuave),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _pie() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(
      children: [
        if (widget.onBorrar != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: P.rojo),
            onPressed: widget.onBorrar,
            child: const Text('Eliminar'),
          ),
        const Spacer(),
        if (!widget.incrustada) ...[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: P.textoSuave),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton(onPressed: widget.onGuardar, child: const Text('Guardar')),
      ],
    ),
  );
}

/// Sección plegable para lo que no hace falta rellenar al principio.
class MasDetalles extends StatefulWidget {
  final String titulo;
  final List<Widget> children;
  const MasDetalles(this.titulo, this.children, {super.key});

  @override
  State<MasDetalles> createState() => _MasDetallesState();
}

class _MasDetallesState extends State<MasDetalles> {
  bool abierto = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => abierto = !abierto),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              AnimatedRotation(
                turns: abierto ? .25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.chevron_right_rounded, color: P.morado),
              ),
              const SizedBox(width: 6),
              Text(
                widget.titulo,
                style: TextStyle(fontWeight: FontWeight.w600, color: P.morado),
              ),
            ],
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: abierto
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
              )
            : const SizedBox(width: double.infinity),
      ),
    ],
  );
}

// ── Piezas de formulario ──

Widget etiqueta(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    t,
    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: P.textoSuave),
  ),
);

Widget seccion(String t) => Padding(
  padding: const EdgeInsets.only(top: 12, bottom: 12),
  child: Row(
    children: [
      Text(t, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: P.borde)),
    ],
  ),
);

Widget campo(String label, TextEditingController c, {String? hint, int lineas = 1, String? error}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      etiqueta(label),
      TextField(
        controller: c,
        maxLines: lineas,
        decoration: InputDecoration(hintText: hint, errorText: error),
      ),
    ],
  ),
);

Widget dos(Widget a, Widget b) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: a),
    const SizedBox(width: 12),
    Expanded(child: b),
  ],
);

Widget conMargen(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 16), child: w);

class CampoFecha extends StatelessWidget {
  final String label;
  final DateTime? valor;
  final ValueChanged<DateTime> onChanged;

  /// Fecha máxima elegible (p. ej. hoy, para algo que ya se hizo).
  final DateTime? hasta;
  const CampoFecha(this.label, this.valor, this.onChanged, {super.key, this.hasta});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        etiqueta(label),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: valor == null || (hasta != null && valor!.isAfter(hasta!))
                  ? (hasta ?? DateTime.now())
                  : valor!,
              firstDate: DateTime(2000),
              lastDate: hasta ?? DateTime(2100),
            );
            if (d != null) onChanged(d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_rounded, size: 18)),
            child: Text(fecha(valor), style: TextStyle(color: valor == null ? P.textoSuave : P.texto)),
          ),
        ),
      ],
    ),
  );
}

const duraciones = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480];

String duracion(int m) => m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min');

class CampoHora extends StatelessWidget {
  final String label;
  final int? valor; // minutos desde las 00:00
  final ValueChanged<int> onChanged;
  const CampoHora(this.label, this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        etiqueta(label),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final h = await showTimePicker(
              context: context,
              initialTime: valor == null
                  ? const TimeOfDay(hour: 9, minute: 0)
                  : TimeOfDay(hour: valor! ~/ 60, minute: valor! % 60),
            );
            if (h != null) onChanged(h.hour * 60 + h.minute);
          },
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.schedule_rounded, size: 18)),
            child: Text(
              valor == null ? '—' : hhmm(valor!),
              style: TextStyle(color: valor == null ? P.textoSuave : P.texto),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget selectorColor(int actual, ValueChanged<int> onChanged) => Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    for (var i = 0; i < paleta.length; i++)
      InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: paleta[i],
            shape: BoxShape.circle,
            border: Border.all(color: i == actual ? P.superficie : Colors.transparent, width: 2),
            boxShadow: i == actual ? [BoxShadow(color: paleta[i], spreadRadius: 2)] : null,
          ),
          child: i == actual ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
        ),
      ),
  ],
);

/// Cabecera de identidad del formulario: avatar grande con el nombre y la paleta, sobre un panel tintado.
Widget identidad(String nombre, int color, ValueChanged<int> onColor, {bool cuadrado = false, String? pie}) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorPaleta(color).withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorPaleta(color).withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Avatar(inicialesDe(nombre.trim().isEmpty ? '?' : nombre), colorPaleta(color), size: 52, cuadrado: cuadrado),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.trim().isEmpty ? 'Sin nombre' : nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: nombre.trim().isEmpty ? P.textoSuave : P.texto,
                  ),
                ),
                if (pie != null) Text(pie, style: TextStyle(fontSize: 12, color: P.textoSuave)),
                const SizedBox(height: 8),
                selectorColor(color, onColor),
              ],
            ),
          ),
        ],
      ),
    );

/// Elegir una opción entre pastillas de su color (estado de hoy, estado de la máquina…).
class SelectorEstado<T> extends StatelessWidget {
  final List<(T, String, Color)> opciones;
  final T valor;
  final ValueChanged<T> onChanged;
  const SelectorEstado({super.key, required this.opciones, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (v, texto, color) in opciones)
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: v == valor ? color.withValues(alpha: .12) : P.superficie,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: v == valor ? color : P.borde, width: v == valor ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: v == valor ? FontWeight.w700 : FontWeight.w500,
                    color: v == valor ? color : P.texto,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

Widget chipsCompetencias(List<String> seleccion, VoidCallback onChanged) => Wrap(
  spacing: 6,
  runSpacing: 6,
  children: [
    for (final c in competencias)
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          seleccion.contains(c) ? seleccion.remove(c) : seleccion.add(c);
          onChanged();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: seleccion.contains(c) ? P.morado : P.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: seleccion.contains(c) ? P.morado : P.borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                seleccion.contains(c) ? Icons.check_rounded : Icons.add_rounded,
                size: 14,
                color: seleccion.contains(c) ? Colors.white : P.textoSuave,
              ),
              const SizedBox(width: 5),
              Text(
                c,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: seleccion.contains(c) ? Colors.white : P.texto,
                ),
              ),
            ],
          ),
        ),
      ),
  ],
);

// ── Cliente ──

Future<void> abrirClienteForm(BuildContext context, [Cliente? c]) => abrirPanel(context, ClienteForm(original: c));

class ClienteForm extends StatefulWidget {
  final Cliente? original;
  const ClienteForm({super.key, this.original});

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  late final Cliente c =
      widget.original?.copia() ?? Cliente(id: store.nuevoId(), color: store.clientes.length % paleta.length);
  late final nombre = TextEditingController(text: c.nombre)..addListener(() => setState(() {}));
  late final cif = TextEditingController(text: c.cif);
  late final direccion = TextEditingController(text: c.direccion);
  late final ciudad = TextEditingController(text: c.ciudad);
  late final cp = TextEditingController(text: c.cp);
  late final provincia = TextEditingController(text: c.provincia);
  late final telefono = TextEditingController(text: c.telefono);
  late final email = TextEditingController(text: c.email);
  late final contacto = TextEditingController(text: c.contacto);
  late final telContacto = TextEditingController(text: c.telefonoContacto);
  late final notas = TextEditingController(text: c.notas);
  String? error;

  void guardar() {
    if (nombre.text.trim().isEmpty) {
      setState(() => error = 'El nombre es obligatorio');
      return;
    }
    c
      ..nombre = nombre.text.trim()
      ..cif = cif.text.trim()
      ..direccion = direccion.text.trim()
      ..ciudad = ciudad.text.trim()
      ..cp = cp.text.trim()
      ..provincia = provincia.text.trim()
      ..telefono = telefono.text.trim()
      ..email = email.text.trim()
      ..contacto = contacto.text.trim()
      ..telefonoContacto = telContacto.text.trim()
      ..notas = notas.text.trim();
    store.guardarCliente(c);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'Cliente',
    titulo: widget.original == null ? 'Nuevo cliente' : 'Editar cliente',
    subtitulo: 'A quien das mantenimiento: una comunidad, un colegio, un hospital, una empresa…',
    onGuardar: guardar,
    onBorrar: widget.original == null
        ? null
        : () async {
            final nav = Navigator.of(context);
            if (await confirmar(context, '¿Eliminar ${c.nombre} y todas sus tareas?')) {
              store.borrarCliente(c.id);
              nav.pop();
            }
          },
    campos: [
      identidad(
        nombre.text,
        c.color,
        (i) => setState(() => c.color = i),
        cuadrado: true,
        pie: 'Su color le identifica en el calendario y las listas',
      ),
      seccion('Datos básicos'),
      campo('Nombre', nombre, hint: 'Colegio San José', error: error),
      dos(campo('Teléfono', telefono), campo('Email', email)),
      seccion('Persona de contacto'),
      dos(campo('Nombre', contacto, hint: 'Administrador, conserje…'), campo('Teléfono', telContacto)),
      MasDetalles('Datos fiscales y notas', [
        dos(campo('CIF/NIF', cif), CampoFecha('Fecha de alta', c.fechaAlta, (d) => setState(() => c.fechaAlta = d))),
        campo('Dirección fiscal', direccion),
        dos(campo('Ciudad', ciudad), campo('Código postal', cp)),
        campo('Provincia', provincia),
        campo('Notas', notas, lineas: 3),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activo'),
          value: c.activa,
          onChanged: (v) => setState(() => c.activa = v),
        ),
      ]),
    ],
  );
}

// ── Trabajador ──

Future<void> abrirTrabajadorForm(BuildContext context, [Trabajador? w]) =>
    abrirPanel(context, TrabajadorForm(original: w));

class TrabajadorForm extends StatefulWidget {
  final Trabajador? original;

  /// Fijo a la derecha de la vista del trabajador: guardar no cierra nada.
  final bool incrustada;
  const TrabajadorForm({super.key, this.original, this.incrustada = false});

  @override
  State<TrabajadorForm> createState() => _TrabajadorFormState();
}

class _TrabajadorFormState extends State<TrabajadorForm> {
  late final Trabajador w =
      widget.original?.copia() ?? Trabajador(id: store.nuevoId(), color: store.trabajadores.length % paleta.length);
  late final nombre = TextEditingController(text: w.nombre)..addListener(() => setState(() {}));
  late final apellidos = TextEditingController(text: w.apellidos)..addListener(() => setState(() {}));
  late final telefono = TextEditingController(text: w.telefono);
  late final email = TextEditingController(text: w.email);
  late final titulos = TextEditingController(text: w.titulos);
  late final info = TextEditingController(text: w.info);
  String? error, errorCompetencias;

  void guardar() {
    setState(() {
      error = nombre.text.trim().isEmpty ? 'El nombre es obligatorio' : null;
      errorCompetencias = w.competencias.isEmpty ? 'Elige al menos una competencia' : null;
    });
    if (error != null || errorCompetencias != null) return;
    w
      ..nombre = nombre.text.trim()
      ..apellidos = apellidos.text.trim()
      ..telefono = telefono.text.trim()
      ..email = email.text.trim()
      ..titulos = titulos.text.trim()
      ..info = info.text.trim();
    store.guardarTrabajador(w.copia());
    if (widget.incrustada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, width: 320, content: Text('${w.nombreCompleto} guardado')),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => VentanaFormulario(
    etiqueta: 'Trabajador',
    titulo: widget.original == null ? 'Nuevo trabajador' : (widget.incrustada ? 'Ficha' : 'Editar trabajador'),
    subtitulo: 'Sus competencias deciden qué tareas puede hacer.',
    incrustada: widget.incrustada,
    onGuardar: guardar,
    onBorrar: widget.original == null
        ? null
        : () async {
            final nav = Navigator.of(context);
            if (await confirmar(context, '¿Eliminar a ${w.nombreCompleto}?')) {
              store.borrarTrabajador(w.id);
              if (!widget.incrustada) nav.pop();
            }
          },
    campos: [
      identidad(
        '${nombre.text} ${apellidos.text}'.trim(),
        w.color,
        (i) => setState(() => w.color = i),
        pie: w.competencias.isEmpty ? 'Sin competencias todavía' : '${w.competencias.length} competencias',
      ),
      seccion('Datos básicos'),
      dos(campo('Nombre', nombre, error: error), campo('Apellidos', apellidos)),
      seccion('Competencias'),
      chipsCompetencias(w.competencias, () => setState(() => errorCompetencias = null)),
      const SizedBox(height: 8),
      if (errorCompetencias != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(errorCompetencias!, style: const TextStyle(color: P.rojo, fontSize: 12)),
        ),
      const SizedBox(height: 8),
      seccion('Estado de hoy'),
      conMargen(
        SelectorEstado<EstadoHoy>(
          opciones: [for (final e in EstadoHoy.values) (e, e.etiqueta, e.color)],
          valor: w.estadoHoy,
          onChanged: (e) => setState(() => w.estadoHoy = e),
        ),
      ),
      MasDetalles('Contacto y más', [
        dos(campo('Teléfono', telefono), campo('Email', email)),
        campo('Títulos y capacidades', titulos, hint: 'Carné RITE, PRL 60 h…'),
        campo('Información básica', info, lineas: 2),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activo'),
          subtitle: const Text('Si está de baja o ya no trabaja, desactívalo.'),
          value: w.activo,
          onChanged: (v) => setState(() => w.activo = v),
        ),
      ]),
    ],
  );
}

// ── Tarea ──

Future<void> abrirTareaForm(BuildContext context, Tarea? t, {String? clienteId}) =>
    abrirPanel(context, TareaForm(original: t, clienteId: clienteId));

class TareaForm extends StatefulWidget {
  final Tarea? original;
  final String? clienteId;
  const TareaForm({super.key, this.original, this.clienteId});

  @override
  State<TareaForm> createState() => _TareaFormState();
}

class _TareaFormState extends State<TareaForm> {
  late final Tarea t = widget.original?.copia() ?? Tarea(id: store.nuevoId(), clienteId: widget.clienteId);
  late final nombre = TextEditingController(text: t.nombre);
  late final marca = TextEditingController(text: t.marca);
  late final modelo = TextEditingController(text: t.modelo);
  late final serie = TextEditingController(text: t.numeroSerie);
  late final ubicacion = TextEditingController(text: t.ubicacion);
  late final notas = TextEditingController(text: t.notas);
  String? error;

  bool get nueva => widget.original == null;

  /// Solo al crear desde la vista de Tareas se elige cliente; desde un cliente va fija a él.
  bool get eligeCliente => nueva && widget.clienteId == null;

  /// Rellena la tarea con los datos de una plantilla.
  void aplicar(Tarea p) => setState(() {
    t
      ..plantillaId = p.id
      ..tipo = p.tipo
      ..periodicidad = p.periodicidad
      ..competencias = [...p.competencias]
      ..proximo = masDias(hoy(), p.periodicidad.dias);
    nombre.text = p.nombre;
    marca.text = p.marca;
    modelo.text = p.modelo;
    notas.text = p.notas;
    final mejor = store.mejorPara(t);
    t.trabajadorIds = mejor == null ? [] : [mejor.id];
  });

  void guardar() {
    if (nombre.text.trim().isEmpty) {
      setState(() => error = 'Ponle un nombre');
      return;
    }
    t
      ..nombre = nombre.text.trim()
      ..marca = marca.text.trim()
      ..modelo = modelo.text.trim()
      ..numeroSerie = serie.text.trim()
      ..ubicacion = ubicacion.text.trim()
      ..notas = notas.text.trim();
    store.guardarTarea(t);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final trabajadores = [...store.trabajadores]
      ..sort((a, b) => (store.esApto(a, t) ? 0 : 1) - (store.esApto(b, t) ? 0 : 1));
    final aptos = trabajadores.where((w) => store.esApto(w, t)).length;
    final plantillas = store.plantillas.where((p) => p.id != t.id).toList();

    return VentanaFormulario(
      etiqueta: t.esPlantilla ? 'Plantilla' : 'Mantenimiento',
      titulo: nueva ? (t.esPlantilla ? 'Nueva plantilla' : 'Nueva tarea') : nombre.text,
      subtitulo: t.esPlantilla
          ? 'Sin cliente: sirve de plantilla para crear tareas en tus clientes.'
          : store.cliente(t.clienteId)?.nombre,
      onGuardar: guardar,
      onBorrar: nueva
          ? null
          : () async {
              final nav = Navigator.of(context);
              if (await confirmar(context, '¿Eliminar "${t.nombre}"?')) {
                store.borrarTarea(t.id);
                nav.pop();
              }
            },
      campos: [
        if (nueva && !t.esPlantilla && plantillas.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: P.moradoSuave.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: P.morado.withValues(alpha: .2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: P.morado, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Partir de una plantilla',
                      style: TextStyle(fontWeight: FontWeight.w700, color: P.moradoOscuro),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Se rellena casi todo y se propone el trabajador más adecuado.',
                  style: TextStyle(color: P.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in plantillas)
                      ActionChip(
                        avatar: Icon(tipoDe(p.tipo).icono, size: 16, color: tipoDe(p.tipo).color),
                        label: Text(p.nombre),
                        backgroundColor: t.plantillaId == p.id ? Colors.white : null,
                        side: BorderSide(color: t.plantillaId == p.id ? P.morado : P.borde),
                        onPressed: () => aplicar(p),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (eligeCliente) ...[
          seccion('Cliente'),
          conMargen(
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: t.clienteId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin cliente (plantilla)')),
                for (final c in store.clientes) DropdownMenuItem(value: c.id, child: Text(c.nombre)),
              ],
              onChanged: (v) => setState(() => t.clienteId = v),
            ),
          ),
        ],
        seccion('Qué hay que mantener'),
        etiqueta('Tipo'),
        conMargen(
          SelectorTipo(
            t.tipo,
            (v) => setState(() {
              t.tipo = v;
              final c = tipoDe(v).competencia;
              if (c != null && !t.competencias.contains(c)) t.competencias.add(c);
            }),
          ),
        ),
        campo('Nombre', nombre, hint: 'Ascensor portal A, centralita de incendios…', error: error),
        conMargen(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              etiqueta('Periodicidad'),
              SegmentedButton<Periodicidad>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: P.moradoSuave,
                  selectedForegroundColor: P.moradoOscuro,
                  side: BorderSide(color: P.borde),
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                segments: [for (final p in Periodicidad.values) ButtonSegment(value: p, label: Text(p.etiqueta))],
                selected: {t.periodicidad},
                onSelectionChanged: (s) => setState(() {
                  t.periodicidad = s.first;
                  if (t.ultimo != null) t.proximo = masDias(t.ultimo!, s.first.dias);
                }),
              ),
            ],
          ),
        ),
        if (!t.esPlantilla)
          dos(
            CampoFecha(
              'Último mantenimiento',
              t.ultimo,
              (d) => setState(() {
                t.ultimo = d;
                t.proximo = masDias(d, t.periodicidad.dias);
              }),
              hasta: hoy(), // lo que ya se hizo no puede ser futuro
            ),
            CampoFecha('Próximo mantenimiento', t.proximo, (d) => setState(() => t.proximo = d)),
          ),
        if (!t.esPlantilla) ...[
          seccion('Horario'),
          dos(
            CampoFecha('Solicitado el', t.solicitud, (d) => setState(() => t.solicitud = d)),
            CampoHora('Hora de inicio', t.inicioMin, (m) => setState(() => t.inicioMin = m)),
          ),
          dos(
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiqueta('Tiempo estimado'),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: duraciones.contains(t.duracionMin) ? t.duracionMin : 60,
                    items: [for (final d in duraciones) DropdownMenuItem(value: d, child: Text(duracion(d)))],
                    onChanged: (v) => setState(() => t.duracionMin = v!),
                  ),
                ],
              ),
            ),
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiqueta('Fin previsto'),
                  InputDecorator(
                    decoration: const InputDecoration(),
                    child: Text(
                      t.finMin == null
                          ? '—'
                          : '${hhmm(t.finMin!)}  (+${tipoDe(t.tipo).retrasoMin} min de margen habitual)',
                      style: TextStyle(color: t.finMin == null ? P.textoSuave : P.texto),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        seccion('Competencias mínimas'),
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Qué tiene que saber hacer el trabajador. Con esto Pulpo sabe a quién puede asignarla.',
            style: TextStyle(color: P.textoSuave, fontSize: 13),
          ),
        ),
        chipsCompetencias(t.competencias, () => setState(() {})),
        if (!t.esPlantilla) ...[
          const SizedBox(height: 8),
          seccion('Trabajadores'),
          Row(
            children: [
              Pill('$aptos aptos', aptos > 0 ? P.verde : P.rojo, punto: true),
              const Spacer(),
              TextButton(
                onPressed: aptos == 0
                    ? null
                    : () => setState(() {
                        final m = store.mejorPara(t);
                        if (m != null) t.trabajadorIds = [m.id];
                      }),
                child: const Text('Asignar automáticamente'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final w in trabajadores) _filaTrabajador(w),
        ],
        const SizedBox(height: 8),
        MasDetalles('Detalles del equipo y notas', [
          campo('Ubicación', ubicacion, hint: 'Sala de máquinas, planta 2…'),
          dos(campo('Marca', marca), campo('Modelo', modelo)),
          dos(
            campo('Número de serie', serie),
            CampoFecha('Fecha de instalación', t.instalacion, (d) => setState(() => t.instalacion = d)),
          ),
          etiqueta('Estado de la máquina'),
          conMargen(
            SelectorEstado<EstadoMaquina>(
              opciones: [for (final e in EstadoMaquina.values) (e, e.etiqueta, e.color)],
              valor: t.estadoMaquina,
              onChanged: (e) => setState(() => t.estadoMaquina = e),
            ),
          ),
          campo('Notas / observaciones', notas, lineas: 3),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activa'),
            value: t.activa,
            onChanged: (v) => setState(() => t.activa = v),
          ),
        ]),
      ],
    );
  }

  Widget _filaTrabajador(Trabajador w) {
    final apto = store.esApto(w, t);
    final faltan = store.faltan(w, t);
    final marcado = t.trabajadorIds.contains(w.id);
    return Opacity(
      opacity: apto ? 1 : .55,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => marcado ? t.trabajadorIds.remove(w.id) : t.trabajadorIds.add(w.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: marcado,
                onChanged: (_) => setState(() => marcado ? t.trabajadorIds.remove(w.id) : t.trabajadorIds.add(w.id)),
              ),
              Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(w.estadoHoy.etiqueta, style: TextStyle(color: w.estadoHoy.color, fontSize: 12)),
                  ],
                ),
              ),
              if (!w.activo)
                const Pill('Inactivo', P.gris, solido: true)
              else if (apto)
                const Pill('Apto', P.verde, solido: true)
              else
                Pill('Le falta: ${faltan.join(', ')}', P.gris),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuadrícula de tipos de mantenimiento: icono de su color y nombre; el elegido, relleno.
class SelectorTipo extends StatelessWidget {
  final String valor;
  final ValueChanged<String> onChanged;
  const SelectorTipo(this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const cols = 5;
      final w = (box.maxWidth - (cols - 1) * 8) / cols;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final x in tipos)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(x.nombre),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: w,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: x.nombre == valor ? x.color : P.columna,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: x.nombre == valor
                      ? [BoxShadow(color: x.color.withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(x.icono, size: 20, color: x.nombre == valor ? Colors.white : x.color),
                    const SizedBox(height: 5),
                    Text(
                      x.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: x.nombre == valor ? Colors.white : P.texto,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
