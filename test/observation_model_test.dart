import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/observation.dart';

/// Guarda el contrato con Firestore: si estos campos cambian de nombre, el
/// historial y los puntos del mapa dejan de cargar.
void main() {
  Observation crear({
    String? foto,
    double? lat,
    double? lng,
  }) => Observation(
    id: 'obs-1',
    commonName: 'Garza Real',
    scientificName: 'Ardea alba',
    location: '4.7120, -74.2000',
    notes: 'Vista en el humedal',
    dateTime: DateTime(2026, 8, 8, 15, 30),
    imagePath: foto,
    latitude: lat,
    longitude: lng,
    type: 'ave',
    userId: 'user-1',
    userDisplayName: 'Explorador',
  );

  test('sobrevive el viaje de ida y vuelta a Firestore', () {
    final original = crear(
      foto: 'https://ejemplo.com/foto.jpg',
      lat: 4.712,
      lng: -74.2,
    );
    final copia = Observation.fromMap('obs-1', original.toMap());

    expect(copia.id, original.id);
    expect(copia.commonName, original.commonName);
    expect(copia.scientificName, original.scientificName);
    expect(copia.location, original.location);
    expect(copia.notes, original.notes);
    expect(copia.dateTime, original.dateTime);
    expect(copia.imagePath, original.imagePath);
    expect(copia.latitude, original.latitude);
    expect(copia.longitude, original.longitude);
    expect(copia.type, original.type);
    expect(copia.userId, original.userId);
    expect(copia.userDisplayName, original.userDisplayName);
  });

  test('un documento vacío no rompe la app', () {
    final copia = Observation.fromMap('obs-x', {});

    expect(copia.commonName, 'Especie observada');
    expect(copia.scientificName, 'Sin confirmar');
    expect(copia.hasPhoto, isFalse);
    expect(copia.hasCoordinates, isFalse);
  });

  group('hasCoordinates', () {
    test('true solo con latitud y longitud', () {
      expect(crear(lat: 4.7, lng: -74.2).hasCoordinates, isTrue);
      expect(crear(lat: 4.7).hasCoordinates, isFalse);
      expect(crear().hasCoordinates, isFalse);
    });
  });

  group('hasPhoto', () {
    test('true solo si es una URL descargable', () {
      expect(crear(foto: 'https://ejemplo.com/f.jpg').hasPhoto, isTrue);
      // Ruta local de un celular: ya no sirve para mostrar la foto.
      expect(crear(foto: '/data/user/0/cache/IMG_123.jpg').hasPhoto, isFalse);
      expect(crear().hasPhoto, isFalse);
    });
  });
}
