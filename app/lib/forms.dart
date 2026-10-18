import 'dart:math';

import 'package:flutter/material.dart';

import 'geo.dart';
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
                padding: const EdgeInsets.fromLTRB(36, 24, 36, 36),
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
    // Ventana amplia (sin llegar a pantalla completa): más aire para los formularios.
    final ancho = min(acoplada ? 680.0 : 860.0, pantalla.width - (acoplada ? 0 : 48));
    final alto = acoplada ? pantalla.height : min(pantalla.height * .9, 900.0);
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
                    padding: const EdgeInsets.fromLTRB(36, 24, 36, 36),
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
        padding: EdgeInsets.fromLTRB(36, acoplada || widget.incrustada ? 28 : 12, 16, 20),
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
                        style: TextStyle(
                          fontFamily: P.titulos,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                        ),
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

Widget seccion(String t) => Container(
  margin: const EdgeInsets.only(top: 14, bottom: 14),
  padding: const EdgeInsets.only(top: 20),
  decoration: BoxDecoration(
    border: Border(top: BorderSide(color: P.borde)),
  ),
  child: Text(
    t,
    style: TextStyle(fontFamily: P.titulos, fontSize: 15.5, fontWeight: FontWeight.w700),
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

/// Bloque de formulario estilo Jobber: título y explicación a la izquierda, campos a la derecha.
/// En ventanas estrechas se apila.
class Bloque extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final List<Widget> children;
  const Bloque(this.titulo, this.children, {super.key, this.descripcion});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: LayoutBuilder(
      builder: (context, box) {
        final cabeza = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(fontFamily: P.titulos, fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            if (descripcion != null) ...[
              const SizedBox(height: 4),
              Text(descripcion!, style: TextStyle(fontSize: 12.5, color: P.textoSuave, height: 1.4)),
            ],
          ],
        );
        final campos = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
        final contenido = box.maxWidth < 640
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cabeza, const SizedBox(height: 14), campos],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 210, child: cabeza),
                  const SizedBox(width: 32),
                  Expanded(child: campos),
                ],
              );
        return Container(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: P.borde)),
          ),
          child: contenido,
        );
      },
    ),
  );
}

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
    // Si la dirección es nueva o ha cambiado, se ubica en el mapa en segundo plano.
    final cambio = c.direccionCompleta != (widget.original?.direccionCompleta ?? '');
    if (cambio || !c.ubicado) {
      c
        ..lat = null
        ..lng = null;
      final copia = c.copia();
      ubicar(copia).then((ok) {
        if (ok && store.cliente(copia.id) != null) {
          store.cliente(copia.id)!
            ..lat = copia.lat
            ..lng = copia.lng;
          store.guardarCliente(store.cliente(copia.id)!);
        }
      });
    }
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
      const SizedBox(height: 22),
      Bloque('Datos del cliente', descripcion: 'Cómo se llama y cómo contactar con él.', [
        campo('Nombre', nombre, hint: 'Colegio San José', error: error),
        dos(campo('Teléfono', telefono), campo('Email', email)),
      ]),
      Bloque('Persona de contacto', descripcion: 'Con quién hablas para coordinar las visitas.', [
        dos(campo('Nombre', contacto, hint: 'Administrador, conserje…'), campo('Teléfono', telContacto)),
      ]),
      Bloque('Dirección', descripcion: 'Dónde está. Con ella se sitúa en el mapa de la agenda.', [
        campo('Calle y número', direccion),
        dos(campo('Ciudad', ciudad), campo('Código postal', cp)),
        campo('Provincia', provincia),
      ]),
      Bloque('Datos fiscales', descripcion: 'Para facturar más adelante.', [
        dos(campo('CIF/NIF', cif), CampoFecha('Cliente desde', c.fechaAlta, (d) => setState(() => c.fechaAlta = d))),
      ]),
      Bloque('Notas', [
        campo('Notas internas', notas, lineas: 3),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activo'),
          subtitle: const Text('Un cliente inactivo no aparece en la planificación.'),
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
      const SizedBox(height: 22),
      Bloque('Datos personales', descripcion: 'Nombre y forma de contacto.', [
        dos(campo('Nombre', nombre, error: error), campo('Apellidos', apellidos)),
        dos(campo('Teléfono', telefono), campo('Email', email)),
      ]),
      Bloque('Competencias', descripcion: 'Qué sabe hacer. Pulpo solo le asigna tareas que puede hacer.', [
        chipsCompetencias(w.competencias, () => setState(() => errorCompetencias = null)),
        if (errorCompetencias != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(errorCompetencias!, style: const TextStyle(color: P.rojo, fontSize: 12)),
          ),
        const SizedBox(height: 12),
        campo('Títulos y carnés', titulos, hint: 'Carné RITE, PRL 60 h…'),
      ]),
      Bloque('Disponibilidad', descripcion: 'Cómo está hoy. Los ausentes no reciben tareas.', [
        conMargen(
          SelectorEstado<EstadoHoy>(
            opciones: [for (final e in EstadoHoy.values) (e, e.etiqueta, e.color)],
            valor: w.estadoHoy,
            onChanged: (e) => setState(() => w.estadoHoy = e),
          ),
        ),
      ]),
      Bloque('Notas', [
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

/// [fecha], [horaMin] y [trabajadorId] rellenan la tarea nueva (p. ej. al crearla desde un hueco de la agenda).
Future<void> abrirTareaForm(
  BuildContext context,
  Tarea? t, {
  String? clienteId,
  bool plantilla = false,
  DateTime? fecha,
  int? horaMin,
  String? trabajadorId,
}) => abrirPanel(
  context,
  TareaForm(
    original: t,
    clienteId: clienteId,
    plantilla: plantilla,
    fecha: fecha,
    horaMin: horaMin,
    trabajadorId: trabajadorId,
  ),
);

class TareaForm extends StatefulWidget {
  final Tarea? original;
  final String? clienteId;
  final DateTime? fecha;
  final int? horaMin;
  final String? trabajadorId;

  /// Crear una plantilla (sin cliente) en vez de una tarea.
  final bool plantilla;
  const TareaForm({
    super.key,
    this.original,
    this.clienteId,
    this.plantilla = false,
    this.fecha,
    this.horaMin,
    this.trabajadorId,
  });

  @override
  State<TareaForm> createState() => _TareaFormState();
}

class _TareaFormState extends State<TareaForm> {
  late final Tarea t =
      widget.original?.copia() ??
      Tarea(
        id: store.nuevoId(),
        // Desde la agenda (con fecha o técnico) es una tarea real, no una plantilla: se propone el primer cliente.
        // Una tarea nueva es de un cliente (se propone el primero); solo es plantilla si se pide.
        clienteId: widget.clienteId ?? (widget.plantilla ? null : store.clientes.firstOrNull?.id),
        plantilla: widget.plantilla,
        proximo: widget.fecha,
        inicioMin: widget.horaMin,
        trabajadorIds: [?widget.trabajadorId],
      );
  late final nombre = TextEditingController(text: t.nombre);
  late final marca = TextEditingController(text: t.marca);
  late final modelo = TextEditingController(text: t.modelo);
  late final serie = TextEditingController(text: t.numeroSerie);
  late final ubicacion = TextEditingController(text: t.ubicacion);
  late final notas = TextEditingController(text: t.notas);
  String? error;

  bool get nueva => widget.original == null;

  /// Rellena la tarea con los datos de una plantilla.
  void aplicar(Tarea p) => setState(() {
    store.usarPlantilla(p.id);
    t
      ..plantillaId = p.id
      ..tipo = p.tipo
      ..periodicidad = p.periodicidad
      ..competencias = [...p.competencias]
      ..proximo = widget.fecha ?? (p.periodicidad.repite ? masDias(hoy(), p.periodicidad.dias) : hoy());
    nombre.text = p.nombre;
    marca.text = p.marca;
    modelo.text = p.modelo;
    notas.text = p.notas;
    final mejor = store.mejorPara(t);
    t.trabajadorIds = widget.trabajadorId != null ? [widget.trabajadorId!] : (mejor == null ? [] : [mejor.id]);
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
    final aptos = store.trabajadores.where((w) => store.esApto(w, t)).length;
    final plantillas = store.plantillasPorUso.where((p) => p.id != t.id).toList();

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
        // 1. Nombre, grande: lo primero.
        campoGrande(
          t.esPlantilla ? 'Nombre de la plantilla' : 'Nombre de la tarea',
          nombre,
          hint: t.esPlantilla
              ? 'Revisión de ascensor, corte de césped…'
              : 'Ascensor portal A, centralita de incendios…',
          error: error,
        ),
        if (!t.esPlantilla) SelectorColorTarea(t, () => setState(() {})),
        // 3. Tipo, en un recuadro de color: plantillas (tarea nueva) o tipos (plantilla).
        if (t.esPlantilla)
          _Recuadro(
            'Tipo',
            SelectorTipo(
              t.tipo,
              (v) => setState(() {
                t.tipo = v;
                final c = tipoDe(v).competencia;
                if (c != null && !t.competencias.contains(c)) t.competencias.add(c);
              }),
            ),
          )
        else if (nueva)
          _Recuadro(
            'Tipo · a partir de una plantilla',
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final p in plantillas) _CuadroPlantilla(p, t.plantillaId == p.id, () => aplicar(p)),
                _CuadroOtro(() async {
                  final p = await crearPlantillaRapida(context);
                  if (p != null) aplicar(p);
                }),
              ],
            ),
          ),
        // 4. Cuándo: calendario a la vista, hora exacta o franja.
        SelectorCuando(t, () => setState(() {})),
        etiqueta('Criticidad'),
        conMargen(
          SelectorEstado<Criticidad>(
            opciones: [for (final c in Criticidad.values) (c, c.etiqueta, c.color)],
            valor: t.criticidad,
            onChanged: (c) => setState(() => t.criticidad = c),
          ),
        ),
        // 5. Para quién y quién la hace: menús desplegables.
        if (!t.esPlantilla) ...[
          dos(
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [etiqueta('Cliente'), SelectorCliente(t.clienteId, (id) => setState(() => t.clienteId = id))],
              ),
            ),
            conMargen(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: etiqueta('Trabajadores')),
                      if (aptos > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Enlace(
                            'Asignar el más adecuado',
                            onTap: () => setState(() {
                              final m = store.mejorPara(t);
                              if (m != null) t.trabajadorIds = [m.id];
                            }),
                          ),
                        ),
                    ],
                  ),
                  SelectorTrabajadores(t, () => setState(() {})),
                ],
              ),
            ),
          ),
        ],
        seccion('Competencias mínimas'),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Qué tiene que saber hacer el trabajador. Con esto Pulpo sabe a quién puede asignarla.',
            style: TextStyle(color: P.textoSuave, fontSize: 13),
          ),
        ),
        chipsCompetencias(t.competencias, () => setState(() {})),
        const SizedBox(height: 8),
        MasDetalles('Detalles del equipo y notas', [
          if (!t.esPlantilla)
            dos(
              CampoFecha(
                'Último mantenimiento',
                t.ultimo,
                (d) => setState(() {
                  t.ultimo = d;
                  if (t.periodicidad.repite) t.proximo = masDias(d, t.periodicidad.dias);
                }),
                hasta: hoy(), // lo que ya se hizo no puede ser futuro
              ),
              CampoFecha('Solicitado el', t.solicitud, (d) => setState(() => t.solicitud = d)),
            ),
          campo('Ubicación', ubicacion, hint: 'Sala de máquinas, planta 2…'),
          dos(campo('Marca', marca), campo('Modelo', modelo)),
          dos(
            campo('Número de serie', serie),
            CampoFecha('Fecha de instalación', t.instalacion, (d) => setState(() => t.instalacion = d)),
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

/// Cuadradito de plantilla: barrita del color de su tipo, nombre y periodicidad.
class _CuadroPlantilla extends StatelessWidget {
  final Tarea p;
  final bool elegida;
  final VoidCallback onTap;
  const _CuadroPlantilla(this.p, this.elegida, this.onTap);

  @override
  Widget build(BuildContext context) {
    final color = tipoDe(p.tipo).color;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 132,
        height: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: elegida ? color.withValues(alpha: .1) : P.superficie,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: elegida ? color : P.borde, width: elegida ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(tipoDe(p.tipo).icono, size: 20, color: color),
            const Spacer(),
            Text(
              p.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2),
            ),
            Text(p.periodicidad.etiqueta, style: TextStyle(fontSize: 11, color: P.textoSuave)),
          ],
        ),
      ),
    );
  }
}

