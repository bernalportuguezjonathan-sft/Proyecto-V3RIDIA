import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/gemini_key.dart';
import 'huella_foto.dart';
import 'repositorio_u.dart';

/// Resultado de identificar una foto.
///
/// NOTA (2026-08-26): `identify()` llama a Gemini DIRECTO desde el cliente,
/// de forma temporal. La clave (`lib/config/gemini_config.dart`) vuelve a
/// viajar dentro de la app mientras el proyecto no tenga el plan Blaze de
/// Firebase activo — sin Blaze no se pueden desplegar las Cloud Functions
/// que la sacan de ahí. La versión segura ya existe, probada, en
/// `functions/` (ver [[project-veridia-backend]] en la memoria del
/// proyecto): cuando se active Blaze, hay que volver a apuntar esta clase a
/// `identificarEspecie`/`guardarObservacion` en vez de llamar a Gemini y a
/// Firestore directo.
///
/// AMPLIADO (2026-08-28): eso vale para el APK, que no se publica. En WEB la
/// clave ya no se compila: el sitio está publicado y un bundle público la
/// deja a la vista de cualquiera. Ver `lib/config/gemini_key.dart`, que
/// resuelve la clave y explica por qué en web queda vacía.
class SpeciesIdentification {
  const SpeciesIdentification({
    required this.identified,
    required this.sha256,
    this.commonName,
    this.scientificName,
    this.description,
    this.type,
    this.confidence = 'baja',
    this.reason,
  });

  final bool identified;

  /// Huella exacta de la foto (sha256). Se usa para marcarla como usada en
  /// `HuellaFotoService` y así no se pueda reutilizar en otra captura.
  final String sha256;

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

/// La foto ya se usó antes (exacta o "prácticamente igual" a una anterior).
class FotoDuplicadaException implements Exception {
  FotoDuplicadaException(this.message);

  final String message;

  @override
  String toString() => message;
}

// 'gemini-flash-lite-latest' pasó a apuntar a un modelo con cuota gratuita de
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
  "tipo": uno de "ave", "mamifero", "reptil", "anfibio", "pez", "insecto",
          "aracnido", "planta", "hongo" u "otro" (o null),
  "confianza": "alta", "media" o "baja",
  "descripcion": "1 o 2 frases sobre la especie y su hábitat en Cundinamarca, o null",
  "motivo": "si identificado es false, explica brevemente por qué (ej: no se ve un ser vivo, imagen borrosa)"
}
''';

/// Palabras que no aportan nada al comparar nombres de especies.
const _palabrasVacias = {'de', 'del', 'la', 'el', 'los', 'las', 'un', 'una'};

/// Parte un nombre en palabras comparables: minúsculas, sin tildes y sin
/// signos. "Perro doméstico (Raza Golden Retriever)" ->
/// [perro, domestico, raza, golden, retriever].
List<String> _palabrasDe(String texto) {
  const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sinTilde = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caracter = String.fromCharCode(rune);
    final i = conTilde.indexOf(caracter);
    buffer.write(i >= 0 ? sinTilde[i] : caracter);
  }
  return buffer
      .toString()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((p) => p.isNotEmpty && !_palabrasVacias.contains(p))
      .toList();
}

/// Formas singular/plural de una palabra.
///
/// Se devuelven TODAS las variantes en vez de "corregir" a una sola: recortar
/// de más rompería casos como "aves" -> "av", que ya no coincidiría con "ave".
Set<String> _formasDe(String palabra) {
  final formas = {palabra};
  if (palabra.length > 3 && palabra.endsWith('es')) {
    formas.add(palabra.substring(0, palabra.length - 2));
  }
  if (palabra.length > 2 && palabra.endsWith('s')) {
    formas.add(palabra.substring(0, palabra.length - 1));
  }
  return formas;
}

/// Compara la especie objetivo de un desafío con lo que identificó la IA,
/// sobre el nombre común, el científico o el tipo.
///
/// Compara palabra por palabra y no cadenas completas. Con `contains` sobre la
/// cadena entera, un desafío de "Perros" no daba por válido un
/// "Perro doméstico (Raza Golden Retriever)" por la simple `s` del plural,
/// mientras que "Aves" sí colaba porque contiene literalmente "ave".
bool especieCoincide(String especieObjetivo, SpeciesIdentification ia) {
  final objetivo = _palabrasDe(especieObjetivo);
  if (objetivo.isEmpty) return false;

  bool coincideCon(String? candidato) {
    if (candidato == null) return false;
    final palabras = _palabrasDe(candidato);
    if (palabras.isEmpty) return false;
    final formasCandidato = palabras.expand(_formasDe).toSet();
    // Deben aparecer TODAS las palabras del objetivo: así un desafío de
    // "Garza Real" no se da por cumplido con una "Garza Morena".
    return objetivo.every((p) => _formasDe(p).any(formasCandidato.contains));
  }

  return coincideCon(ia.commonName) ||
      coincideCon(ia.scientificName) ||
      coincideCon(ia.type);
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

  /// Identifica una foto con Gemini.
  ///
  /// Antes de gastar la petición de IA revisa si la foto ya se usó (huella
  /// sha256 + ahash sobre `users/{uid}/fotos`): así una imagen repetida no
  /// vuelve a analizarse ni a sumar Veridiums. [origen] es solo descriptivo
  /// ("una observación", "el desafío X"...) para ese registro de huellas.
  Future<SpeciesIdentification> identify(
    Uint8List imageBytes,
    String mimeType, {
    String? origen,
  }) async {
    if (faltaClaveGemini) {
      // Dos mensajes distintos a propósito: en web es una decisión de
      // seguridad (la clave no se compila ahí, ver config/gemini_key.dart) y
      // quien lo lee es un explorador, no quien programa; en móvil sí es algo
      // que hay que configurar.
      throw SpeciesIdentificationException(
        kIsWeb
            ? 'La identificación con IA no está disponible en la versión web. '
                  'Usa la app de Android para identificar especies.'
            : 'Falta configurar la clave de Gemini en '
                  'lib/config/gemini_config.dart',
      );
    }

    final huella = await calcularHuella(imageBytes);
    final perfil = UserRepository.instance.currentUser.value;
    if (perfil != null) {
      final duplicada = await HuellaFotoService.instance.buscarDuplicado(
        userId: perfil.userId,
        huella: huella,
      );
      if (duplicada != null) {
        throw FotoDuplicadaException(duplicada.mensaje);
      }
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

    final SpeciesIdentification resultado;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
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

      resultado = SpeciesIdentification(
        identified: json['identificado'] as bool? ?? false,
        sha256: huella.sha256,
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

    // Se marca usada YA (identifique algo o no): así una foto borrosa que
    // Gemini rechaza tampoco se puede reintentar en bucle gastando cuota.
    if (perfil != null) {
      await HuellaFotoService.instance.registrar(
        userId: perfil.userId,
        huella: huella,
        origen: origen ?? 'la Cámara IA',
      );
    }

    return resultado;
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
              Uri.parse(_endpoint),
              // La clave va en la CABECERA, no en la query string: las URLs
              // acaban en los logs de proxies, en el historial del navegador
              // y en las trazas de error, y ahí la clave quedaría a la vista.
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': geminiApiKey,
              },
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
