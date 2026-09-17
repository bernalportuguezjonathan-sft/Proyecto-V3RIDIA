import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/observation.dart';

/// Los topes con los que el cliente recorta antes de escribir.
///
/// Tienen que seguir siendo los mismos que valida `firestore.rules`: si el
/// cliente escribe algo más largo de lo que la regla admite, el avistamiento
/// se pierde con un permission-denied que el explorador no entiende.
void main() {
  group('recortarCampo', () {
    test('deja intacto lo que ya cabe', () {
      expect(
        recortarCampo('Colibrí chillón', topeCommonName),
        'Colibrí chillón',
      );
    });

    test('recorta lo que se pasa', () {
      final largo = 'x' * 600;
      expect(recortarCampo(largo, topeNotes).length, topeNotes);
    });

    test('el resultado nunca supera el tope', () {
      for (final tope in [topeCommonName, topeNotes, topeType]) {
        expect(recortarCampo('a' * 1000, tope).length, lessThanOrEqualTo(tope));
      }
    });

    test('no deja un espacio suelto al final del corte', () {
      final texto = '${'a' * 99} bcdef';
      expect(recortarCampo(texto, 100).endsWith(' '), isFalse);
    });

    test('no parte una letra por la mitad', () {
      // Un emoji ocupa dos unidades UTF-16: cortar entre ellas dejaría medio
      // carácter y un texto inválido que Firestore rechaza.
      final texto = 'a🐸b';
      final corte = recortarCampo(texto, 2);
      expect(corte, 'a');
      expect(corte.codeUnits.every((u) => u < 0xD800 || u > 0xDFFF), isTrue);
    });

    test('una descripción larga de la IA cabe tras recortarla', () {
      // El caso real: Gemini devuelve más texto del que pidió el prompt.
      final descripcion =
          'Planta herbácea perenne de hojas grandes y coriáceas. ' * 20;
      expect(descripcion.length, greaterThan(topeNotes));
      expect(
        recortarCampo(descripcion, topeNotes).length,
        lessThanOrEqualTo(topeNotes),
      );
    });
  });

  group('textoONull', () {
    test('null sigue siendo null', () {
      expect(textoONull(null), isNull);
    });

    test('la cadena vacía pasa a null', () {
      // La IA puede devolver "" en vez de null, y la regla exige que
      // commonName tenga al menos un carácter.
      expect(textoONull(''), isNull);
      expect(textoONull('   '), isNull);
    });

    test('limpia los espacios de los lados', () {
      expect(textoONull('  Garza Real  '), 'Garza Real');
    });
  });

  group('coordenadaValida', () {
    test('deja pasar un punto real de la Sabana', () {
      expect(coordenadaValida(4.7235, maximo: 90), 4.7235);
      expect(coordenadaValida(-74.2255, maximo: 180), -74.2255);
    });

    test('descarta lo que está fuera del planeta', () {
      expect(coordenadaValida(95, maximo: 90), isNull);
      expect(coordenadaValida(-200, maximo: 180), isNull);
    });

    test('descarta NaN e infinitos', () {
      expect(coordenadaValida(double.nan, maximo: 90), isNull);
      expect(coordenadaValida(double.infinity, maximo: 90), isNull);
      expect(coordenadaValida(double.negativeInfinity, maximo: 180), isNull);
    });

    test('null sigue siendo null', () {
      expect(coordenadaValida(null, maximo: 90), isNull);
    });

    test('los extremos exactos valen', () {
      expect(coordenadaValida(90, maximo: 90), 90);
      expect(coordenadaValida(-180, maximo: 180), -180);
    });
  });
}
