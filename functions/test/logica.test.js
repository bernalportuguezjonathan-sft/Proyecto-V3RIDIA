'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizar,
  palabrasDe,
  especieCoincide,
  calcularBonoCompletar,
  ahashDesdeRgba,
  distanciaHamming,
  UMBRAL_PARECIDO,
} = require('../logica');

describe('normalizar', () => {
  test('quita tildes y pasa a minusculas', () => {
    assert.equal(normalizar('Colibrí Chillón'), 'colibri chillon');
    assert.equal(normalizar('Ñandú'), 'nandu');
  });
});

describe('palabrasDe', () => {
  test('descarta palabras vacias y signos', () => {
    assert.deepEqual(
      palabrasDe('Perro doméstico (Raza Golden Retriever)'),
      ['perro', 'domestico', 'raza', 'golden', 'retriever']
    );
  });
});

describe('especieCoincide', () => {
  function ia({ commonName = null, scientificName = null, type = null } = {}) {
    return { identified: true, commonName, scientificName, type };
  }

  test('exige todas las palabras del objetivo, no una cadena completa', () => {
    // Con un simple "contains", un desafio de "Garza Real" se hubiera dado
    // por cumplido con una "Garza Morena". No debe pasar.
    assert.equal(
      especieCoincide('Garza Real', ia({ commonName: 'Garza Morena' })),
      false
    );
    assert.equal(
      especieCoincide('Garza Real', ia({ commonName: 'Garza Real' })),
      true
    );
  });

  test('tolera singular/plural en ambos lados', () => {
    assert.equal(
      especieCoincide('Perros', ia({ commonName: 'Perro doméstico' })),
      true
    );
    assert.equal(especieCoincide('Aves', ia({ type: 'ave' })), true);
  });

  test('compara tambien contra el nombre cientifico y el tipo', () => {
    assert.equal(
      especieCoincide('Ardea alba', ia({ scientificName: 'Ardea alba' })),
      true
    );
  });

  test('un objetivo vacio nunca coincide', () => {
    assert.equal(especieCoincide('', ia({ commonName: 'Garza Real' })), false);
  });

  test('sin identificacion, no hay coincidencia', () => {
    assert.equal(especieCoincide('Garza Real', ia()), false);
  });
});

describe('calcularBonoCompletar', () => {
  test('da el 10% de la meta redondeado hacia arriba', () => {
    assert.equal(calcularBonoCompletar(10), 1);
    assert.equal(calcularBonoCompletar(20), 2);
    assert.equal(calcularBonoCompletar(100), 10);
  });

  test('nunca da menos de 1 ni mas de 10', () => {
    assert.equal(calcularBonoCompletar(1), 1);
    assert.equal(calcularBonoCompletar(0), 1);
    assert.equal(calcularBonoCompletar(1000), 10);
  });
});

describe('ahashDesdeRgba', () => {
  function rgbaDeGrises(grises) {
    const bytes = Buffer.alloc(64 * 4);
    for (let i = 0; i < 64; i++) {
      bytes[i * 4] = grises[i];
      bytes[i * 4 + 1] = grises[i];
      bytes[i * 4 + 2] = grises[i];
      bytes[i * 4 + 3] = 255;
    }
    return bytes;
  }

  test('mitad oscura y mitad clara da un hash estable', () => {
    const grises = Array.from({ length: 64 }, (_, i) => (i < 32 ? 0 : 255));
    const hash = ahashDesdeRgba(rgbaDeGrises(grises));
    assert.equal(hash.length, 16);
    assert.equal(hash, '00000000ffffffff');
  });

  test('una imagen plana no enciende ningun bit', () => {
    const hash = ahashDesdeRgba(rgbaDeGrises(new Array(64).fill(120)));
    assert.equal(hash, '0'.repeat(16));
  });

  test('devuelve vacio si no llegan 64 pixeles', () => {
    assert.equal(ahashDesdeRgba(Buffer.alloc(10)), '');
  });
});

