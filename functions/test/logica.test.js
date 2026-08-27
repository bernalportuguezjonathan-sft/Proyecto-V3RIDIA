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
