import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// De dónde salieron las coordenadas de una observación.
enum OrigenUbicacion {
  /// Del EXIF de la foto: donde de verdad se tomó.
  foto,

  /// Del GPS del celular en el momento de registrarla.
  dispositivo,

  /// No se pudo determinar.
  desconocida,
}

/// Dónde y cuándo se tomó una foto.
class UbicacionFoto {
  const UbicacionFoto({
    required this.origen,
    this.latitude,
    this.longitude,
    this.fecha,
  });

  const UbicacionFoto.desconocida()
    : origen = OrigenUbicacion.desconocida,
      latitude = null,
      longitude = null,
      fecha = null;

  final OrigenUbicacion origen;
  final double? latitude;
  final double? longitude;

  /// Fecha de captura según el EXIF, o null si la foto no la trae.
  final DateTime? fecha;

  bool get tieneCoordenadas => latitude != null && longitude != null;

  /// Texto corto para mostrarle al explorador de dónde salió el punto.
  String get descripcionOrigen => switch (origen) {
    OrigenUbicacion.foto => 'Ubicación tomada de la foto',
    OrigenUbicacion.dispositivo => 'Ubicación actual del dispositivo',
    OrigenUbicacion.desconocida => 'Sin ubicación',
  };

  String get etiqueta => tieneCoordenadas
      ? '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}'
      : 'Sin ubicación';
}

/// Convierte los grados/minutos/segundos del EXIF a grados decimales.
///
/// El EXIF guarda la latitud como tres fracciones (34/1, 12/1, 3456/100) y la
/// referencia por separado ('N'/'S'), así que hay que rearmar el número y
/// aplicarle el signo a mano.
double? gradosDecimales(List<double> dms, String? referencia) {
  if (dms.length < 3) return null;
  final valor = dms[0] + dms[1] / 60 + dms[2] / 3600;
  if (valor.isNaN || valor.isInfinite) return null;

  final ref = (referencia ?? '').trim().toUpperCase();
  final negativo = ref.startsWith('S') || ref.startsWith('W');
  final signo = negativo ? -valor : valor;

  // Un valor fuera de rango es un EXIF corrupto, no una coordenada.
  if (signo.abs() > 180) return null;
  return signo;
}

/// Interpreta la fecha de captura del EXIF ('2026:08:24 15:04:31').
///
/// No es ISO 8601: usa dos puntos también en la fecha, así que `DateTime.parse`
/// la rechaza.
DateTime? fechaExif(String? crudo) {
  if (crudo == null) return null;
  final match = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(crudo.trim());
  if (match == null) return null;

  final numeros = [
    for (var i = 1; i <= 6; i++) int.tryParse(match.group(i)!) ?? 0,
  ];
  if (numeros[0] < 1990) return null;

  try {
    return DateTime(
      numeros[0],
      numeros[1],
      numeros[2],
      numeros[3],
      numeros[4],
      numeros[5],
    );
  } catch (_) {
    return null;
  }
}

/// Lee dónde y cuándo se tomó una foto a partir de sus bytes.
///
/// Devuelve una ubicación desconocida si la imagen no trae EXIF: pasa con las
/// capturas de pantalla, con las fotos que se reenvían por mensajería (que
/// borran los metadatos) y con cualquier imagen que el propio selector haya
/// recomprimido.
Future<UbicacionFoto> ubicacionDesdeExif(Uint8List bytes) async {
  try {
    final tags = await readExifFromBytes(bytes);
    if (tags.isEmpty) return const UbicacionFoto.desconocida();

    final fecha =
        fechaExif(tags['EXIF DateTimeOriginal']?.printable) ??
        fechaExif(tags['Image DateTime']?.printable);

    final lat = _coordenada(tags, 'GPS GPSLatitude', 'GPS GPSLatitudeRef');
    final lng = _coordenada(tags, 'GPS GPSLongitude', 'GPS GPSLongitudeRef');
    if (lat == null || lng == null) {
      return UbicacionFoto(origen: OrigenUbicacion.desconocida, fecha: fecha);
    }

    return UbicacionFoto(
      origen: OrigenUbicacion.foto,
      latitude: lat,
      longitude: lng,
      fecha: fecha,
    );
  } catch (e) {
    debugPrint('No se pudo leer el EXIF de la foto: $e');
    return const UbicacionFoto.desconocida();
  }
}

double? _coordenada(Map<String, IfdTag> tags, String clave, String claveRef) {
  final valores = tags[clave]?.values;
  if (valores == null) return null;

  final numeros = <double>[];
  for (final valor in valores.toList()) {
    if (valor is Ratio) {
      if (valor.denominator == 0) return null;
      numeros.add(valor.numerator / valor.denominator);
    } else if (valor is num) {
      numeros.add(valor.toDouble());
    }
  }
  return gradosDecimales(numeros, tags[claveRef]?.printable);
}

/// Ubicación de una observación: primero la de la foto, y solo si la foto no
/// la trae, la del dispositivo.
///
/// Este orden es el que arregla el problema de "tomé la foto en casa y la app
/// dice que la tomé donde la subí": el GPS del celular describe dónde está el
/// explorador AHORA, no dónde estaba el animal.
Future<UbicacionFoto> ubicacionDeObservacion(
  Uint8List bytes, {
  bool permitirDispositivo = true,
}) async {
  final deLaFoto = await ubicacionDesdeExif(bytes);
  if (deLaFoto.tieneCoordenadas) return deLaFoto;
  if (!permitirDispositivo) return deLaFoto;

  final posicion = await ubicacionDelDispositivo();
  if (posicion == null) {
    return UbicacionFoto(
      origen: OrigenUbicacion.desconocida,
      fecha: deLaFoto.fecha,
    );
  }

  return UbicacionFoto(
    origen: OrigenUbicacion.dispositivo,
    latitude: posicion.latitude,
    longitude: posicion.longitude,
    fecha: deLaFoto.fecha,
  );
}

/// GPS del dispositivo sin dejar al explorador esperando: si tarda más de 8
/// segundos se usa la última posición conocida, y si no hay ninguna, null.
Future<Position?> ubicacionDelDispositivo() async {
  try {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
