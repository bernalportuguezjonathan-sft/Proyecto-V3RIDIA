'use strict';

/**
 * Backend de Veridia.
 *
 * Existe por dos huecos que el code review de la app encontró y que un
 * cliente Flutter, por diseño, nunca puede cerrar del todo:
 *
 * 1. La clave de Gemini viajaba embebida en el APK/bundle web -- cualquiera
 *    con el instalador podia extraerla y gastar la cuota. Aqui vive como
 *    secreto de servidor (GEMINI_API_KEY) y el cliente nunca la ve.
 * 2. Los Veridiums se otorgaban con una transaccion de Firestore que
 *    corria en el cliente: un APK modificado podia saltarse la verificacion
 *    de la IA y auto-asignarse progreso/monedas. Aqui la identificacion Y la
 *    transaccion de recompensa corren con el Admin SDK, que las reglas de
 *    Firestore no pueden vetar -- por eso firestore.rules ahora PROHIBE al
 *    cliente escribir tokens al alza, progreso de desafios o el contador de
 *    completados: solo puede llegar por aqui.
 *
 * Flujo desde la app (reemplaza al POST directo a Gemini + a las
 * transacciones de repositorio_d.dart / huella_foto.dart):
 *
 *   1. identificarEspecie(imageBase64, mimeType)
 *      -> identifica con Gemini, revisa fotos repetidas, y CACHEA el
 *         resultado server-side en users/{uid}/fotos/{sha256}.
 *   2. guardarObservacion(sha256, observationId, imageUrl, lat, lng)
 *      -> lee esa identificacion YA VERIFICADA (el cliente no puede
 *         inventarla), crea el avistamiento y avanza TODOS los desafios
 *         propios cuya especie coincida, en una sola transaccion.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');
const sharp = require('sharp');

const { identificarEspecie: identificarConGemini } = require('./gemini');
const {
  especieCoincide,
  calcularBonoCompletar,
  ahashDesdeRgba,
  distanciaHamming,
  UMBRAL_PARECIDO,
} = require('./logica');

admin.initializeApp();
const db = admin.firestore();

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

// Cuantas huellas recientes se comparan para el parecido "recomprimida/
// reexportada". Mismo limite que usaba el cliente; acota el costo de
// lecturas sin dejar de cubrir el uso real de un explorador.
const MAX_HUELLAS_REVISADAS = 300;

const REGION = 'us-central1';

function exigirSesion(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }
  return request.auth.uid;
}

function coleccionFotos(uid) {
  return db.collection('users').doc(uid).collection('fotos');
}

function coleccionProgreso(uid) {
  return db.collection('users').doc(uid).collection('desafios');
}

/** sha256 en hex + average-hash 8x8 (o vacio si la imagen no se pudo decodificar). */
async function calcularHuella(buffer) {
  const sha256 = crypto.createHash('sha256').update(buffer).digest('hex');

  let ahash = '';
  try {
    const rgba = await sharp(buffer)
      .resize(8, 8, { fit: 'fill' })
      .ensureAlpha()
      .raw()
      .toBuffer();
    ahash = ahashDesdeRgba(rgba);
  } catch (e) {
    logger.warn('No se pudo calcular el ahash de la foto', { error: String(e) });
  }

  return { sha256, ahash };
}

/**
 * Foto ya usada antes por este explorador: exacta (mismo sha256) o
 * "practicamente igual" (ahash a poca distancia -- recompresion, reexportado
 * de WhatsApp, etc). null si es nueva.
 */
async function buscarDuplicado(uid, huella) {
  const exactaRef = coleccionFotos(uid).doc(huella.sha256);
  const exactaSnap = await exactaRef.get();
  if (exactaSnap.exists) {
    const data = exactaSnap.data();
    return {
      exacta: true,
      fecha: data.fecha,
      origen: data.origen || 'una captura anterior',
    };
  }

  if (!huella.ahash) return null;

  const snapshot = await coleccionFotos(uid)
    .orderBy('fecha', 'desc')
    .limit(MAX_HUELLAS_REVISADAS)
    .get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const ahash = data.ahash || '';
    if (!ahash) continue;
    if (distanciaHamming(ahash, huella.ahash) <= UMBRAL_PARECIDO) {
      return {
        exacta: false,
        fecha: data.fecha,
        origen: data.origen || 'una captura anterior',
      };
    }
  }
  return null;
}

