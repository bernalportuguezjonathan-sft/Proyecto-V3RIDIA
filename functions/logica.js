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

// ---------- Economia: niveles y mejoras de mascota ----------
//
// Espejo EXACTO de lib/services/economia.dart. Si cambian los umbrales, el
// bono fijo o la condicion de una mejora en el lado Dart, hay que cambiarlos
// aqui tambien: el dia que esto se despliegue, el servidor va a recalcular lo
// mismo que la app ya le mostro al explorador, y una diferencia de un solo
// Veridium se ve como un pago que "no llego".

/** Veridiums GANADOS EN TOTAL que hacen falta para cada nivel. */
const UMBRALES_NIVEL = [0, 15, 40, 80, 140, 220, 320, 450];

/** Nivel segun el acumulado historico (nunca segun el saldo). */
function nivelDesde(totalGanado) {
  let nivel = 1;
  for (let i = 1; i < UMBRALES_NIVEL.length; i++) {
    if (totalGanado >= UMBRALES_NIVEL[i]) nivel = i + 1;
  }
  return nivel;
}

/** Bono fijo de las mejoras que son de si/no. */
const BONO_FIJO_MASCOTA = 2;

/** Kilometros a partir de los cuales una foto cuenta como territorio nuevo. */
const KM_TERRITORIO_NUEVO = 3;

const COLIBRI_DESDE_ESPECIE = 3;
const COLIBRI_MAXIMO = 3;

/**
 * Rareza de cada mascota y por cuanto multiplica su mejora.
 *
 * Espejo de `Rareza` y `rarezaDeMascota` en lib/services/economia.dart. Sin
 * esto, la app pagaria x4 por la tucaneta y el servidor x1: el explorador
 * veria el bono en pantalla y luego no le llegaria.
 */
const MULTIPLICADOR_RAREZA = {
  comun: 1,
  rara: 2,
  epica: 3,
  legendaria: 4,
};

const RAREZA_DE_MASCOTA = {
  rana: 'comun',
  colibri: 'comun',
  currucutu: 'rara',
  mariquita: 'epica',
  tucaneta: 'legendaria',
};

/** Veridiums que paga la mejora de esa mascota cuando se cumple. */
function bonoDeRareza(mascota) {
  const rareza = RAREZA_DE_MASCOTA[mascota] || 'comun';
  return BONO_FIJO_MASCOTA * MULTIPLICADOR_RAREZA[rareza];
}

const PALABRAS_DE_AGUA = [
  'humedal',
  'laguna',
  'pantano',
  'cienaga',
  'embalse',
  'represa',
  'quebrada',
  'rio ',
  'lago',
  'acuatic',
];

/** true si el texto de una zona (ya normalizado) la delata como agua. */
function esZonaDeAguaNormalizada(textoNormalizado) {
  return PALABRAS_DE_AGUA.some((p) => textoNormalizado.includes(p));
}

/**
 * Veridiums extra que aporta la mascota activa a una foto.
 *
 * `contexto` = { momento: Date, enHumedal, tipoEspecie, especiesDistintasHoy,
 * kmDesdeMisFotos }. Devuelve { veridiums, motivo }.
 */
function bonoDeMascota(mascota, contexto) {
  const ninguno = { veridiums: 0, motivo: null };
  if (!mascota) return ninguno;

  const bono = bonoDeRareza(mascota);
  const multiplicador =
    MULTIPLICADOR_RAREZA[RAREZA_DE_MASCOTA[mascota] || 'comun'];

  const hora = contexto.momento.getHours();
  const esDeNoche = hora >= 18 || hora < 6;
  const esCultivo =
    contexto.tipoEspecie === 'planta' || contexto.tipoEspecie === 'hongo';
  const km = contexto.kmDesdeMisFotos;
  const esTerritorioNuevo =
    km === null || km === undefined || km >= KM_TERRITORIO_NUEVO;

  switch (mascota) {
    case 'rana':
      return contexto.enHumedal
        ? { veridiums: bono, motivo: 'Bioindicadora: foto en humedal' }
        : ninguno;

    case 'currucutu':
      return esDeNoche
        ? {
            veridiums: bono,
            motivo: 'Ojo nocturno: registro entre 6 p.m. y 6 a.m.',
          }
        : ninguno;

    case 'colibri': {
      const hoy = contexto.especiesDistintasHoy || 0;
      const extra = hoy - (COLIBRI_DESDE_ESPECIE - 1);
      if (extra <= 0) return ninguno;
      return {
        veridiums:
          Math.min(COLIBRI_MAXIMO, Math.max(1, extra)) * multiplicador,
        motivo: `Polinizador: ${hoy} especies distintas hoy`,
      };
    }

    case 'tucaneta':
      return esTerritorioNuevo
        ? {
            veridiums: bono,
            motivo: 'Dispersora: territorio nuevo para ti',
          }
        : ninguno;

    case 'mariquita':
      return esCultivo
        ? {
            veridiums: bono,
            motivo: 'Control biologico: diagnostico de cultivo',
          }
        : ninguno;

    default:
      return ninguno;
  }
}

/**
 * Clave de idempotencia de un movimiento de Veridiums: el id del documento en
 * users/{uid}/movimientos. No lleva la hora a proposito — tiene que ser la
 * misma para el mismo hecho, se reintente cuando se reintente.
 */
function claveMovimiento(motivo, referencia) {
  return `${motivo}_${referencia}`;
}

module.exports = {
  normalizar,
  palabrasDe,
  formasDe,
  especieCoincide,
  calcularBonoCompletar,
  ahashDesdeRgba,
  distanciaHamming,
  UMBRAL_PARECIDO,
  UMBRALES_NIVEL,
  nivelDesde,
  BONO_FIJO_MASCOTA,
  KM_TERRITORIO_NUEVO,
  esZonaDeAguaNormalizada,
  bonoDeMascota,
  bonoDeRareza,
  MULTIPLICADOR_RAREZA,
  RAREZA_DE_MASCOTA,
  claveMovimiento,
};