/// Cuadradito "Otro": crea una plantilla nueva sin salir de la tarea.
class _CuadroOtro extends StatelessWidget {
  final VoidCallback onTap;
  const _CuadroOtro(this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      width: 132,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.morado.withValues(alpha: .5), width: 1.5),
        color: P.moradoSuave.withValues(alpha: .5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, color: P.morado),
          const SizedBox(height: 4),
          Text(
            'Otro',
            style: TextStyle(fontWeight: FontWeight.w700, color: P.moradoOscuro),
          ),
        ],
      ),
    ),
  );
}

/// Ventanita para crear una plantilla rápida (nombre y tipo). Devuelve la plantilla creada.
Future<Tarea?> crearPlantillaRapida(BuildContext context) {
  final nombre = TextEditingController();
  var tipo = tipos.first.nombre;
  return showDialog<Tarea>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nueva plantilla',
                  style: TextStyle(fontFamily: P.titulos, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                etiqueta('Nombre'),
                TextField(
                  controller: nombre,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Corte de césped, revisión de puertas…'),
                ),
                const SizedBox(height: 12),
                etiqueta('Tipo'),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  items: [
                    for (final x in tipos)
                      DropdownMenuItem(
                        value: x.nombre,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: x.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(x.nombre),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => set(() => tipo = v!),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        if (nombre.text.trim().isEmpty) return;
                        final p = Tarea(
                          id: store.nuevoId(),
                          nombre: nombre.text.trim(),
                          tipo: tipo,
                          competencias: [?tipoDe(tipo).competencia],
                        );
                        store.guardarTarea(p);
                        Navigator.pop(c, p);
                      },
                      child: const Text('Crear y usar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Nombre en grande: el primer campo, más vistoso.
Widget campoGrande(String label, TextEditingController c, {String? hint, String? error}) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      etiqueta(label),
      TextField(
        controller: c,
        style: TextStyle(fontFamily: P.titulos, fontSize: 20, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: P.titulos,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: P.textoSuave.withValues(alpha: .6),
          ),
          errorText: error,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          fillColor: P.superficie,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: P.borde, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: P.morado, width: 2),
          ),
        ),
      ),
    ],
  ),
);