describe('distanciaHamming', () => {
  test('hashes identicos distan 0', () => {
    assert.equal(distanciaHamming('00ff00ff00ff00ff', '00ff00ff00ff00ff'), 0);
  });

  test('cuenta bits, no caracteres', () => {
    assert.equal(distanciaHamming('1000000000000000', '0000000000000000'), 1);
    assert.equal(distanciaHamming('f000000000000000', '0000000000000000'), 4);
  });

  test('una foto recomprimida sigue bajo el umbral de parecido', () => {
    assert.ok(
      distanciaHamming('ffff0000ffff0000', 'ffff0000ffff0001') <= UMBRAL_PARECIDO
    );
  });

  test('dos fotos distintas superan el umbral', () => {
    assert.ok(
      distanciaHamming('ffffffff00000000', '00000000ffffffff') > UMBRAL_PARECIDO
    );
  });
});

// El resto del archivo usa importaciones desestructuradas; aqui se toma el
// modulo entero para que se vea de un vistazo que estas funciones son el
// espejo de las del lado Dart.
const logica = require('../logica.js');

// ---------------------------------------------------------------------------
// Economia: niveles y mejoras de mascota
//
// Estos casos son el ESPEJO de test/economia_test.dart. Si uno de los dos
// lados cambia y el otro no, uno de los dos archivos se pone rojo, que es
// justo lo que se quiere: sin esto, la app y el servidor pagarian distinto y
// nadie se enteraria hasta que un explorador reclamara.
// ---------------------------------------------------------------------------

const contexto = (extra = {}) => ({
  momento: new Date(2026, 7, 26, 12),
  enHumedal: false,
  tipoEspecie: null,
  especiesDistintasHoy: 1,
  kmDesdeMisFotos: null,
  ...extra,
});

test('nivelDesde sube al cruzar cada umbral', () => {
  assert.equal(logica.nivelDesde(0), 1);
  assert.equal(logica.nivelDesde(14), 1);
  assert.equal(logica.nivelDesde(15), 2);
  assert.equal(logica.nivelDesde(39), 2);
  assert.equal(logica.nivelDesde(40), 3);
  assert.equal(logica.nivelDesde(450), logica.UMBRALES_NIVEL.length);
});

test('nivelDesde no pasa del maximo', () => {
  assert.equal(logica.nivelDesde(999999), logica.UMBRALES_NIVEL.length);
});

test('sin mascota no hay bono', () => {
  assert.equal(logica.bonoDeMascota(null, contexto()).veridiums, 0);
});

test('la rana solo paga en humedal', () => {
  assert.equal(
    logica.bonoDeMascota('rana', contexto({ enHumedal: true })).veridiums,
    logica.bonoDeRareza('rana')
  );
  assert.equal(logica.bonoDeMascota('rana', contexto()).veridiums, 0);
});

test('el currucutu paga de 6 p.m. a 6 a.m.', () => {
  const noche = contexto({ momento: new Date(2026, 7, 26, 20) });
  const madrugada = contexto({ momento: new Date(2026, 7, 26, 5) });
  const tarde = contexto({ momento: new Date(2026, 7, 26, 17) });
  assert.equal(
    logica.bonoDeMascota('currucutu', noche).veridiums,
    logica.bonoDeRareza('currucutu')
  );
  assert.equal(
    logica.bonoDeMascota('currucutu', madrugada).veridiums,
    logica.bonoDeRareza('currucutu')
  );
  assert.equal(logica.bonoDeMascota('currucutu', tarde).veridiums, 0);
});

test('el colibri arranca en la tercera especie distinta y tiene tope', () => {
  const con = (n) => contexto({ especiesDistintasHoy: n });
  assert.equal(logica.bonoDeMascota('colibri', con(2)).veridiums, 0);
  assert.equal(logica.bonoDeMascota('colibri', con(3)).veridiums, 1);
  assert.equal(logica.bonoDeMascota('colibri', con(5)).veridiums, 3);
  assert.equal(logica.bonoDeMascota('colibri', con(30)).veridiums, 3);
});

