import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/services/huella_foto.dart';

/// Anti-repetición de fotos: la misma imagen no puede sumar progreso ni
/// Veridiums dos veces, ni siquiera reexportada o recomprimida.
void main() {
  /// Miniatura RGBA de 8x8 a partir de 64 niveles de gris.
  Uint8List rgbaDeGrises(List<int> grises) {
    final bytes = Uint8List(64 * 4);
    for (var i = 0; i < 64; i++) {
      bytes[i * 4] = grises[i];
      bytes[i * 4 + 1] = grises[i];
      bytes[i * 4 + 2] = grises[i];
      bytes[i * 4 + 3] = 255;
    }
    return bytes;
  }

  group('ahashDesdeRgba', () {
    test('mitad oscura y mitad clara da un hash estable', () {
      final grises = List<int>.generate(64, (i) => i < 32 ? 0 : 255);
      final hash = ahashDesdeRgba(rgbaDeGrises(grises));

      expect(hash.length, 16);
      // Los 32 primeros píxeles están bajo el promedio y los 32 últimos por
      // encima: ocho nibbles en 0 y ocho en f.
      expect(hash, '00000000ffffffff');
    });

    test('una imagen plana no enciende ningún bit', () {
      final hash = ahashDesdeRgba(rgbaDeGrises(List<int>.filled(64, 120)));
      expect(hash, '0' * 16);
    });

    test('devuelve vacío si no llegan 64 píxeles', () {
      expect(ahashDesdeRgba(Uint8List(10)), '');
    });
  });

  group('distanciaHamming', () {
    test('hashes idénticos distan 0', () {
      expect(distanciaHamming('00ff00ff00ff00ff', '00ff00ff00ff00ff'), 0);
    });

    test('cuenta los bits distintos, no los caracteres', () {
      // 1 vs 0 en el primer nibble = 1 bit.
      expect(distanciaHamming('1000000000000000', '0000000000000000'), 1);
      // f vs 0 = 4 bits.
      expect(distanciaHamming('f000000000000000', '0000000000000000'), 4);
    });

    test('longitudes distintas se tratan como totalmente diferentes', () {
      expect(distanciaHamming('ffff', 'ffffffffffffffff'), 64);
    });

    test('una foto recomprimida sigue bajo el umbral de parecido', () {
      // Un solo bit cambiado: dos versiones de la misma imagen.
      const original = 'ffff0000ffff0000';
      const recomprimida = 'ffff0000ffff0001';
      expect(
        distanciaHamming(original, recomprimida),
        lessThanOrEqualTo(HuellaFotoService.umbralParecido),
      );
    });

    test('dos fotos distintas superan el umbral', () {
      expect(
        distanciaHamming('ffffffff00000000', '00000000ffffffff'),
        greaterThan(HuellaFotoService.umbralParecido),
      );
    });
  });
}
