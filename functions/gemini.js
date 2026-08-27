'use strict';

const { HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

// 'gemini-flash-lite-latest' y no una versión fija: ya pasó una vez que un
// alias más "nuevo" ('gemini-flash-latest') apuntó a un modelo con solo 20
// peticiones/día de cuota gratis. Este alias tiene cuota mucho más alta.
const MODELO = 'gemini-flash-lite-latest';
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODELO}:generateContent`;

const PROMPT = `Eres un naturalista experto en fauna y flora de Colombia, especialmente del
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
}`;

// Igual que el lado Dart: 2 intentos, cada uno hasta 20s. No tiene sentido
// hacer esperar al explorador más de medio minuto por una foto.
const MAX_INTENTOS = 2;

function esperaSugeridaMs(cuerpo) {
  const match = /"retryDelay"\s*:\s*"(\d+)s"/.exec(cuerpo);
  if (!match) return null;
  const segundos = parseInt(match[1], 10);
  if (Number.isNaN(segundos)) return null;
  return Math.min(15, Math.max(1, segundos)) * 1000;
}

function esCuotaDiariaAgotada(cuerpo) {
  return cuerpo.includes('PerDay');
}

function mensajeDeError(status) {
  switch (status) {
    case 400:
      return 'La clave de Gemini configurada en el servidor no es válida.';
    case 403:
      return 'La clave de Gemini no tiene permiso para usar este modelo.';
    case 429:
      return 'Alcanzaste el límite de peticiones gratuitas de la IA. Espera un minuto y vuelve a intentarlo.';
    default:
      return status >= 500
        ? 'El servicio de IA está caído en este momento. Intenta de nuevo en unos minutos.'
        : `La IA no pudo responder (código ${status}). Intenta de nuevo.`;
  }
}

function dormir(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Llama a Gemini con reintentos ante errores temporales (429/5xx). */
async function llamarGemini(apiKey, imageBase64, mimeType) {
  const body = JSON.stringify({
    contents: [
      {
        parts: [
          { text: PROMPT },
          { inline_data: { mime_type: mimeType, data: imageBase64 } },
        ],
      },
    ],
  });

  let ultimoFallo = null;

  for (let intento = 1; intento <= MAX_INTENTOS; intento++) {
    let response;
    try {
      response = await fetch(ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          // La clave nunca sale del servidor: viaja en la cabecera de ESTA
          // petición saliente, no en algo que el cliente Flutter vea jamás.
          'x-goog-api-key': apiKey,
        },
        body,
        signal: AbortSignal.timeout(20000),
      });
    } catch (e) {
      ultimoFallo = e;
      if (intento === MAX_INTENTOS) {
        throw new HttpsError(
          'unavailable',
          'No se pudo conectar con la IA. Intenta de nuevo.'
        );
      }
      await dormir(2000 * intento);
      continue;
    }

    if (response.ok) {
      return await response.json();
    }

    const textoError = await response.text();
    logger.warn(`Gemini error ${response.status}`, { textoError });

    if (response.status === 429 && esCuotaDiariaAgotada(textoError)) {
      throw new HttpsError(
        'resource-exhausted',
        'Se agotó la cuota gratuita de la IA por hoy. Vuelve a intentarlo más tarde.'
      );
    }

    const esTemporal = response.status === 429 || response.status >= 500;
    if (esTemporal && intento < MAX_INTENTOS) {
      const espera = esperaSugeridaMs(textoError) || 3000 * intento;
      await dormir(espera);
      continue;
    }

    throw new HttpsError('internal', mensajeDeError(response.status));
  }

  logger.error('Gemini no respondió tras los reintentos', { ultimoFallo });
  throw new HttpsError(
    'internal',
    `La IA no respondió tras ${MAX_INTENTOS} intentos.`
  );
}

/** Extrae y valida el JSON que Gemini devuelve envuelto en su respuesta. */
function parsearIdentificacion(decoded) {
  try {
    const candidato = decoded.candidates[0];
    const rawText = candidato.content.parts[0].text;
    const limpio = rawText
      .trim()
      .replace(/^```json/, '')
      .replace(/^```/, '')
      .replace(/```$/, '')
      .trim();
    const json = JSON.parse(limpio);

    return {
      identified: json.identificado === true,
      commonName: json.nombre_comun ?? null,
      scientificName: json.nombre_cientifico ?? null,
      type: json.tipo ?? null,
      confidence: json.confianza ?? 'baja',
      description: json.descripcion ?? null,
      reason: json.motivo ?? null,
    };
  } catch (e) {
    logger.error('No se pudo interpretar la respuesta de Gemini', {
      error: String(e),
      decoded,
    });
    throw new HttpsError(
      'internal',
      'No se pudo interpretar la respuesta de la IA. Intenta de nuevo.'
    );
  }
}

async function identificarEspecie(apiKey, imageBase64, mimeType) {
  const decoded = await llamarGemini(apiKey, imageBase64, mimeType);
  return parsearIdentificacion(decoded);
}

module.exports = { identificarEspecie, parsearIdentificacion };