// ==========================================================================
// 1) identificarEspecie -- proxy de Gemini + registro de huella
// ==========================================================================

exports.identificarEspecie = onCall(
  { secrets: [GEMINI_API_KEY], region: REGION, timeoutSeconds: 45 },
  async (request) => {
    const uid = exigirSesion(request);
    const { imageBase64, mimeType, origen } = request.data || {};

    if (typeof imageBase64 !== 'string' || !imageBase64) {
      throw new HttpsError('invalid-argument', 'Falta la imagen.');
    }
    if (typeof mimeType !== 'string' || !mimeType) {
      throw new HttpsError('invalid-argument', 'Falta el tipo de imagen.');
    }
    // Gemini rechaza imagenes gigantes de todas formas; cortar aqui evita
    // gastar tiempo de funcion decodificando algo que ya sabemos que va a
    // fallar (el base64 pesa ~33% mas que los bytes originales).
    if (imageBase64.length > 15 * 1024 * 1024) {
      throw new HttpsError('invalid-argument', 'La imagen es demasiado grande.');
    }

    const buffer = Buffer.from(imageBase64, 'base64');
    const huella = await calcularHuella(buffer);

    const duplicada = await buscarDuplicado(uid, huella);
    if (duplicada) {
      return { sha256: huella.sha256, duplicada, identification: null };
    }

    const identification = await identificarConGemini(
      GEMINI_API_KEY.value(),
      imageBase64,
      mimeType
    );

    // Se cachea SIEMPRE que Gemini respondio (identifique o no): asi una
    // foto borrosa que Gemini rechaza tambien queda marcada como "ya
    // procesada" y no se puede reintentar en bucle gastando cuota.
    await coleccionFotos(uid).doc(huella.sha256).set({
      sha256: huella.sha256,
      ahash: huella.ahash,
      origen: origen || 'la Camara IA',
      fecha: new Date().toISOString(),
      identification,
      challengesAcreditados: [],
      observacionId: null,
    });

    return { sha256: huella.sha256, duplicada: null, identification };
  }
);

// ==========================================================================
// 2) guardarObservacion -- crea el avistamiento y paga los desafios que
//    coincidan, usando la identificacion YA VERIFICADA en el paso anterior.
// ==========================================================================

