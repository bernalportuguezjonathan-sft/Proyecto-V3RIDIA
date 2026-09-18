import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/gemini_key.dart';
import 'foto_comprimida.dart';
import 'huella_foto.dart';
import 'limite_intentos.dart';
import 'repositorio_u.dart';

/// Por qué una foto no se puede registrar como avistamiento.
enum MotivoRechazo {
  /// Sirve: es una especie de fauna, flora u hongo vista en vivo.
  ninguno,

  /// Es un ser vivo, pero la IA no reconoció qué especie (foto borrosa,
  /// demasiado lejos, sujeto tapado...).
  noIdentificada,

  /// Una persona, un objeto, comida, un vehículo... nada que pertenezca a un
  /// inventario de biodiversidad.
  noEsSerVivo,

  /// La foto de una pantalla o de una impresión: la especie puede ser real,
  /// pero el avistamiento no lo es.
  pantallaOImpresion,
}

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
    this.rechazo = MotivoRechazo.ninguno,
  });

  /// true solo si la foto sirve para registrar un avistamiento: especie
  /// reconocida, ser vivo y tomada en vivo.
  ///
  /// Es deliberadamente estricto. Todo lo que decide si una foto se guarda,
  /// si suma Veridiums o si avanza un desafío mira este campo, así que
  /// cualquier duda tiene que resolverse hacia el NO: una foto de más que se
  /// pierde es un incordio, una foto basura que entra se queda en el mapa
  /// comunitario para siempre.
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

  /// Por qué se rechazó, cuando [identified] es false.
  ///
  /// Lo que la IA vio ("una persona", "un objeto") no va en un campo aparte:
  /// ya viaja dentro de [reason], que es el texto que se le enseña al
  /// explorador. Tenerlo dos veces obligaba a mantener los dos sincronizados
  /// para nada.
  final MotivoRechazo rechazo;
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
Eres un naturalista. Catalogas CUALQUIER ser vivo que te muestren —silvestre
o doméstico, común o raro— y conoces especialmente la fauna y la flora de
Cundinamarca, Colombia. Observa la imagen y responde ÚNICAMENTE con un JSON
válido (sin texto adicional, sin marcado de código), con exactamente esta
forma:

{
  "identificado": true o false,
  "nombre_comun": "nombre común en español, o null",
  "nombre_cientifico": "nombre científico, o null",
  "tipo": uno de "ave", "mamifero", "reptil", "anfibio", "pez", "insecto",
          "aracnido", "planta", "hongo" u "otro" (o null),
  "confianza": "alta", "media" o "baja",
  "descripcion": "1 o 2 frases sobre la especie y su hábitat en Cundinamarca, o null",
  "es_ser_vivo": true o false,
  "categoria_no_valida": uno de "persona", "objeto", "comida", "vehiculo",
          "edificacion", "texto", "ninguna",
  "es_pantalla_o_impresion": true o false,
  "motivo": "si identificado es false, explica brevemente por qué"
}

REGLAS ESTRICTAS, en este orden:

0. "es_ser_vivo" responde a UNA sola pregunta: ¿lo que domina la foto es un
   organismo vivo? NO depende de que sepas nombrar la especie. Un animal o
   una planta que no logras identificar sigue siendo un ser vivo: en ese caso
   "es_ser_vivo" es true, "identificado" es false y lo explicas en "motivo".
   No uses "categoria_no_valida" para decir "no sé qué es".

1. "es_ser_vivo" es true si el sujeto principal es una planta, un animal o un
   hongo reales y vivos. Es false para partes del cuerpo humano, objetos,
   muebles, ropa, comida preparada, vehículos, edificaciones, pantallas,
   dibujos, texto y logotipos.

   LOS ANIMALES DOMÉSTICOS Y COMUNES CUENTAN COMO ANIMALES. Un perro, un
   gato, una gallina, una vaca, un caballo, un conejo o un loro son fauna y
   "es_ser_vivo" es true, aunque no sean especies silvestres de Cundinamarca.
   Una mascota dormida, tumbada, a contraluz, de espaldas o parcialmente
   tapada SIGUE siendo un animal: no la clasifiques como "objeto" por estar
   quieta, borrosa o mal iluminada.

   Solo marca "objeto" cuando de verdad veas una cosa inanimada. Ante la duda
   entre un animal real y un peluche o una figura, decide por el animal real
   y baja "confianza" a "baja".

   UN SER HUMANO NO CUENTA COMO ESPECIE: si lo que domina la foto es una
   persona o un rostro, "es_ser_vivo" es false y "categoria_no_valida" es
   "persona", aunque biológicamente sea un animal.

