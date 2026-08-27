import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/services/geocodificacion.dart';

/// Búsqueda de lugares reales (no solo las zonas curadas del mapa), vía
/// Nominatim/OpenStreetMap. Solo se prueba el parseo: la petición de red en
/// sí no se ejecuta en los tests.
void main() {
  group('LugarEncontrado.fromJson', () {
    test('lee nombre, categoría y coordenadas de una respuesta típica', () {
      final lugar = LugarEncontrado.fromJson({
        'display_name': 'Laguna de la Herrera, Mosquera, Cundinamarca',
        'type': 'water',
        'class': 'natural',
        'lat': '4.7526',
        'lon': '-74.3193',
      });

      expect(lugar.nombre, 'Laguna de la Herrera, Mosquera, Cundinamarca');
      expect(lugar.categoria, 'water');
      expect(lugar.latitude, closeTo(4.7526, 0.0001));
      expect(lugar.longitude, closeTo(-74.3193, 0.0001));
    });

    test('usa la clase general si no viene el tipo específico', () {
      final lugar = LugarEncontrado.fromJson({
        'display_name': 'Funza, Cundinamarca',
        'class': 'boundary',
        'lat': '4.7169',
        'lon': '-74.2097',
      });
      expect(lugar.categoria, 'boundary');
    });

    test('sin nombre ni categoría, no revienta', () {
      final lugar = LugarEncontrado.fromJson({'lat': '0', 'lon': '0'});
      expect(lugar.nombre, isNotEmpty);
      expect(lugar.categoria, isNotEmpty);
    });
  });

  group('LugarBusquedaException', () {
    test('el mensaje es el texto que se le da', () {
      final error = LugarBusquedaException('No hay internet');
      expect(error.toString(), 'No hay internet');
    });
  });
}
