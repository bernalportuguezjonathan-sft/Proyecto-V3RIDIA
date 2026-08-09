import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/services/especie_ia_service.dart';

/// Esta es la lógica anti-trampa: decide si la foto que subió el explorador
/// realmente corresponde a la especie que pide el desafío.
void main() {
  SpeciesIdentification identificada({
    String? comun,
    String? cientifico,
    String? tipo,
  }) => SpeciesIdentification(
    identified: true,
    commonName: comun,
    scientificName: cientifico,
    type: tipo,
    confidence: 'alta',
  );

  group('especieCoincide', () {
    test('acepta el nombre común exacto', () {
      expect(
        especieCoincide('Garza Real', identificada(comun: 'Garza Real')),
        isTrue,
      );
    });

    test('ignora mayúsculas y espacios sobrantes', () {
      expect(
        especieCoincide('  garza real  ', identificada(comun: 'Garza Real')),
        isTrue,
      );
    });

    test('acepta cuando el objetivo es más general que lo identificado', () {
      // Desafío pide "Garza", la IA vio "Garza Real".
      expect(
        especieCoincide('Garza', identificada(comun: 'Garza Real')),
        isTrue,
      );
    });

    test('acepta por nombre científico', () {
      expect(
        especieCoincide(
          'Ardea alba',
          identificada(comun: 'Garza Real', cientifico: 'Ardea alba'),
        ),
        isTrue,
      );
    });

    test('acepta por tipo cuando el desafío es genérico', () {
      // Desafío "tómale foto a 10 aves".
      expect(
        especieCoincide('ave', identificada(comun: 'Copetón', tipo: 'ave')),
        isTrue,
      );
    });

    test('rechaza una especie distinta', () {
      expect(
        especieCoincide('Garza', identificada(comun: 'Colibrí chillón')),
        isFalse,
      );
    });

    test('rechaza cuando el desafío no define especie', () {
      expect(especieCoincide('', identificada(comun: 'Garza Real')), isFalse);
      expect(especieCoincide('   ', identificada(comun: 'Garza')), isFalse);
    });

    test('rechaza cuando la IA no devolvió ningún nombre', () {
      expect(especieCoincide('Garza', identificada()), isFalse);
    });
  });
}
