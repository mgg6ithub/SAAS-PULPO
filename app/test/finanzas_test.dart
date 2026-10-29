import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulpo/finanzas.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/finanzas.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    store.guardarCliente(Cliente(id: 'c1', nombre: 'Comunidad Mayor 12', cif: 'H12345678'));
    store.guardarTarea(
      Tarea(id: 't1', clienteId: 'c1', nombre: 'Revisión ascensor', precio: 120, iva: 21, proximo: hoy()),
    );
  });

  test('importes en euros con punto de miles y coma decimal', () {
    expect(euros(1234.5), '1.234,50 €');
    expect(euros(0), '0,00 €');
    expect(euros(1000000), '1.000.000,00 €');
  });

  test('totales y estado de cobro', () {
    final d = Documento(
      lineas: [
        Linea(concepto: 'A', cantidad: 2, precio: 50),
        Linea(concepto: 'B', precio: 100, iva: 10),
      ],
      vence: masDias(hoy(), -1),
    );
    expect((d.base, d.cuota, d.total), (200.0, 31.0, 231.0));
    expect(d.estado, EstadoCobro.vencida);
    d.cobradaEl = hoy();
    expect(d.estado, EstadoCobro.cobrada);
    expect(Documento(tipo: TipoDocumento.presupuesto).estado, EstadoCobro.presupuesto);
  });

  test('lo hecho con precio se factura una sola vez, numerado y en el resumen', () async {
    store.marcarHecha(store.tarea('t1')!);
    final mes = DateTime(hoy().year, hoy().month);
    final nuevas = finanzas.porFacturar(mes);
    expect(nuevas.length, 1);
    expect(nuevas.single.total, closeTo(145.2, 1e-9));
    await finanzas.guardar(nuevas.single);
    expect(nuevas.single.codigo, 'F${hoy().year}-0001');
    expect(finanzas.porFacturar(mes), isEmpty, reason: 'no se cobra dos veces');
    expect(finanzas.resumen(mes).pendiente, closeTo(145.2, 1e-9));
    await finanzas.cobrar(nuevas.single, true);
    expect(finanzas.resumen(mes).cobrado, closeTo(145.2, 1e-9));
    final csv = finanzas.csv(finanzas.documentos!);
    expect(csv.split('\r\n')[1], contains('F${hoy().year}-0001;'));
    expect(csv, contains('"Comunidad Mayor 12";H12345678;120,00;25,20;145,20'));
    final pdf = await documentoPdf(nuevas.single);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    await finanzas.borrar(nuevas.single);
  });

  for (final ancho in [1440.0, 700.0, 420.0, 360.0]) {
    testWidgets('Finanzas cabe a $ancho px y crea una factura', (tester) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VistaFinanzas())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // En el móvil las pestañas son un desplegable: primero se abre.
      Future<void> elegir(String actual, String opcion) async {
        if (ancho < 700) {
          await tester.tap(find.text(actual));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(opcion).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await elegir('Facturas', 'Presupuestos');
      await elegir('Presupuestos', 'Facturas');

      final d = Documento(
        clienteId: 'c1',
        lineas: [Linea(concepto: 'Revisión', precio: 100)],
      );
      await tester.runAsync(() => finanzas.guardar(d));
      await tester.pumpAndSettle();
      expect(find.text('Comunidad Mayor 12'), findsOneWidget);
      await tester.tap(find.text('Comunidad Mayor 12'));
      await tester.pumpAndSettle();
      // Con la letra de los tests (cada carácter tan ancho como alto) algún texto largo no cabe; en la app sí.
      expect(find.textContaining('F${hoy().year}-0'), findsWidgets);
      Navigator.of(tester.element(find.textContaining('F${hoy().year}-0').last)).pop();
      await tester.pumpAndSettle();
      await finanzas.borrar(d);
    });
  }
}
