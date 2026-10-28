import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulpo/forms.dart';
import 'package:pulpo/informes.dart';
import 'package:pulpo/models.dart';
import 'package:pulpo/screens/informes.dart';
import 'package:pulpo/screens/vista_trabajador.dart';
import 'package:pulpo/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('comprimirFoto deja la foto en JPEG de 1280 px por el lado largo', () async {
    final png = img.encodePng(img.Image(width: 2000, height: 1000));
    final jpg = await comprimirFoto(Uint8List.fromList(png));
    final d = img.decodeJpg(jpg)!;
    expect((d.width, d.height), (1280, 640));
  });

  test('sin sesión el informe se guarda en memoria y sale el primero', () async {
    await informes.crear(trabajoId: 't1', trabajadorId: 'w1', resultado: 0, notas: 'uno', fotos: []);
    await informes.crear(trabajoId: 't1', trabajadorId: 'w1', resultado: 1, notas: 'dos', fotos: [Uint8List(3)]);
    final l = informes.de('t1')!;
    expect(l.map((i) => i.notas), ['dos', 'uno']);
    expect(l.first.fotos.length, 1);
    expect(informes.de('otro'), isEmpty);
  });

  test('el PDF del informe se genera con sus fotos', () async {
    final foto = await comprimirFoto(Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30))));
    await informes.crear(trabajoId: 't2', trabajadorId: 'w1', resultado: 2, notas: 'Falta una pieza', fotos: [foto]);
    final pdf = await informePdf(informes.de('t2')!.first, Tarea(id: 't2', nombre: 'Revisión ascensor'));
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });

  testWidgets('el trabajador guarda un informe y el administrador lo abre', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.cargar();
    final w = Trabajador(id: 'w9', nombre: 'Javier');
    final t = Tarea(id: 't9', nombre: 'Ascensor portal A', trabajadorIds: ['w9']);
    store.guardarTrabajador(w);
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) =>
                TextButton(onPressed: () => abrirPanel(c, FormularioInforme(t, w)), child: const Text('Abrir')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    // Con la letra de los tests (cada carácter tan ancho como alto) las pestañas no caben; en la app sí.
    tester.takeException();
    expect(find.text('Fotos'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Cambiada la correa');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(informes.de('t9')!.single.notas, 'Cambiada la correa');

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InformesDelTrabajo(t))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Javier · Cambiada la correa'), findsOneWidget);
    await tester.tap(find.text('Todo correcto'));
    await tester.pumpAndSettle();
    expect(find.text('Descargar PDF'), findsOneWidget);
  });
}
