import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/gemini_config.dart';

class SpeciesIdentification {
  const SpeciesIdentification({
    required this.identified,
    this.commonName,
    this.scientificName,
    this.description,
    this.type,
    this.confidence = 'baja',
    this.reason,
  });

  final bool identified;
  final String? commonName;
  final String? scientificName;
  final String? description;
  final String? type;
  final String confidence;
  final String? reason;
}

class SpeciesIdentificationException implements Exception {
  SpeciesIdentificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

// 'gemini-flash-latest' pasó a apuntar a un modelo con cuota gratuita de
// solo 20 peticiones/día (se agota en minutos). 'gemini-flash-lite-latest'
// tiene cuota gratuita mucho más alta y sigue siendo Alias — no se fija a
// una versión concreta que luego pueda perder cuota, como ya pasó antes.
const _model = 'gemini-flash-lite-latest';
const _endpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

const _prompt = '''
Eres un naturalista experto en fauna y flora de Colombia, especialmente del
departamento de Cundinamarca. Observa la imagen y responde ÚNICAMENTE con un
JSON válido (sin texto adicional, sin marcado de código), con exactamente esta
forma:

{
  "identificado": true o false,
  "nombre_comun": "nombre común en español, o null",
  "nombre_cientifico": "nombre científico, o null",
  "tipo": "ave", "planta", "insecto" u "otro" (o null),
  "confianza": "alta", "media" o "baja",
  "descripcion": "1 o 2 frases sobre la especie y su hábitat en Cundinamarca, o null",
  "motivo": "si identificado es false, explica brevemente por qué (ej: no se ve un ser vivo, imagen borrosa)"
}
''';

/// Compara la especie objetivo de un desafío con lo que identificó la IA.
/// Coincidencia por texto (insensible a mayúsculas), sobre nombre común,
/// científico o tipo.
bool especieCoincide(String especieObjetivo, SpeciesIdentification ia) {
  final objetivo = especieObjetivo.toLowerCase().trim();
  if (objetivo.isEmpty) return false;
  final candidatos = [
    ia.commonName,
    ia.scientificName,
    ia.type,
  ].whereType<String>().map((s) => s.toLowerCase().trim());
  return candidatos.any(
    (c) => c.isNotEmpty && (c.contains(objetivo) || objetivo.contains(c)),
  );
}

/// Espera que pide la API en un 429 (`retryDelay: "7s"`), acotada para no
/// dejar al usuario mirando un spinner eterno.
Duration? _esperaSugerida(String cuerpo) {
  final match = RegExp(r'"retryDelay"\s*:\s*"(\d+)s"').firstMatch(cuerpo);
  if (match == null) return null;
  final segundos = int.tryParse(match.group(1)!);
  if (segundos == null) return null;
  return Duration(seconds: segundos.clamp(1, 15));
}

/// true si el 429 es por cuota DIARIA agotada (`...PerDay...`). Reintentar
/// no sirve de nada en ese caso: la cuota no vuelve hasta el día siguiente,
/// así que hay que fallar rápido en vez de dejar la UI "cargando" varias
/// rondas de espera para nada.
bool _esCuotaDiariaAgotada(String cuerpo) => cuerpo.contains('PerDay');

class EspecieIAService {
  /// Número de envíos a Gemini antes de rendirse ante un 429/503 temporal.
  /// 2 en vez de 3: cada intento puede tardar hasta 20s, y no tiene sentido
  /// hacer esperar al explorador más de medio minuto por una foto.
  static const _maxIntentos = 2;

  Future<SpeciesIdentification> identify(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    if (geminiApiKey.isEmpty || geminiApiKey.startsWith('PON_AQUI')) {
      throw SpeciesIdentificationException(
        'Falta configurar la clave de Gemini en lib/config/gemini_config.dart',
      );
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
    });

    final response = await _enviarConReintentos(body);

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>;
      final content = candidates.first as Map<String, dynamic>;
      final parts =
          (content['content'] as Map<String, dynamic>)['parts']
              as List<dynamic>;
      final rawText = (parts.first as Map<String, dynamic>)['text'] as String;

      final cleanedText = rawText
          .trim()
          .replaceFirst(RegExp(r'^```json'), '')
          .replaceFirst(RegExp(r'^```'), '')
          .replaceFirst(RegExp(r'```$'), '')
          .trim();

      final json = jsonDecode(cleanedText) as Map<String, dynamic>;

      return SpeciesIdentification(
        identified: json['identificado'] as bool? ?? false,
        commonName: json['nombre_comun'] as String?,
        scientificName: json['nombre_cientifico'] as String?,
        type: json['tipo'] as String?,
        confidence: json['confianza'] as String? ?? 'baja',
        description: json['descripcion'] as String?,
        reason: json['motivo'] as String?,
      );
    } catch (e) {
      debugPrint(
        'No se pudo interpretar la respuesta de Gemini: ${response.body}',
      );
      throw SpeciesIdentificationException(
        'No se pudo interpretar la respuesta de la IA. Intenta de nuevo.',
      );
    }
  }

  /// Envía la petición reintentando los errores temporales.
  ///
  /// El plan gratuito de Gemini limita las peticiones por minuto y responde
  /// 429; casi siempre basta con esperar unos segundos, así que reintentamos
  /// en vez de hacer fallar el desafío del explorador.
  Future<http.Response> _enviarConReintentos(String body) async {
    Object? ultimoFallo;

    for (var intento = 1; intento <= _maxIntentos; intento++) {
      final http.Response response;
      try {
        response = await http
            .post(
              Uri.parse('$_endpoint?key=$geminiApiKey'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        ultimoFallo = e;
        if (intento == _maxIntentos) {
          throw SpeciesIdentificationException(
            'No se pudo conectar con la IA. Revisa tu conexión a internet.',
          );
        }
        await Future<void>.delayed(Duration(seconds: 2 * intento));
        continue;
      }

      if (response.statusCode == 200) return response;

      debugPrint('Gemini error ${response.statusCode}: ${response.body}');

      // Cuota diaria agotada: reintentar es inútil, mejor avisar ya.
      if (response.statusCode == 429 && _esCuotaDiariaAgotada(response.body)) {
        throw SpeciesIdentificationException(
          'Se agotó la cuota gratuita de la IA por hoy. '
          'Vuelve a intentarlo más tarde.',
        );
      }

      final esTemporal =
          response.statusCode == 429 || response.statusCode >= 500;
      if (esTemporal && intento < _maxIntentos) {
        final espera =
            _esperaSugerida(response.body) ?? Duration(seconds: 3 * intento);
        await Future<void>.delayed(espera);
        continue;
      }

      throw SpeciesIdentificationException(_mensajeDeError(response));
    }

    throw SpeciesIdentificationException(
      'La IA no respondió tras $_maxIntentos intentos. '
      'Detalle: $ultimoFallo',
    );
  }

  String _mensajeDeError(http.Response response) {
    switch (response.statusCode) {
      case 400:
        return 'La clave de Gemini no es válida. '
            'Revisa lib/config/gemini_config.dart';
      case 403:
        return 'La clave de Gemini no tiene permiso para usar este modelo.';
      case 429:
        return 'Alcanzaste el límite de peticiones gratuitas de la IA. '
            'Espera un minuto y vuelve a intentarlo.';
      default:
        return response.statusCode >= 500
            ? 'El servicio de IA está caído en este momento. '
                  'Intenta de nuevo en unos minutos.'
            : 'La IA no pudo responder (código ${response.statusCode}). '
                  'Intenta de nuevo.';
    }
  }
}
