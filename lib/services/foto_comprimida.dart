import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Una foto lista para viajar por la red, con el tipo que de verdad tiene.
class FotoParaEnviar {
  const FotoParaEnviar({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Lado al que se encoge la foto ANTES de mandarla a Gemini.
///
/// Gemini trocea las imágenes en mosaicos de 768px, así que una foto de 12
/// megapíxeles no le dice nada que no le diga una de 1024: lo único que
/// cambia es lo que tarda en subir. Lo mide en el lado CORTO (ver
/// [comprimirParaEnviar]), así que la foto acaba en algo como 1365x1024.
const int ladoParaIA = 1024;

/// Lado al que se encoge la foto que se GUARDA y se ve en el mapa.
///
/// Más generoso que el de la IA porque esta sí la mira una persona, pero muy
/// lejos del original: a pantalla completa en un celular no se distingue.
const int ladoParaGuardar = 1600;

/// Encoge y recomprime una foto para enviarla por red.
///
/// Por qué existe: la app tomaba la foto SIN tocar —a propósito, porque
/// `imageQuality` del selector borra el EXIF y con él se pierde dónde se tomó
/// de verdad— y esos mismos bytes de varios MB se mandaban tal cual a Gemini
/// y a Supabase. Eso costaba tres cosas a la vez:
///
/// - **Subida lenta.** Una foto de 4 MB tarda decenas de segundos en una red
///   de colegio. La subida a Supabase corta a los 25 s, así que una foto
///   grande con mala red se PERDÍA: la observación se guardaba sin imagen.
/// - **Tirón en pantalla.** Para la IA, esos bytes se pasan a base64 y de ahí
///   a JSON. Cada paso hace una copia y, en Dart, una cadena ocupa el doble
///   que sus caracteres: de 4 MB de foto salían decenas de MB vivos a la vez
///   y el hilo de la interfaz se quedaba parado mientras tanto.
/// - **Nada a cambio.** Ni Gemini ni la pantalla de un celular aprovechan esa
///   resolución.
///
/// El EXIF sigue a salvo: la ubicación se lee de los bytes ORIGINALES en
/// cuanto se elige la foto, mucho antes de pasar por aquí, y la huella
/// anti-repetición también. Esto solo toca la copia que sale por la red.
///
/// Si la compresión falla —formato raro, plataforma sin soporte— devuelve la
/// foto original tal cual: peor es no poder mandarla.
Future<FotoParaEnviar> comprimirParaEnviar(
  Uint8List original, {
  required int lado,
  int calidad = 85,
  String mimeOriginal = 'image/jpeg',
}) async {
  try {
    final comprimida = await FlutterImageCompress.compressWithList(
      original,
      minWidth: lado,
      minHeight: lado,
      quality: calidad,
      format: CompressFormat.jpeg,
    );

    // Dos motivos para quedarse con la original. Vacía significa que el
    // codificador no pudo con ella. Y si sale MÁS grande que la original (una
    // foto ya pequeña y muy optimizada, o un PNG con pocos colores) no hay
    // nada que ganar recomprimiéndola, solo calidad que perder.
    if (comprimida.isEmpty || comprimida.length >= original.length) {
      return FotoParaEnviar(bytes: original, mimeType: mimeOriginal);
    }

    return FotoParaEnviar(
      bytes: Uint8List.fromList(comprimida),
      mimeType: 'image/jpeg',
    );
  } catch (e) {
    debugPrint('No se pudo comprimir la foto, se envía original: $e');
    return FotoParaEnviar(bytes: original, mimeType: mimeOriginal);
  }
}
