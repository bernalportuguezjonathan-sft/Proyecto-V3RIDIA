'use strict';

/**
 * Rate limiting para las Cloud Functions de Veridia.
 *
 * Por qué existe: con Blaze activo, cada invocación de `identificarEspecie`
 * cuesta una llamada a Gemini (cuota externa) más tiempo de función
 * facturado; `guardarObservacion` cuesta lecturas/escrituras de Firestore.
 * Sin límite, un cliente modificado en un bucle -o alguien con la consola de
 * red abierta- puede vaciar la cuota diaria de Gemini o disparar la
 * facturación en minutos. Las reglas de Firestore no pueden frenar esto:
 * limitan QUÉ se escribe, no CUÁNTAS VECES se llama a una función.
 *
 * Dos cupos independientes por función:
 *   - por UID: frena a una cuenta que abusa.
 *   - por IP: frena a quien crea cuentas nuevas para esquivar el cupo de UID
 *     (o pega el endpoint directo sin pasar por la app).
 * Ambos con ventana fija de 1 minuto: es la unidad en la que ya se piensa la
 * cuota de Gemini, y una ventana fija es mucho más barata en Firestore que
 * una ventana deslizante (un documento por minuto, no un documento por
 * petición).
 *
 * El contador vive en la colección `rateLimits`, con `expiresAt` para que
 * una política TTL de Firestore la limpie sola (ver el comando al final de
 * este archivo). Sin TTL los documentos se acumulan para siempre; con Blaze
 * eso es dinero real por almacenamiento, aunque sea poco.
 */

const { HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
// Misma razon que en index.js: v13+ de firebase-admin ya no expone
// `admin.firestore()` con namespace, solo la API modular.
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

function db() {
  return getFirestore();
}

/**
 * IP real del que llama, detrás del proxy de Cloud Functions.
 *
 * `onCall` (v2) expone la petición HTTP cruda en `request.rawRequest`.
 * Cloud Functions siempre pasa por un balanceador que añade
 * `x-forwarded-for`; `req.ip` de Express ya lo resuelve cuando `trust proxy`
 * está activo (lo está, por defecto, en el runtime de Functions), así que
 * se usa como fuente principal y la cabecera como respaldo.
 */
function obtenerIp(request) {
  const cruda = request.rawRequest;
  if (!cruda) return 'sin-ip';
  if (cruda.ip) return cruda.ip;
  const adelantada = cruda.headers && cruda.headers['x-forwarded-for'];
  if (typeof adelantada === 'string' && adelantada.length > 0) {
    return adelantada.split(',')[0].trim();
  }
  return 'sin-ip';
}

/**
 * Incrementa el contador de una ventana fija y devuelve el conteo YA
 * incluyendo esta petición. Atómico: dos peticiones simultáneas nunca leen
 * el mismo valor de partida.
 */
async function incrementarContador(clave, ventanaMs, margenLimpiezaMs) {
  const ventanaId = Math.floor(Date.now() / ventanaMs);
  const ref = db().collection('rateLimits').doc(`${clave}_${ventanaId}`);

  return db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const actual = snap.exists ? snap.data().conteo || 0 : 0;
    const nuevo = actual + 1;
    tx.set(ref, {
      conteo: nuevo,
      // El TTL de Firestore borra el documento pasada esta fecha. El margen
      // extra evita que se borre justo cuando la ventana todavía está en uso
      // por una petición que llegó tarde.
      expiresAt: Timestamp.fromMillis(
        Date.now() + ventanaMs + margenLimpiezaMs
      ),
    });
    return nuevo;
  });
}

/**
 * Envuelve un handler de `onCall` (v2) con límites por usuario y por IP.
 *
 * Uso:
 *   exports.miFuncion = onCall(
 *     { region: REGION },
 *     conLimiteDeTasa(async (request) => { ... }, {
 *       nombre: 'miFuncion',
 *       porUsuario: 20,
 *       porIp: 60,
 *     })
 *   );
 *
 * Devuelve un `HttpsError('resource-exhausted', ...)` cuando se excede: es
 * el único código de la tabla de errores de Functions que Firebase traduce a
 * HTTP 429 (Too Many Requests) en la respuesta real que recibe el cliente.
 */
function conLimiteDeTasa(handler, opciones) {
  const {
    nombre,
    porUsuario = 20,
    porIp = 60,
    ventanaMs = 60_000,
  } = opciones;

  if (!nombre) {
    throw new Error('conLimiteDeTasa requiere un "nombre" único por función.');
  }

  const margenLimpiezaMs = 5 * 60_000;

  return async (request) => {
    const uid = request.auth ? request.auth.uid : null;
    const ip = obtenerIp(request);

    if (uid) {
      const conteoUsuario = await incrementarContador(
        `usuario_${nombre}_${uid}`,
        ventanaMs,
        margenLimpiezaMs
      );
      if (conteoUsuario > porUsuario) {
        logger.warn('Rate limit por usuario excedido', {
          funcion: nombre,
          uid,
          conteo: conteoUsuario,
          limite: porUsuario,
        });
        throw new HttpsError(
          'resource-exhausted',
          'Demasiadas peticiones seguidas. Espera un minuto e intenta de nuevo.'
        );
      }
    }

    const conteoIp = await incrementarContador(
      `ip_${nombre}_${ip}`,
      ventanaMs,
      margenLimpiezaMs
    );
    if (conteoIp > porIp) {
      logger.warn('Rate limit por IP excedido', {
        funcion: nombre,
        ip,
        conteo: conteoIp,
        limite: porIp,
      });
      throw new HttpsError(
        'resource-exhausted',
        'Demasiadas peticiones desde tu red. Espera un minuto e intenta de nuevo.'
      );
    }

    return handler(request);
  };
}

module.exports = { conLimiteDeTasa, obtenerIp };

/**
 * Comando para que Firestore borre solo los documentos de `rateLimits` cuya
 * `expiresAt` ya pasó (política TTL, gratis, no hay que programar nada).
 * Ejecutar UNA vez, desde una terminal con `gcloud` autenticado:
 *
 *   gcloud firestore fields ttls update expiresAt \
 *     --collection-group=rateLimits \
 *     --enable-ttl \
 *     --project=v3ridia
 *
 * Sin esto los documentos de conteo se acumulan para siempre: con un
 * explorador activo son un par de KB al mes, pero es limpieza gratuita que
 * no cuesta nada dejar activada.
 */
