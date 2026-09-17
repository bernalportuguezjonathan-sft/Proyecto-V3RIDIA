'use strict';

const { HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

// 'gemini-flash-lite-latest' y no una versión fija: ya pasó una vez que un
// alias más "nuevo" ('gemini-flash-latest') apuntó a un modelo con solo 20
// peticiones/día de cuota gratis. Este alias tiene cuota mucho más alta.
const MODELO = 'gemini-flash-lite-latest';
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODELO}:generateContent`;

// IMPORTANTE: este prompt y `evaluarRespuestaIA` de abajo son el espejo exacto
// de `lib/services/especie_ia_service.dart`. Si se cambia uno hay que cambiar
// el otro, o el día que se despliegue este backend la app filtrará distinto de
// como filtra hoy.
const PROMPT = `Eres un naturalista. Catalogas CUALQUIER ser vivo que te muestren —silvestre
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
   español qué viste realmente.`;

/** Cómo se le nombra al explorador cada cosa que no es una especie. */
const NOMBRE_DE_CATEGORIA = {
  persona: 'una persona',
  objeto: 'un objeto',
  comida: 'comida',
  vehiculo: 'un vehículo',
  edificacion: 'una construcción',
  texto: 'texto o un logotipo',
};

/**
 * Decide si lo que devolvió Gemini sirve como avistamiento.
 * Espejo de `evaluarRespuestaIA` en el lado Dart.
 */
function evaluarRespuestaIA({
  identificado,
  esSerVivo,
  categoriaNoValida,
  esPantalla,
  motivoIA,
}) {
  const categoria = String(categoriaNoValida ?? 'ninguna')
    .trim()
    .toLowerCase();
  // Si la IA omite el campo caemos a `identificado`, que siempre viene.
  const vivo = typeof esSerVivo === 'boolean' ? esSerVivo : identificado;
  const categoriaInvalida = categoria !== '' && categoria !== 'ninguna';

  if (!vivo || categoriaInvalida) {
    const que = NOMBRE_DE_CATEGORIA[categoria];
    return {
      rechazo: 'noEsSerVivo',
      mensaje: que
        ? `Eso es ${que}, no una especie. Veridia solo registra plantas, animales y hongos.`
        : 'Esto no es una especie. Veridia solo registra plantas, animales y hongos.',
    };
  }

  if (esPantalla === true) {
    return {
      rechazo: 'pantallaOImpresion',
      mensaje:
        'Esta foto parece tomada de una pantalla o de una impresión. El avistamiento tiene que ser tuyo: fotografía la especie en vivo.',
    };
  }

  if (!identificado) {
    return {
      rechazo: 'noIdentificada',
      mensaje:
        motivoIA ??
        'La IA no reconoció ninguna especie en esta foto. Acércate más o busca mejor luz.',
    };
  }

  return { rechazo: 'ninguno', mensaje: null };
}

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

    const evaluacion = evaluarRespuestaIA({
      identificado: json.identificado === true,
      esSerVivo: json.es_ser_vivo,
      categoriaNoValida: json.categoria_no_valida,
      esPantalla: json.es_pantalla_o_impresion === true,
      motivoIA: json.motivo ?? null,
    });

    return {
      // El veredicto manda sobre lo que diga `identificado`: si la IA
      // reconoció un colibrí pero la foto es de la pantalla de un portátil,
      // aquí queda en false y ya no se puede guardar ni cobrar.
      identified: evaluacion.rechazo === 'ninguno',
      commonName: json.nombre_comun ?? null,
      scientificName: json.nombre_cientifico ?? null,
      type: json.tipo ?? null,
      confidence: json.confianza ?? 'baja',
      description: json.descripcion ?? null,
      reason: evaluacion.mensaje ?? json.motivo ?? null,
      rechazo: evaluacion.rechazo,
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

module.exports = { identificarEspecie, parsearIdentificacion, evaluarRespuestaIA };
