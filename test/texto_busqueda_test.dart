import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/utils/texto_busqueda.dart';

/// Búsqueda tolerante a errores de tipeo: la base de que "buscar zonas,
/// especies o fotos" encuentre lo que se quiere sin exigir ortografía
/// perfecta ni coincidencia literal.
void main() {
  group('normalizarTexto', () {
    test('quita tildes y pasa a minúsculas', () {
      expect(normalizarTexto('Colibrí Chillón'), 'colibri chillon');
      expect(normalizarTexto('Ñandú'), 'nandu');
    });
  });

  group('distanciaLevenshtein', () {
    test('cero para textos idénticos', () {
      expect(distanciaLevenshtein('garza', 'garza'), 0);
    });

    test('una trasposición de letras contiguas cuenta como un solo error', () {
      // El tipeo rápido en celular suele intercambiar dos letras seguidas;
      // sin tratarla aparte, "graza" quedaría a distancia 2 de "garza" (dos
      // sustituciones) y el margen de tolerancia normal no lo perdonaría.
      expect(distanciaLevenshtein('garza', 'graza'), 1);
    });

    test('una sola letra cambiada cuenta como un solo error', () {
      expect(distanciaLevenshtein('garza', 'garzo'), 1);
    });

    test('cuenta insertar o borrar una letra', () {
      expect(distanciaLevenshtein('colibri', 'colibrii'), 1);
      expect(distanciaLevenshtein('colibri', 'colibr'), 1);
    });

    test('con una cadena vacía, la distancia es el largo de la otra', () {
      expect(distanciaLevenshtein('', 'garza'), 5);
      expect(distanciaLevenshtein('garza', ''), 5);
    });
  });

  group('palabrasSimilares', () {
    test('palabras muy cortas exigen coincidencia exacta', () {
      expect(palabrasSimilares('un', 'en'), isFalse);
      expect(palabrasSimilares('ave', 'ave'), isTrue);
    });

    test('tolera un error de tipeo en palabras medianas', () {
      expect(palabrasSimilares('garza', 'graza'), isTrue);
      expect(palabrasSimilares('perro', 'perr'), isTrue);
    });

    test('una palabra dentro de otra cuenta como parecida', () {
      expect(palabrasSimilares('colibri', 'colibries'), isTrue);
    });

    test('palabras realmente distintas no se confunden', () {
      expect(palabrasSimilares('garza', 'sabila'), isFalse);
    });
  });

  group('coincideDifuso', () {
    test('una consulta vacía deja pasar todo', () {
      expect(coincideDifuso('Garza Real', ''), isTrue);
      expect(coincideDifuso('Garza Real', '   '), isTrue);
    });

    test('encuentra con errores de tipeo razonables', () {
      expect(coincideDifuso('Garza Real', 'graza'), isTrue);
      expect(coincideDifuso('Colibrí Chillón', 'colibries'), isTrue);
    });

    test('exige TODAS las palabras de la consulta', () {
      expect(coincideDifuso('Garza Real', 'garza morena'), isFalse);
      expect(coincideDifuso('Garza Real de la Sabana', 'garza real'), isTrue);
    });

    test('no inventa coincidencias entre palabras distintas', () {
      expect(coincideDifuso('Garza Real', 'sabila'), isFalse);
    });

    test('encuentra por sustring aunque la palabra no esté completa', () {
      expect(coincideDifuso('Laguna de la Herrera', 'lagun'), isTrue);
    });
  });
}