test('la tucaneta paga lejos de las fotos propias', () => {
  assert.equal(
    logica.bonoDeMascota('tucaneta', contexto({ kmDesdeMisFotos: 8 }))
      .veridiums,
    logica.bonoDeRareza('tucaneta')
  );
  assert.equal(
    logica.bonoDeMascota('tucaneta', contexto({ kmDesdeMisFotos: 0.5 }))
      .veridiums,
    0
  );
});

test('la primera foto con ubicacion cuenta como territorio nuevo', () => {
  assert.equal(
    logica.bonoDeMascota('tucaneta', contexto()).veridiums,
    logica.bonoDeRareza('tucaneta')
  );
});

test('la mariquita paga en plantas y hongos, no en fauna', () => {
  const con = (t) => contexto({ tipoEspecie: t });
  assert.equal(
    logica.bonoDeMascota('mariquita', con('planta')).veridiums,
    logica.bonoDeRareza('mariquita')
  );
  assert.equal(
    logica.bonoDeMascota('mariquita', con('hongo')).veridiums,
    logica.bonoDeRareza('mariquita')
  );
  assert.equal(logica.bonoDeMascota('mariquita', con('ave')).veridiums, 0);
});

test('una mascota desconocida no rompe el pago', () => {
  // Un documento con una clave vieja o corrupta no puede tumbar la funcion:
  // en el peor caso el explorador se queda sin bono, no sin observacion.
  assert.equal(logica.bonoDeMascota('dragon', contexto()).veridiums, 0);
});

test('ninguna mejora se sale de lo que su rareza permite', () => {
  const todo = contexto({
    momento: new Date(2026, 7, 26, 20),
    enHumedal: true,
    tipoEspecie: 'planta',
    especiesDistintasHoy: 50,
    kmDesdeMisFotos: 100,
  });
  for (const m of ['rana', 'currucutu', 'colibri', 'tucaneta', 'mariquita']) {
    const mult = logica.MULTIPLICADOR_RAREZA[logica.RAREZA_DE_MASCOTA[m]];
    const techo = m === 'colibri' ? 3 * mult : logica.bonoDeRareza(m);
    assert.ok(logica.bonoDeMascota(m, todo).veridiums <= techo, m);
  }
});

test('la rareza alta paga al menos el triple que la comun', () => {
  // Es la razon de existir del multiplicador: sin el, la tucaneta de 160
  // Veridiums rendia igual que la rana gratis.
  for (const [mascota, rareza] of Object.entries(logica.RAREZA_DE_MASCOTA)) {
    if (rareza !== 'epica' && rareza !== 'legendaria') continue;
    assert.ok(
      logica.bonoDeRareza(mascota) >= logica.BONO_FIJO_MASCOTA * 3,
      `${mascota} es ${rareza} y paga poco`
    );
  }
});

test('los multiplicadores coinciden con el lado Dart', () => {
  // Espejo literal de `RarezaX.multiplicador` en economia.dart.
  assert.deepEqual(logica.MULTIPLICADOR_RAREZA, {
    comun: 1,
    rara: 2,
    epica: 3,
    legendaria: 4,
  });
  assert.deepEqual(logica.RAREZA_DE_MASCOTA, {
    rana: 'comun',
    colibri: 'comun',
    currucutu: 'rara',
    mariquita: 'epica',
    tucaneta: 'legendaria',
  });
});

test('esZonaDeAguaNormalizada reconoce los cuerpos de agua del JSON', () => {
  assert.equal(logica.esZonaDeAguaNormalizada('humedal guali'), true);
  assert.equal(logica.esZonaDeAguaNormalizada('laguna de la herrera'), true);
  assert.equal(logica.esZonaDeAguaNormalizada('bosque andino'), false);
});

test('claveMovimiento es estable para el mismo hecho', () => {
  assert.equal(
    logica.claveMovimiento('foto', 'obs1'),
    logica.claveMovimiento('foto', 'obs1')
  );
  assert.notEqual(
    logica.claveMovimiento('foto', 'obs1'),
    logica.claveMovimiento('foto', 'obs2')
  );
});
