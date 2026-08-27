import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:veridia_app/models/bird_zone.dart';
import 'package:veridia_app/models/observation.dart';

/// Búsqueda del mapa: además de las zonas, tiene que encontrar las fotos que
/// ya tomaron los exploradores y poder ubicarlas en su zona.
void main() {
  Observation observacion({
    String id = '1',
    String commonName = 'Garza real',
    String scientificName = 'Ardea alba',
    String location = 'Humedal',
    String notes = '',
    String? type,
    String? userDisplayName,
    double? lat,
    double? lng,
  }) {
    return Observation(
      id: id,
      commonName: commonName,
      scientificName: scientificName,
      location: location,
      notes: notes,
      dateTime: DateTime(2026, 8, 24),
      type: type,
      userDisplayName: userDisplayName,
      latitude: lat,
      longitude: lng,
    );
  }

  BirdZone zona({
    required String id,
    required double lat,
    required double lng,
  }) {
    return BirdZone(
      id: id,
      name: 'Zona $id',
      location: 'Mosquera',
      description: '',
      habitat: '',
      latitude: lat,
      longitude: lng,
      color: Colors.green,
      areaPoints: [
        LatLng(lat - 0.001, lng - 0.001),
        LatLng(lat + 0.001, lng - 0.001),
        LatLng(lat + 0.001, lng + 0.001),
        LatLng(lat - 0.001, lng + 0.001),
      ],
      species: const [],
    );
  }

  group('observacionCoincide', () {
    test('una búsqueda vacía deja pasar todo', () {
      expect(observacionCoincide(observacion(), '   '), isTrue);
    });

    test('encuentra por nombre común ignorando tildes y mayúsculas', () {
      final o = observacion(commonName: 'Tingua bogotana');
      expect(observacionCoincide(o, 'TINGUA'), isTrue);
      expect(observacionCoincide(o, 'bogotána'), isTrue);
    });

    test('encuentra por nombre científico, tipo y autor', () {
      final o = observacion(
        scientificName: 'Ardea alba',
        type: 'ave',
        userDisplayName: 'Samuel',
      );
      expect(observacionCoincide(o, 'ardea'), isTrue);
      expect(observacionCoincide(o, 'ave'), isTrue);
      expect(observacionCoincide(o, 'samuel'), isTrue);
    });

    test('no inventa coincidencias', () {
      expect(observacionCoincide(observacion(), 'colibrí'), isFalse);
    });

    test('tolera un error de tipeo razonable', () {
      final o = observacion(commonName: 'Garza real');
      expect(observacionCoincide(o, 'graza'), isTrue);
      expect(observacionCoincide(o, 'garsa'), isTrue);
    });

    test('encuentra escribiendo solo parte de la palabra', () {
      final o = observacion(commonName: 'Colibrí chillón');
      expect(observacionCoincide(o, 'colib'), isTrue);
    });
  });

  group('filtrarObservaciones', () {
    final lista = [
      observacion(id: '1', commonName: 'Garza real'),
      observacion(id: '2', commonName: 'Colibrí esmeralda'),
      observacion(id: '3', commonName: 'Tingua bogotana'),
    ];

    test('filtra por texto libre', () {
      final resultado = filtrarObservaciones(lista, query: 'colibri');
      expect(resultado.map((o) => o.id), ['2']);
    });

    test('el chip de especie acota además del texto', () {
      final resultado = filtrarObservaciones(lista, especie: 'Garza real');
      expect(resultado.map((o) => o.id), ['1']);
    });

    test('sin filtros devuelve todo', () {
      expect(filtrarObservaciones(lista).length, 3);
    });

    test('la búsqueda por especie también tolera errores de tipeo', () {
      final resultado = filtrarObservaciones(lista, especie: 'Graza real');
      expect(resultado.map((o) => o.id), ['1']);
    });
  });

  group('filterBirdZones', () {
    BirdZone zonaConEspecie(String nombreZona, String nombreEspecie) {
      return BirdZone(
        id: nombreZona,
        name: nombreZona,
        location: 'Mosquera',
        description: 'Zona de prueba',
        habitat: '',
        latitude: 4.7,
        longitude: -74.2,
        color: Colors.green,
        areaPoints: const [],
        species: [
          BirdSpecies(
            name: nombreEspecie,
            scientificName: 'Species testus',
            descriptionHabitat: '',
            emoji: '🐦',
            color: Colors.green,
            imageUrl: '',
          ),
        ],
      );
    }

    test('encuentra una zona aunque la especie se escriba con typo', () {
      final zonas = [
        zonaConEspecie('Humedal Gualí', 'Garza Real'),
        zonaConEspecie('Parque de la Sabana', 'Colibrí Chillón'),
      ];

      final resultado = filterBirdZones(zonas, query: 'graza');
      expect(resultado.map((z) => z.id), ['Humedal Gualí']);
    });

    test('sin coincidencias devuelve una lista vacía', () {
      final zonas = [zonaConEspecie('Humedal Gualí', 'Garza Real')];
      expect(filterBirdZones(zonas, query: 'jirafa'), isEmpty);
    });

    test('el chip de especie sigue siendo exacto', () {
      final zonas = [
        zonaConEspecie('Humedal Gualí', 'Garza Real'),
        zonaConEspecie('Parque de la Sabana', 'Garza Morena'),
      ];
      final resultado = filterBirdZones(zonas, selectedSpecies: 'Garza Real');
      expect(resultado.map((z) => z.id), ['Humedal Gualí']);
    });
  });

  group('zonaDePunto', () {
    final zonas = [
      zona(id: 'a', lat: 4.7000, lng: -74.2000),
      zona(id: 'b', lat: 4.8000, lng: -74.3000),
    ];

    test('un punto dentro del polígono cae en su zona', () {
      expect(zonaDePunto(zonas, 4.7005, -74.2005)?.id, 'a');
    });

    test('un punto cercano se asigna a la zona más próxima', () {
      // ~1 km al norte del centro de la zona "a": fuera del polígono pero
      // dentro del radio de cortesía.
      expect(zonaDePunto(zonas, 4.7090, -74.2000)?.id, 'a');
    });

    test('un punto lejano no pertenece a ninguna zona', () {
      expect(zonaDePunto(zonas, 6.2500, -75.5600), isNull);
    });

    test('el radio de cortesía es configurable', () {
      expect(zonaDePunto(zonas, 4.7090, -74.2000, radioKm: 0.1), isNull);
    });
  });

  group('zonaContiene', () {
    test('distingue dentro de fuera del polígono', () {
      final z = zona(id: 'a', lat: 4.7, lng: -74.2);
      expect(zonaContiene(z, 4.7, -74.2), isTrue);
      expect(zonaContiene(z, 4.75, -74.2), isFalse);
    });
  });
}
