'use strict';

/**
 * Lógica pura portada de la app Flutter (lib/services/especie_ia_service.dart,
 * lib/services/huella_foto.dart, lib/models/desafio.dart). Vive separada de
 * index.js para poder probarla con `node --test` sin arrancar Firebase.
 *
 * IMPORTANTE: si algo cambia en el lado Dart (la fórmula del bono, las
 * palabras vacías de especieCoincide, el umbral de parecido de fotos...),
 * hay que replicarlo aquí también. No hay una sola fuente de verdad entre
 * cliente y servidor para esta lógica de comparación de texto.
 */

// ---------- Texto: normalizar y comparar nombres de especie ----------

const PALABRAS_VACIAS = new Set([
  'de',
  'del',
  'la',
  'el',
  'los',
  'las',
  'un',
  'una',
]);

const CON_TILDE = 'áàäâãéèëêíìïîóòöôõúùüûñç';
const SIN_TILDE = 'aaaaaeeeeiiiiooooouuuunc';

function normalizar(texto) {
  let salida = '';
  for (const caracter of String(texto).toLowerCase()) {
    const i = CON_TILDE.indexOf(caracter);
    salida += i >= 0 ? SIN_TILDE[i] : caracter;
  }
  return salida;
}

/** "Perro doméstico (Golden)" -> ["perro", "domestico", "golden"]. */
function palabrasDe(texto) {
  return normalizar(texto)
    .split(/[^a-z0-9]+/)
    .filter((p) => p.length > 0 && !PALABRAS_VACIAS.has(p));
}

/** Formas singular/plural de una palabra, igual que el lado Dart. */
function formasDe(palabra) {
  const formas = new Set([palabra]);
  if (palabra.length > 3 && palabra.endsWith('es')) {
    formas.add(palabra.slice(0, -2));
  }
  if (palabra.length > 2 && palabra.endsWith('s')) {
    formas.add(palabra.slice(0, -1));
  }
  return formas;
}

/**
 * Compara la especie objetivo de un desafío con lo que identificó la IA
 * (nombre común, científico o tipo), palabra por palabra y tolerando
 * singular/plural. Ver la versión Dart para el razonamiento completo.
 */
function especieCoincide(especieObjetivo, identificacion) {
  const objetivo = palabrasDe(especieObjetivo);
  if (objetivo.length === 0) return false;

  function coincideCon(candidato) {
    if (!candidato) return false;
    const palabras = palabrasDe(candidato);
    if (palabras.length === 0) return false;
    const formasCandidato = new Set();
    for (const p of palabras) {
      for (const f of formasDe(p)) formasCandidato.add(f);
    }
    return objetivo.every((p) => {
      for (const f of formasDe(p)) {
        if (formasCandidato.has(f)) return true;
      }
      return false;
    });
  }

  return (
    coincideCon(identificacion.commonName) ||
    coincideCon(identificacion.scientificName) ||
    coincideCon(identificacion.type)
  );
}

// ---------- Economía: bono por cerrar un desafío ----------

/** Igual que calcularBonoCompletar en lib/models/desafio.dart. */
function calcularBonoCompletar(metaGoal) {
  if (metaGoal <= 1) return 1;
  return Math.min(10, Math.max(1, Math.ceil(metaGoal / 10)));
}

// ---------- Huella perceptual de una foto (average hash 8x8) ----------

/**
 * 64 píxeles RGBA (una miniatura de 8x8) -> hash hexadecimal de 16
 * caracteres. Un bit por píxel: 1 si está por encima del brillo medio.
 */
function ahashDesdeRgba(rgba) {
  const total = 64;
  if (rgba.length < total * 4) return '';

  const grises = new Array(total);
  let suma = 0;
  for (let i = 0; i < total; i++) {
    const o = i * 4;
    // Luminancia perceptual (Rec. 601): el verde pesa más que el azul.
    const gris = Math.floor(
      (rgba[o] * 299 + rgba[o + 1] * 587 + rgba[o + 2] * 114) / 1000
    );
    grises[i] = gris;
    suma += gris;
  }

  const promedio = suma / total;
  let hex = '';
  for (let nibble = 0; nibble < total / 4; nibble++) {
    let valor = 0;
    for (let bit = 0; bit < 4; bit++) {
      valor <<= 1;
      if (grises[nibble * 4 + bit] > promedio) valor |= 1;
    }
    hex += valor.toString(16);
  }
  return hex;
}

/** Bits distintos entre dos ahash en hexadecimal. 0 = idénticas. */
function distanciaHamming(hexA, hexB) {
  if (hexA.length !== hexB.length) return 64;
  let distancia = 0;
  for (let i = 0; i < hexA.length; i++) {
    const a = parseInt(hexA[i], 16);
    const b = parseInt(hexB[i], 16);
    if (Number.isNaN(a) || Number.isNaN(b)) return 64;
    let xor = a ^ b;
    while (xor !== 0) {
      distancia += xor & 1;
      xor >>= 1;
    }
  }
  return distancia;
}

/** Bits de diferencia que aún se consideran "la misma foto". */
const UMBRAL_PARECIDO = 5;

module.exports = {
  normalizar,
  palabrasDe,
  formasDe,
  especieCoincide,
  calcularBonoCompletar,
  ahashDesdeRgba,
  distanciaHamming,
  UMBRAL_PARECIDO,
};
