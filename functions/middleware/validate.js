'use strict';

/**
 * Validación y saneamiento de entradas para las Cloud Functions.
 *
 * Antes, `index.js` comprobaba cada campo a mano (`typeof x !== 'string'`):
 * cubría "está el campo" pero no "el campo tiene sentido" — un `latitude` de
 * 9999 o un `observationId` con `../` en medio pasaban igual. Con esquemas
 * de zod se valida TIPO, RANGO y FORMA en un solo sitio, y el error que
 * recibe el cliente siempre dice qué campo falló y por qué.
 *
 * `esquema.strict()` en cada objeto: un payload con un campo de más se
 * rechaza en vez de ignorarse en silencio. Es la misma razón por la que las
 * reglas de Firestore usan `hasOnly()` en vez de comprobar solo lo que sí
 * les importa — un campo inesperado casi siempre es una versión vieja del
 * cliente o alguien probando qué acepta el endpoint.
 */

const { z } = require('zod');
const { HttpsError } = require('firebase-functions/v2/https');

/**
 * Valida `datos` contra `esquema` y devuelve el objeto YA VALIDADO (con los
 * valores por defecto del esquema aplicados). Lanza `HttpsError`
 * ('invalid-argument' -> HTTP 400) con el primer problema encontrado.
 */
function validar(esquema, datos) {
  const resultado = esquema.safeParse(datos || {});
  if (!resultado.success) {
    const primero = resultado.error.issues[0];
    const campo = primero.path.length > 0 ? primero.path.join('.') : 'payload';
    throw new HttpsError('invalid-argument', `${campo}: ${primero.message}`);
  }
  return resultado.data;
}

// ---------------------------------------------------------------------------
// Esquemas de las dos Cloud Functions actuales.
// ---------------------------------------------------------------------------

// Los mismos mimeType que puede entregar image_picker en Android/iOS/web
// para una foto tomada con la cámara o elegida de la galería. Gemini no
// acepta nada fuera de esta lista de todas formas; rechazarlo aquí ahorra
// una llamada a la API por una imagen que iba a fallar igual.
const MIME_TYPES_IMAGEN = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
];

const esquemaIdentificarEspecie = z
  .object({
    // ~15 MB de imagen en base64 pesan ~20 MB de texto (overhead ~33%).
    imageBase64: z.string().min(1).max(20 * 1024 * 1024),
    mimeType: z.enum(MIME_TYPES_IMAGEN),
    // Solo para mensajes de error más claros ("la Cámara IA", "una
    // observación"); nunca se usa para decidir nada, así que basta con
    // acotar el tamaño.
    origen: z.string().max(120).optional(),
  })
  .strict();

// El id de una observación es siempre un id de documento de Firestore
// (`_collection.doc().id` en el cliente): letras, números, guiones. Fijar el
// patrón aquí es lo que cierra cualquier intento de meter un separador de
// ruta en un id que luego se usa para nombrar el archivo en Supabase Storage.
const idFirestoreRegex = /^[A-Za-z0-9_-]{1,64}$/;

const esquemaGuardarObservacion = z
  .object({
    sha256: z.string().regex(/^[0-9a-f]{64}$/, 'debe ser un sha256 hexadecimal'),
    observationId: z.string().regex(idFirestoreRegex, 'id de observación inválido'),
    imageUrl: z.string().url().max(2048).nullish(),
    latitude: z.number().min(-90).max(90).nullish(),
    longitude: z.number().min(-180).max(180).nullish(),
    location: z.string().max(200).nullish(),
  })
  .strict();

module.exports = {
  validar,
  esquemaIdentificarEspecie,
  esquemaGuardarObservacion,
  idFirestoreRegex,
};

/**
 * Patrón para un endpoint HTTP (`onRequest`) con query params, por si algún
 * día se añade uno. Los `onCall` actuales no tienen query string —
 * `request.data` ya es el "body" tipado que llega desde el cliente Dart—,
 * así que no hay ningún parámetro de URL que validar hoy. Se deja el
 * patrón listo para no tener que redescubrirlo:
 *
 * const { z } = require('zod');
 * const esquemaQuery = z.object({
 *   formato: z.enum(['json', 'texto']).default('json'),
 *   limite: z.coerce.number().int().min(1).max(100).default(20),
 * });
 *
 * exports.miEndpoint = onRequest((req, res) => {
 *   const resultado = esquemaQuery.safeParse(req.query);
 *   if (!resultado.success) {
 *     res.status(400).json({ error: resultado.error.issues[0].message });
 *     return;
 *   }
 *   const { formato, limite } = resultado.data; // ya son del tipo correcto
 *   // ...
 * });
 */
