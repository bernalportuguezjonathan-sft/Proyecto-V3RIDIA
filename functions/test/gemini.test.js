'use strict';

const test = require('node:test');
const assert = require('node:assert');

const { evaluarRespuestaIA } = require('../gemini');

// Espejo de test/filtro_especie_test.dart en el lado Flutter. Si los dos
// filtros se desincronizan, la app filtrará distinto el día que se despliegue
// este backend — y eso es justo lo que estos casos existen para impedir.

test('evaluarRespuestaIA — lo que sí sirve', async (t) => {
  await t.test('una especie reconocida en vivo pasa', () => {
    const e = evaluarRespuestaIA({
      identificado: true,
      esSerVivo: true,
      categoriaNoValida: 'ninguna',
      esPantalla: false,
    });
    assert.strictEqual(e.rechazo, 'ninguno');
    assert.strictEqual(e.mensaje, null);
  });

  await t.test('sin los campos nuevos se comporta como antes', () => {
    const e = evaluarRespuestaIA({ identificado: true });
    assert.strictEqual(e.rechazo, 'ninguno');
  });
});

test('evaluarRespuestaIA — personas y objetos', async (t) => {
  await t.test('rechaza una persona aunque la IA la haya identificado', () => {
    const e = evaluarRespuestaIA({
      identificado: true,
      esSerVivo: false,
      categoriaNoValida: 'persona',
      esPantalla: false,
    });
    assert.strictEqual(e.rechazo, 'noEsSerVivo');
    assert.match(e.mensaje, /una persona/);
  });

  await t.test('una categoría no válida manda sobre es_ser_vivo', () => {
    const e = evaluarRespuestaIA({
      identificado: true,
      esSerVivo: true,
      categoriaNoValida: 'vehiculo',
    });
    assert.strictEqual(e.rechazo, 'noEsSerVivo');
  });

  await t.test('una categoría desconocida también rechaza', () => {
    const e = evaluarRespuestaIA({
      identificado: true,
      esSerVivo: false,
      categoriaNoValida: 'algo_que_no_esta_en_la_lista',
    });
    assert.strictEqual(e.rechazo, 'noEsSerVivo');
    assert.match(e.mensaje, /no es una especie/);
  });
});

test('evaluarRespuestaIA — fotos de pantallas', async (t) => {
  await t.test('rechaza una especie real fotografiada de una pantalla', () => {
    const e = evaluarRespuestaIA({
      identificado: true,
      esSerVivo: true,
      categoriaNoValida: 'ninguna',
      esPantalla: true,
    });
    assert.strictEqual(e.rechazo, 'pantallaOImpresion');
    assert.match(e.mensaje, /en vivo/);
  });

  await t.test('lo que no es ser vivo pesa más que la pantalla', () => {
    const e = evaluarRespuestaIA({
      identificado: false,
      esSerVivo: false,
      categoriaNoValida: 'vehiculo',
      esPantalla: true,
    });
    assert.strictEqual(e.rechazo, 'noEsSerVivo');
  });
});

test('evaluarRespuestaIA — no reconocida', async (t) => {
  await t.test('conserva el motivo que dio la IA', () => {
    const e = evaluarRespuestaIA({
      identificado: false,
      esSerVivo: true,
      categoriaNoValida: 'ninguna',
      motivoIA: 'La foto está demasiado borrosa.',
    });
    assert.strictEqual(e.rechazo, 'noIdentificada');
    assert.strictEqual(e.mensaje, 'La foto está demasiado borrosa.');
  });

  await t.test('pone un mensaje propio si la IA no dio motivo', () => {
    const e = evaluarRespuestaIA({ identificado: false, esSerVivo: true });
    assert.strictEqual(e.rechazo, 'noIdentificada');
    assert.match(e.mensaje, /no reconoció/);
  });
});
