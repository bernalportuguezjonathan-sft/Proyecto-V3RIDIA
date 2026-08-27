import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/services/ubicacion_foto.dart';

/// Ubicación real del avistamiento: sale del EXIF de la foto y solo cae al
/// GPS del celular si la imagen no la trae. Es lo que evita que una foto
/// tomada en casa quede marcada donde se subió.
void main() {
  group('gradosDecimales', () {
    test('convierte grados, minutos y segundos a decimal', () {
      // 4° 42' 43.2" N = 4.712
      expect(gradosDecimales([4, 42, 43.2], 'N'), closeTo(4.712, 0.0001));
    });

    test('el hemisferio sur y el oeste van en negativo', () {
      expect(gradosDecimales([74, 12, 0], 'W'), closeTo(-74.2, 0.0001));
      expect(gradosDecimales([4, 0, 0], 'S'), closeTo(-4.0, 0.0001));
    });

    test('acepta la referencia en minúscula o con espacios', () {
      expect(gradosDecimales([74, 0, 0], ' w '), closeTo(-74.0, 0.0001));
    });

    test('sin referencia asume positivo', () {
      expect(gradosDecimales([4, 0, 0], null), closeTo(4.0, 0.0001));
    });

    test('rechaza una lista incompleta', () {
      expect(gradosDecimales([4, 42], 'N'), isNull);
    });

    test('rechaza coordenadas imposibles', () {
      expect(gradosDecimales([200, 0, 0], 'N'), isNull);
    });
  });

  group('fechaExif', () {
    test('interpreta el formato con dos puntos en la fecha', () {
      final fecha = fechaExif('2026:08:24 15:04:31');
      expect(fecha, DateTime(2026, 8, 24, 15, 4, 31));
    });

    test('devuelve null con basura o vacío', () {
      expect(fechaExif(null), isNull);
      expect(fechaExif(''), isNull);
      expect(fechaExif('no es una fecha'), isNull);
    });

    test('descarta el 0000:00:00 que ponen algunas cámaras', () {
      expect(fechaExif('0000:00:00 00:00:00'), isNull);
    });
  });

  group('UbicacionFoto', () {
    test('sin coordenadas no se puede ubicar en el mapa', () {
      const sinDatos = UbicacionFoto.desconocida();
      expect(sinDatos.tieneCoordenadas, isFalse);
      expect(sinDatos.etiqueta, 'Sin ubicación');
    });

    test('la etiqueta recorta a cuatro decimales', () {
      const ubicacion = UbicacionFoto(
        origen: OrigenUbicacion.foto,
        latitude: 4.712345678,
        longitude: -74.200987654,
      );
      expect(ubicacion.tieneCoordenadas, isTrue);
      expect(ubicacion.etiqueta, '4.7123, -74.2010');
    });

    test('distingue si el punto viene de la foto o del celular', () {
      const deLaFoto = UbicacionFoto(
        origen: OrigenUbicacion.foto,
        latitude: 4.7,
        longitude: -74.2,
      );
      const delCelular = UbicacionFoto(
        origen: OrigenUbicacion.dispositivo,
        latitude: 4.7,
        longitude: -74.2,
      );

      expect(deLaFoto.descripcionOrigen, contains('foto'));
      expect(delCelular.descripcionOrigen, contains('dispositivo'));
    });
  });
}