exports.guardarObservacion = onCall(
  { region: REGION, timeoutSeconds: 30 },
  async (request) => {
    const uid = exigirSesion(request);
    const {
      sha256,
      observationId,
      imageUrl,
      latitude,
      longitude,
      location,
    } = request.data || {};

    if (typeof sha256 !== 'string' || !sha256) {
      throw new HttpsError('invalid-argument', 'Falta identificar la foto primero.');
    }
    if (typeof observationId !== 'string' || !observationId) {
      throw new HttpsError('invalid-argument', 'Falta el id de la observacion.');
    }

    const huellaRef = coleccionFotos(uid).doc(sha256);
    const huellaSnap = await huellaRef.get();
    if (!huellaSnap.exists) {
      throw new HttpsError(
        'failed-precondition',
        'Esta foto no paso por la identificacion de la IA.'
      );
    }
    const huella = huellaSnap.data();
    const identification = huella.identification;
    if (!identification || identification.identified !== true) {
      throw new HttpsError(
        'failed-precondition',
        'La IA no identifico ninguna especie en esta foto.'
      );
    }

    // Idempotente: si esta foto ya se guardo antes (reintento de red del
    // cliente), no se crea un segundo avistamiento ni se vuelve a pagar.
    if (huella.observacionId) {
      const userSnap = await db.collection('users').doc(uid).get();
      return {
        observacionId: huella.observacionId,
        avances: [],
        saldoNuevo: userSnap.data()?.tokens || 0,
      };
    }

    const observacionRef = db.collection('avistamientos').doc(observationId);

    // Desafios propios: globales o asignados a mi, que aun no haya
    // completado y cuya especie coincida con lo que la IA identifico.
    // Mismo criterio que challengesForUser() en el cliente.
    const challengesSnap = await db
      .collection('challenges')
      .where('assignedToUserId', 'in', [null, uid])
      .get();

    const elegibles = [];
    for (const doc of challengesSnap.docs) {
      const challenge = doc.data();
      if (!especieCoincide(challenge.targetSpecies, identification)) continue;
      elegibles.push({ id: doc.id, ...challenge });
    }

    const resultado = await db.runTransaction(async (tx) => {
      // TODAS las lecturas antes que TODAS las escrituras: es requisito de
      // Firestore y ademas asi el bono se calcula sobre el estado real, no
      // sobre lo que habia cuando se armo `elegibles` fuera de la transaccion.
      const progresoRefs = elegibles.map((c) => coleccionProgreso(uid).doc(c.id));
      const progresoSnaps = await Promise.all(progresoRefs.map((ref) => tx.get(ref)));
      const userRef = db.collection('users').doc(uid);
      const userSnap = await tx.get(userRef);
      const huellaSnapTx = await tx.get(huellaRef);

      if (huellaSnapTx.data().observacionId) {
        // Otra llamada gano la carrera entre que leimos fuera de la
        // transaccion y ahora: no dupliques nada.
        return {
          observacionId: huellaSnapTx.data().observacionId,
          avances: [],
          saldoNuevo: userSnap.data()?.tokens || 0,
        };
      }

      const acreditados = new Set(huellaSnapTx.data().challengesAcreditados || []);
      let tokensGanados = 0;
      const avances = [];

      elegibles.forEach((challenge, i) => {
        if (acreditados.has(challenge.id)) return; // ya se pago con esta misma foto

        const snap = progresoSnaps[i];
        const actual = snap.exists
          ? snap.data()
          : { progreso: 0, completado: false, bonoPagado: false };

        if (actual.progreso >= challenge.targetGoal) return; // ya estaba completo

        const nuevoProgreso = actual.progreso + 1;
        const completado = nuevoProgreso >= challenge.targetGoal;
        const pagarBono = completado && !actual.bonoPagado;
        const bono = pagarBono ? calcularBonoCompletar(challenge.targetGoal) : 0;
        const ganados = 1 + bono;

        tx.set(progresoRefs[i], {
          progreso: nuevoProgreso,
          completado,
          bonoPagado: actual.bonoPagado || pagarBono,
          actualizado: new Date().toISOString(),
        });

        if (pagarBono) {
          tx.update(db.collection('challenges').doc(challenge.id), {
            completadoPor: admin.firestore.FieldValue.increment(1),
          });
        }

        acreditados.add(challenge.id);
        tokensGanados += ganados;
        avances.push({
          challengeId: challenge.id,
          title: challenge.title,
          progreso: nuevoProgreso,
          meta: challenge.targetGoal,
          completado,
          veridiumsGanados: ganados,
          bono,
        });
      });

      const saldoActual = userSnap.data()?.tokens || 0;
      const saldoNuevo = saldoActual + tokensGanados;
      if (tokensGanados > 0) {
        tx.update(userRef, { tokens: saldoNuevo });
      }

      tx.set(
        observacionRef,
        {
          commonName: identification.commonName || 'Especie observada',
          scientificName: identification.scientificName || 'Sin confirmar',
          location: location || 'Sin ubicacion',
          notes: identification.description || 'Identificado con IA',
          dateTime: new Date().toISOString(),
          imagePath: imageUrl || null,
          latitude: latitude ?? null,
          longitude: longitude ?? null,
          type: identification.type || null,
          userId: uid,
          userDisplayName: request.auth.token.name || null,
        },
        { merge: true }
      );

      tx.update(huellaRef, {
        observacionId: observationId,
        challengesAcreditados: Array.from(acreditados),
      });

      return { observacionId: observationId, avances, saldoNuevo };
    });

    return resultado;
  }
);