/// Recuadro tintado con título, para agrupar (el tipo de la tarea).
class _Recuadro extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Recuadro(this.titulo, this.child);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: P.moradoSuave.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: P.morado.withValues(alpha: .2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(fontFamily: P.titulos, fontSize: 14, fontWeight: FontWeight.w700, color: P.moradoOscuro),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

/// Caja que parece un campo con flechas ⇕ (indica que es un menú).
class _CajaMenu extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool abierto;
  const _CajaMenu({required this.child, required this.onTap, required this.abierto});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: P.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: abierto ? P.morado : P.borde, width: abierto ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          Icon(Icons.unfold_more_rounded, size: 18, color: P.textoSuave),
        ],
      ),
    ),
  );
}

/// Menú de clientes: todos los clientes y, abajo, "Crear nuevo cliente" (abre la misma ventana
/// que en Clientes; el cliente creado queda elegido).
class SelectorCliente extends StatelessWidget {
  final String? valor;
  final ValueChanged<String> onChanged;
  const SelectorCliente(this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = store.cliente(valor);
    final clientes = [...store.clientes]..sort((a, b) => a.nombre.compareTo(b.nombre));
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(P.superficie),
        maximumSize: const WidgetStatePropertyAll(Size(460, 380)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      menuChildren: [
        if (clientes.isEmpty)
          const MenuItemButton(child: Text('Aún no tienes clientes'))
        else
          for (final x in clientes)
            MenuItemButton(
              leadingIcon: Avatar(x.iniciales, colorPaleta(x.color), size: 22, cuadrado: true),
              trailingIcon: x.id == valor ? Icon(Icons.check_rounded, size: 18, color: P.morado) : null,
              onPressed: () => onChanged(x.id),
              child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 260), child: Text(x.nombre)),
            ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: Icon(Icons.add_rounded, color: P.morado),
          onPressed: () async {
            final antes = {for (final x in store.clientes) x.id};
            await abrirClienteForm(context);
            final nuevo = store.clientes.where((x) => !antes.contains(x.id)).firstOrNull;
            if (nuevo != null) onChanged(nuevo.id);
          },
          child: Text(
            'Crear nuevo cliente',
            style: TextStyle(color: P.morado, fontWeight: FontWeight.w700),
          ),
        ),
      ],
      builder: (context, menu, _) => _CajaMenu(
        abierto: menu.isOpen,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        child: c == null
            ? Text('Elegir cliente', style: TextStyle(color: P.textoSuave))
            : Row(
                children: [
                  Avatar(c.iniciales, colorPaleta(c.color), size: 24, cuadrado: true),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      c.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Menú de trabajadores: se marcan uno o varios (no se cierra al marcar). Los que no son aptos
/// salen apagados con lo que les falta. Los equipos llegarán con la fase de grupos.
class SelectorTrabajadores extends StatelessWidget {
  final Tarea t;
  final VoidCallback onCambio;
  const SelectorTrabajadores(this.t, this.onCambio, {super.key});

  @override
  Widget build(BuildContext context) {
    final ws = store.trabajadores.where((w) => w.activo).toList()
      ..sort((a, b) => (store.esApto(a, t) ? 0 : 1) - (store.esApto(b, t) ? 0 : 1));
    final elegidos = t.trabajadorIds.map(store.trabajador).whereType<Trabajador>().toList();
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(P.superficie),
        maximumSize: const WidgetStatePropertyAll(Size(460, 420)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      menuChildren: [
        if (ws.isEmpty) const MenuItemButton(child: Text('Aún no tienes trabajadores')),
        for (final w in ws)
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: Icon(
              t.trabajadorIds.contains(w.id) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: t.trabajadorIds.contains(w.id) ? P.morado : P.textoSuave,
            ),
            trailingIcon: store.esApto(w, t)
                ? const Pill('Apto', P.verde, solido: true)
                : Pill('Le falta: ${store.faltan(w, t).join(', ')}', P.gris),
            onPressed: () {
              t.trabajadorIds.contains(w.id) ? t.trabajadorIds.remove(w.id) : t.trabajadorIds.add(w.id);
              onCambio();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: Row(
                children: [
                  Avatar(inicialesDe(w.nombreCompleto), colorPaleta(w.color), size: 22),
                  const SizedBox(width: 8),
                  Opacity(opacity: store.esApto(w, t) ? 1 : .55, child: Text(w.nombreCompleto)),
                ],
              ),
            ),
          ),
        const Divider(height: 8),
        MenuItemButton(
          onPressed: null,
          child: Text('Equipos · próximamente', style: TextStyle(color: P.textoSuave, fontSize: 12.5)),
        ),
      ],
      builder: (context, menu, _) => _CajaMenu(
        abierto: menu.isOpen,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        child: elegidos.isEmpty
            ? Text('Sin asignar', style: TextStyle(color: P.textoSuave))
            : Row(
                children: [
                  AvataresTrabajadores(t.trabajadorIds, size: 24),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      elegidos.map((w) => w.nombre).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Cuándo, sencillo: el día (abre el calendario) con la repetición al lado, y debajo la hora
/// o, con "Franja horaria", dos horas: de tal a tal.
class SelectorCuando extends StatefulWidget {
  final Tarea t;
  final VoidCallback onCambio;
  const SelectorCuando(this.t, this.onCambio, {super.key});

  @override
  State<SelectorCuando> createState() => _SelectorCuandoState();
}

class _SelectorCuandoState extends State<SelectorCuando> {
  late bool franja = widget.t.conFranja;
  Tarea get t => widget.t;

  void cambiar(void Function() f) {
    setState(f);
    widget.onCambio();
  }

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  /// Campo que abre un selector al pulsarlo (día u hora).
  Widget _campo(
    String label,
    String? valor,
    String vacio,
    IconData icono,
    VoidCallback onTap, {
    bool destacado = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      etiqueta(label),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: destacado ? P.moradoSuave.withValues(alpha: .6) : P.superficie,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: destacado ? P.morado.withValues(alpha: .45) : P.borde),
          ),
          child: Row(
            children: [
              Icon(icono, size: 18, color: destacado ? P.morado : P.textoSuave),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  valor ?? vacio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: valor == null ? FontWeight.w400 : FontWeight.w600,
                    color: valor == null ? P.textoSuave : (destacado ? P.moradoOscuro : P.texto),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<int?> _pedirHora(int? actual) async {
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (actual ?? 540) ~/ 60, minute: (actual ?? 540) % 60),
    );
    return h == null ? null : h.hour * 60 + h.minute;
  }

  @override
  Widget build(BuildContext context) {
    final d = t.proximo;
    final opciones = {
      Periodicidad.unica,
      Periodicidad.semanal,
      Periodicidad.mensual,
      Periodicidad.anual,
      t.periodicidad,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Día + repetición.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _campo(
                  t.esPlantilla ? 'Primer día' : 'Día',
                  d == null
                      ? null
                      : '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]} · ${relativo(d).toLowerCase()}',
                  'Elegir día',
                  Icons.calendar_month_rounded,
                  () async {
                    final x = await showDatePicker(
                      context: context,
                      initialDate: d ?? hoy(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (x != null) cambiar(() => t.proximo = x);
                  },
                  destacado: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    etiqueta('Se repite'),
                    DropdownButtonFormField<Periodicidad>(
                      isExpanded: true,
                      initialValue: t.periodicidad,
                      items: [
                        for (final p in Periodicidad.values.where(opciones.contains))
                          DropdownMenuItem(value: p, child: Text(p.etiqueta)),
                      ],
                      onChanged: (v) => cambiar(() => t.periodicidad = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Hora exacta, o franja (de tal a tal).
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!franja)
                Expanded(
                  child: _campo(
                    'Hora',
                    t.inicioMin == null ? null : hhmm(t.inicioMin!),
                    'Elegir hora',
                    Icons.schedule_rounded,
                    () async {
                      final m = await _pedirHora(t.inicioMin);
                      if (m != null) cambiar(() => t.inicioMin = m);
                    },
                  ),
                )
              else ...[
                Expanded(
                  child: _campo(
                    'Desde',
                    t.ventanaDesdeMin == null ? null : hhmm(t.ventanaDesdeMin!),
                    'Hora de inicio',
                    Icons.schedule_rounded,
                    () async {
                      final m = await _pedirHora(t.ventanaDesdeMin);
                      if (m != null) {
                        cambiar(() {
                          t.ventanaDesdeMin = m;
                          t.inicioMin = m;
                          if ((t.ventanaHastaMin ?? 0) <= m) t.ventanaHastaMin = m + 60;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _campo(
                    'Hasta',
                    t.ventanaHastaMin == null ? null : hhmm(t.ventanaHastaMin!),
                    'Hora de fin',
                    Icons.schedule_rounded,
                    () async {
                      final m = await _pedirHora(t.ventanaHastaMin);
                      if (m != null) cambiar(() => t.ventanaHastaMin = m);
                    },
                  ),
                ),
              ],
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: franja ? P.moradoSuave : null,
                    side: BorderSide(color: franja ? P.morado.withValues(alpha: .5) : P.borde),
                  ),
                  onPressed: () => cambiar(() {
                    franja = !franja;
                    if (franja) {
                      t.ventanaDesdeMin = t.inicioMin ?? 8 * 60;
                      t.ventanaHastaMin = t.ventanaDesdeMin! + 4 * 60;
                      t.inicioMin = t.ventanaDesdeMin;
                    } else {
                      t.ventanaDesdeMin = null;
                      t.ventanaHastaMin = null;
                    }
                  }),
                  child: Text(franja ? 'Hora exacta' : 'Franja horaria'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Color del bloque en el calendario: circulitos con colores habituales y "+" para cualquier otro.
/// El primero es "Automático": el color de su tipo.
class SelectorColorTarea extends StatelessWidget {
  final Tarea t;
  final VoidCallback onCambio;
  const SelectorColorTarea(this.t, this.onCambio, {super.key});

  static const colores = [
    0xFF7C3AED,
    0xFF2563EB,
    0xFF0EA5E9,
    0xFF0D9488,
    0xFF16A34A,
    0xFF84CC16,
    0xFFCA8A04,
    0xFFEA580C,
    0xFFDC2626,
    0xFFDB2777,
    0xFF64748B,
  ];

  Widget _circulo(Color c, bool sel, VoidCallback onTap, {Widget? dentro, String? tip}) => Tooltip(
    message: tip ?? '',
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: sel ? P.superficie : Colors.transparent, width: 2),
          boxShadow: sel ? [BoxShadow(color: c, spreadRadius: 2)] : null,
        ),
        child: dentro ?? (sel ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null),
      ),
    ),
  );

  Future<void> _otro(BuildContext context) async {
    // Paleta amplia: 12 tonos × 4 luminosidades.
    final todos = [
      for (final l in [.35, .45, .55, .7])
        for (var h = 0; h < 360; h += 30) HSLColor.fromAHSL(1, h.toDouble(), .7, l).toColor(),
    ];
    final elegido = await showDialog<Color>(
      context: context,
      builder: (c) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Otro color',
                style: TextStyle(fontFamily: P.titulos, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 12 * 34,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final x in todos) _circulo(x, false, () => Navigator.pop(c, x))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null) {
      t.color = elegido.toARGB32();
      onCambio();
    }
  }

  @override
  Widget build(BuildContext context) {
    final propio = t.color != null && !colores.contains(t.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          etiqueta('Color en el calendario'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _circulo(
                tipoDe(t.tipo).color,
                t.color == null,
                () {
                  t.color = null;
                  onCambio();
                },
                tip: 'Automático (color del tipo)',
                dentro: t.color == null
                    ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                    : const Text(
                        'A',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
              ),
              for (final c in colores)
                _circulo(Color(c), t.color == c, () {
                  t.color = c;
                  onCambio();
                }),
              if (propio) _circulo(Color(t.color!), true, () {}),
              Tooltip(
                message: 'Otro color',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _otro(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: P.borde, width: 1.5),
                    ),
                    child: Icon(Icons.add_rounded, size: 16, color: P.textoSuave),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
