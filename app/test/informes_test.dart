import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulpo/informes.dart';
import 'package:pulpo/models.dart';

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
}