2. "es_pantalla_o_impresion" es true si la imagen NO es una escena real
   captada en vivo, sino la foto de otra imagen. Señales: bordes o marco de
   un monitor, celular o televisor; patrón de moiré o rejilla de píxeles;
   reflejos sobre un vidrio; barra de navegador, cursor, íconos o menús;
   marcas de agua de bancos de imágenes; fotografía de una página impresa,
   un libro o un afiche; o una captura de pantalla directa.

3. "categoria_no_valida" es "ninguna" cuando "es_ser_vivo" es true. En
   cualquier otro caso indica qué es lo que se ve.

4. "identificado" es true SOLO si "es_ser_vivo" es true, la especie se
   reconoce y "es_pantalla_o_impresion" es false.

5. Si "identificado" es false, "motivo" explica en una frase corta y en
   español qué viste realmente.
''';

/// Veredicto sobre lo que devolvió la IA.
@immutable
class EvaluacionIA {
  const EvaluacionIA({required this.rechazo, this.mensaje});

  final MotivoRechazo rechazo;

  /// Qué decirle al explorador. null cuando la foto sirve.
  final String? mensaje;

  bool get sirve => rechazo == MotivoRechazo.ninguno;
}

/// Cómo se le nombra al explorador cada cosa que no es una especie.
const _nombreDeCategoria = {
  'persona': 'una persona',
  'objeto': 'un objeto',
  'comida': 'comida',
  'vehiculo': 'un vehículo',
  'edificacion': 'una construcción',
  'texto': 'texto o un logotipo',
};

/// Decide si lo que devolvió Gemini sirve como avistamiento.
///
/// Vive aparte y es pura para poder probarla sin red: es la regla que sostiene
/// todo el filtro. Una foto de más que se pierde es un incordio; una foto
/// basura que entra se queda en el mapa comunitario para siempre, así que ante
/// la duda se rechaza.
///
/// [esSerVivo] cae a [identificado] cuando la IA omite el campo: el modelo
/// siempre devuelve `identificado`, así que ese es el respaldo sensato si un
/// día responde con el formato viejo.
EvaluacionIA evaluarRespuestaIA({
  required bool identificado,
  bool? esSerVivo,
  String? categoriaNoValida,
  bool esPantalla = false,
  String? motivoIA,
}) {
  final categoria = (categoriaNoValida ?? 'ninguna').trim().toLowerCase();
  final vivo = esSerVivo ?? identificado;
  final categoriaInvalida = categoria.isNotEmpty && categoria != 'ninguna';

  if (!vivo || categoriaInvalida) {
    final que = _nombreDeCategoria[categoria];
    return EvaluacionIA(
      rechazo: MotivoRechazo.noEsSerVivo,
      mensaje: que == null
          ? 'Esto no es una especie. Veridia solo registra plantas, animales '
                'y hongos.'
          : 'Eso es $que, no una especie. Veridia solo registra plantas, '
                'animales y hongos.',
    );
  }

  if (esPantalla) {
    return const EvaluacionIA(
      rechazo: MotivoRechazo.pantallaOImpresion,
      mensaje:
          'Esta foto parece tomada de una pantalla o de una impresión. '
          'El avistamiento tiene que ser tuyo: fotografía la especie en vivo.',
    );
  }

  if (!identificado) {
    return EvaluacionIA(
      rechazo: MotivoRechazo.noIdentificada,
      mensaje:
          motivoIA ??
          'La IA no reconoció ninguna especie en esta foto. '
              'Acércate más o busca mejor luz.',
    );
  }

  return const EvaluacionIA(rechazo: MotivoRechazo.ninguno);
}

/// Motivo por el que Gemini se negó a responder, o null si respondió bien.
///
/// Gemini tiene DOS formas de decir que no: devolver la respuesta sin
/// `candidates` (bloqueó la petición entera) o devolver un candidato sin
/// `parts`, con un `finishReason` que no es STOP (SAFETY, RECITATION,
/// MAX_TOKENS).
///
/// Importa aquí más que en cualquier otra app: el filtro de seguridad de
/// Gemini salta sobre todo con **fotos de personas**, que es exactamente lo
/// que este servicio existe para rechazar. Antes los dos casos reventaban al
/// leer `parts` y caían en el catch genérico, así que el explorador que
/// fotografiaba a alguien leía "no se pudo interpretar la respuesta de la IA"
/// —un mensaje que no dice nada y que invita a reintentar en bucle— en vez de
/// enterarse de que ahí no hay ninguna especie.
String? motivoDeBloqueoGemini(Map<String, dynamic> respuesta) {
  final feedback = respuesta['promptFeedback'];
  if (feedback is Map && feedback['blockReason'] != null) {
    return feedback['blockReason'].toString();
  }

  final candidates = respuesta['candidates'];
  if (candidates is! List || candidates.isEmpty) return 'SIN_CANDIDATOS';

  final primero = candidates.first;
  if (primero is! Map) return 'RESPUESTA_INESPERADA';

  final content = primero['content'];
  final parts = content is Map ? content['parts'] : null;
  if (parts is! List || parts.isEmpty) {
    return (primero['finishReason'] ?? 'SIN_TEXTO').toString();
  }

  return null;
}

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
      // Tres mensajes distintos a propósito, según QUIÉN lo está leyendo.
      //
      // En la web publicada lo lee un explorador: para él la IA simplemente
      // no existe ahí, y eso es una decisión de seguridad (la clave no se
      // compila en web, ver config/gemini_key.dart). En la web en modo
      // desarrollo lo lee quien programa, que SÍ puede activarla en su
      // máquina y necesita saber cómo. En móvil es algo por configurar.
      throw SpeciesIdentificationException(
        kIsWeb
            ? (kDebugMode
                  ? 'IA desactivada en esta ejecución web. Para probarla en '
                        'el navegador, arranca con probar-ia-en-web.ps1 (pasa '
                        'la clave por --dart-define, sin dejarla en el '
                        'bundle).'
                  : 'La identificación con IA no está disponible en la '
                        'versión web. Usa la app de Android para identificar '
                        'especies.')
            : 'Falta configurar la clave de Gemini en '
                  'lib/config/gemini_config.dart',
      );
    }

    final perfil = UserRepository.instance.currentUser.value;

    // El freno va ANTES que nada, incluso antes de calcular la huella: si el
    // explorador está en plena racha de fotos rechazadas o agotó el cupo del
    // día, no tiene sentido gastar CPU, una lectura de Firestore ni una
    // petición de IA para acabar diciéndole que no.
    if (perfil != null) {
      await LimiteIntentosService.instance.revisar(perfil.userId);
    }

    final huella = await calcularHuella(imageBytes);
    if (perfil != null) {
      final duplicada = await HuellaFotoService.instance.buscarDuplicado(
        userId: perfil.userId,
        huella: huella,
      );
      if (duplicada != null) {
        // Reenviar la misma foto una y otra vez es justo el patrón que el
        // limitador existe para cortar, así que cuenta como rechazo.
        await LimiteIntentosService.instance.registrarRechazo(perfil.userId);
        throw FotoDuplicadaException(duplicada.mensaje);
      }
    }

    // Se encoge justo antes de mandarla, NO antes de calcular la huella.
    //
    // El orden importa: la huella tiene que salir siempre de los bytes
    // originales. Si saliera de la copia comprimida, bastaría con que el
    // compresor cambiara un byte entre versiones de Android para que la misma
    // foto diera un sha256 distinto y el control de repetidas dejara de
    // reconocerla.
    final paraIA = await comprimirParaEnviar(
      imageBytes,
      lado: ladoParaIA,
      mimeOriginal: mimeType,
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inline_data': {
                'mime_type': paraIA.mimeType,
                'data': base64Encode(paraIA.bytes),
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

      // Gemini se negó a responder. No es un fallo técnico que haya que
      // reintentar: es una respuesta, y se trata como rechazo normal para que
      // cuente en el limitador y la foto quede marcada como usada.
      final bloqueo = motivoDeBloqueoGemini(decoded);
      if (bloqueo != null) {
        debugPrint('Gemini no devolvió texto (motivo: $bloqueo)');
        return _registrarYDevolver(
          SpeciesIdentification(
            identified: false,
            sha256: huella.sha256,
            rechazo: MotivoRechazo.noIdentificada,
            reason:
                'La IA no pudo analizar esta foto. Suele pasar con fotos de '
                'personas. Enfoca una planta, un animal o un hongo.',
          ),
          userId: perfil?.userId,
          huella: huella,
          origen: origen,
        );
      }

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

      final evaluacion = evaluarRespuestaIA(
        identificado: json['identificado'] as bool? ?? false,
        esSerVivo: json['es_ser_vivo'] as bool?,
        categoriaNoValida: json['categoria_no_valida'] as String?,
        esPantalla: json['es_pantalla_o_impresion'] as bool? ?? false,
        motivoIA: json['motivo'] as String?,
      );

      resultado = SpeciesIdentification(
        // El veredicto manda sobre lo que diga `identificado`: si la IA
        // reconoció un colibrí pero la foto es de la pantalla de un portátil,
        // aquí queda en false y ya no se puede guardar ni cobrar.
        identified: evaluacion.sirve,
        sha256: huella.sha256,
        commonName: json['nombre_comun'] as String?,
        scientificName: json['nombre_cientifico'] as String?,
        type: json['tipo'] as String?,
        confidence: json['confianza'] as String? ?? 'baja',
        description: json['descripcion'] as String?,
        reason: evaluacion.mensaje ?? json['motivo'] as String?,
        rechazo: evaluacion.rechazo,
      );
    } catch (e) {
      debugPrint(
        'No se pudo interpretar la respuesta de Gemini: ${response.body}',
      );
      throw SpeciesIdentificationException(
        'No se pudo interpretar la respuesta de la IA. Intenta de nuevo.',
      );
    }

    return _registrarYDevolver(
      resultado,
      userId: perfil?.userId,
      huella: huella,
      origen: origen,
    );
  }

  /// Marca la foto como usada y actualiza el limitador, identifique o no.
  ///
  /// Lo comparten el resultado normal y el rechazo por bloqueo de Gemini: si
  /// el bloqueado no pasara por aquí, la misma foto se podría reenviar en
  /// bucle sin gastar intentos ni quedar registrada, que es justo el agujero
  /// que el limitador existe para cerrar.
  Future<SpeciesIdentification> _registrarYDevolver(
    SpeciesIdentification resultado, {
    required String? userId,
    required HuellaFoto huella,
    String? origen,
  }) async {
    if (userId == null) return resultado;

    // El cupo del día se gasta aquí y no al empezar: llegar hasta este punto
    // significa que la IA respondió. Un fallo de red antes de eso no le cuesta
    // un análisis al explorador.
    await LimiteIntentosService.instance.contarAnalisis(userId);

    // Se marca usada YA: así una foto borrosa que Gemini rechaza tampoco se
    // puede reintentar en bucle gastando cuota.
    await HuellaFotoService.instance.registrar(
      userId: userId,
      huella: huella,
      origen: origen ?? 'la Cámara IA',
    );

    // Una foto válida borra la racha: quien está explorando de verdad nunca
    // debería toparse con la espera, por muchas fotos que falle entre medias.
    if (resultado.identified) {
      await LimiteIntentosService.instance.registrarExito(userId);
    } else {
      await LimiteIntentosService.instance.registrarRechazo(userId);
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
