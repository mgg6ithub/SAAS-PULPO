import '../models.dart';
import '../store.dart';
import 'activo.dart';
import 'plan.dart';

/// Simulación «Dominion»: cuatro activos pequeños (planta de secado, dos camiones y una estación de bombeo),
/// con pocos componentes y un mantenimiento por componente más uno del activo, alternando la criticidad.
/// Cada vez que se pulsa añade un juego nuevo (no borra nada) y crea la OT pendiente de cada mantenimiento.
int crearSimulacionDominion() {
  const tipos = TipoMantenimiento.values;
  var n = 0, desfase = -3;

  void activo(
    String icono,
    String tag,
    String nombre,
    String fabricante,
    double horas,
    List<(String icono, String tag, String nombre)> componentes,
    List<(String nombre, String descripcion, int dias)> mantenimientos,
  ) {
    final raiz = Activo(
      id: store.nuevoId(),
      icono: icono,
      tag: tag,
      nombre: nombre,
      fabricante: fabricante,
      horas: horas,
    );
    store.guardarActivo(raiz);
    final ids = [raiz.id];
    for (final (ic, t, nom) in componentes) {
      final c = Activo(id: store.nuevoId(), icono: ic, padreId: raiz.id, tag: '$tag-$t', nombre: nom, horas: horas);
      store.guardarActivo(c);
      ids.add(c.id);
    }
    // El primero es del activo entero; el resto, uno por componente.
    for (final (i, (nom, desc, dias)) in mantenimientos.indexed) {
      final p = PlanMantenimiento(
        id: store.nuevoId(),
        activoId: ids[i < ids.length ? i : 0],
        nombre: nom,
        descripcion: desc,
        tipo: tipos[n % 3],
        cadaDias: dias,
        proximo: masDias(hoy(), desfase),
      );
      store.guardarPlan(p);
      store.guardarTarea(p.ot(store.nuevoId()));
      n++;
      desfase += 2;
    }
  }

  activo(
    'fabrica',
    'PST-02',
    'Planta de secado térmico',
    'Andritz',
    6200,
    [
      ('dom_secador', 'SEC', 'Secadero rotativo'),
      ('dom_horno', 'QUE', 'Quemador'),
      ('dom_soplante', 'VEN', 'Ventilador de extracción'),
      ('pq_ciclon', 'CIC', 'Ciclón separador'),
    ],
    [
      ('Revisión general de la planta', 'Recorrido completo: fugas, ruidos, temperaturas y seguridad.', 30),
      ('Engrase de rodillos del secadero', 'Engrasar rodillos y comprobar la alineación del tambor.', 7),
      ('Limpieza del quemador', 'Limpiar boquilla y electrodos; revisar la llama.', 30),
      ('Vibraciones del ventilador', 'Medir vibraciones y revisar rodete y correas.', 15),
      ('Vaciado del ciclón', 'Vaciar la tolva y revisar el desgaste interior.', 7),
    ],
  );
  activo(
    'camion',
    'CAM-01',
    'Camión cisterna Volvo FH',
    'Volvo',
    182000,
    [
      ('motor', 'MOT', 'Motor'),
      ('herramientas', 'FRE', 'Frenos'),
      ('dom_cisterna', 'CIS', 'Cisterna'),
      ('bomba', 'BOM', 'Bomba de descarga'),
    ],
    [
      ('Revisión ITV', 'Preparar el camión para la inspección técnica.', 180),
      ('Cambio de aceite y filtros', 'Aceite de motor, filtro de aceite y de gasoil.', 90),
      ('Revisión de frenos', 'Pastillas, discos y circuito de aire.', 60),
      ('Estanqueidad de la cisterna', 'Comprobar bocas de carga, juntas y válvulas.', 30),
      ('Revisión de la bomba', 'Cierres, caudal y presión de descarga.', 30),
    ],
  );
  activo(
    'camion',
    'CAM-02',
    'Camión de vacío Scania R450',
    'Scania',
    143000,
    [
      ('motor', 'MOT', 'Motor'),
      ('herramientas', 'FRE', 'Frenos'),
      ('dom_aspiracion', 'ASP', 'Equipo de aspiración'),
      ('dom_hidrolimpieza', 'HID', 'Bomba de hidrolimpieza'),
    ],
    [
      ('Revisión ITV', 'Preparar el camión para la inspección técnica.', 180),
      ('Cambio de aceite y filtros', 'Aceite de motor, filtro de aceite y de gasoil.', 90),
      ('Revisión de frenos', 'Pastillas, discos y circuito de aire.', 60),
      ('Revisión de la bomba de vacío', 'Aceite de la bomba, filtros y válvula de alivio.', 30),
      ('Mangueras de alta presión', 'Revisar mangueras, racores y boquillas.', 15),
    ],
  );
  activo(
    'dom_bomba_crudo',
    'EB-01',
    'Estación de bombeo de crudo',
    'Sulzer',
    9800,
    [
      ('pq_bomba_centrifuga', 'B1', 'Bomba centrífuga principal'),
      ('pq_valvula_seguridad', 'VS', 'Válvula de seguridad'),
    ],
    [
      ('Revisión de la estación', 'Fugas, presiones y estado general.', 30),
      ('Cierre mecánico de la bomba', 'Revisar fugas del cierre y temperatura de cojinetes.', 30),
      ('Tarado de la válvula de seguridad', 'Comprobar y certificar la presión de tarado.', 365),
    ],
  );
  return n;
}
