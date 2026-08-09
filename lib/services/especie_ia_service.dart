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

const _model = 'gemini-flash-latest';
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

class EspecieIAService {
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

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_endpoint?key=$geminiApiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw SpeciesIdentificationException(
        'No se pudo conectar con la IA. Revisa tu conexión a internet.',
      );
    }

    if (response.statusCode != 200) {
      debugPrint('Gemini error ${response.statusCode}: ${response.body}');
      throw SpeciesIdentificationException(
        response.statusCode == 400
            ? 'La clave de Gemini no es válida. Revisa lib/config/gemini_config.dart'
            : 'La IA no pudo responder (código ${response.statusCode}). Intenta de nuevo.',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>;
      final content = candidates.first as Map<String, dynamic>;
      final parts = (content['content'] as Map<String, dynamic>)['parts'] as List<dynamic>;
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
      debugPrint('No se pudo interpretar la respuesta de Gemini: ${response.body}');
      throw SpeciesIdentificationException(
        'No se pudo interpretar la respuesta de la IA. Intenta de nuevo.',
      );
    }
  }
}
