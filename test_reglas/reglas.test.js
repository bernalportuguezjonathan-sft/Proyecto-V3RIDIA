'use strict';

// Pruebas REALES de firestore.rules contra el emulador de Firestore.
// Se centran en /avistamientos, que es la coleccion que ven todos.

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { setDoc, doc, getDoc, updateDoc, deleteDoc } = require('firebase/firestore');

const RAIZ = path.join(__dirname, '..');
const ANA = 'uid_ana';
const BETO = 'uid_beto';

/** Un avistamiento valido, tal como lo escribe Observation.toMap(). */
function valido(extra = {}) {
  return {
    commonName: 'Colibri chillon',
    scientificName: 'Colibri coruscans',
    location: 'Humedal Guali',
    notes: '',
    dateTime: '2026-09-17T10:00:00.000Z',
    imagePath: 'https://ejemplo.supabase.co/foto.jpg',
    latitude: 4.7235,
    longitude: -74.2255,
    type: 'ave',
    userId: ANA,
    userDisplayName: 'Ana',
    ...extra,
  };
}

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-veridia',
    firestore: {
      rules: fs.readFileSync(path.join(RAIZ, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8085,
    },
  });
});

test.after(async () => {
  if (env) await env.cleanup();
});

test.beforeEach(async () => {
  await env.clearFirestore();
});

/** Firestore de Ana, autenticada. */
function comoAna() {
  return env.authenticatedContext(ANA).firestore();
}
function comoBeto() {
  return env.authenticatedContext(BETO).firestore();
}

// Siembra un avistamiento de Ana saltandose las reglas, para probar
// update/delete sobre algo que ya existe.
async function sembrar(id = 'obs1', datos = valido()) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'avistamientos', id), datos);
  });
}

test('crear: un avistamiento valido pasa', async () => {
  await assertSucceeds(
    setDoc(doc(comoAna(), 'avistamientos', 'obs1'), valido())
  );
});

test('crear: sin sesion no se puede', async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(anon, 'avistamientos', 'obs1'), valido()));
});

test('crear: no se puede publicar en nombre de otro', async () => {
  await assertFails(
    setDoc(doc(comoAna(), 'avistamientos', 'obs1'), valido({ userId: BETO }))
  );
});

test('crear: faltan campos obligatorios', async () => {
  await assertFails(
    setDoc(doc(comoAna(), 'avistamientos', 'obs1'), {
      commonName: 'Algo',
      userId: ANA,
    })
  );
});

test('crear: un campo desconocido se rechaza', async () => {
  await assertFails(
    setDoc(
      doc(comoAna(), 'avistamientos', 'obs1'),
      valido({ campoInventado: 'basura' })
    )
  );
});

test('crear: notas de exactamente el tope pasan', async () => {
  // La frontera importa: el cliente recorta a 500 con recortarCampo(), asi
  // que si la regla rechazara los 500 exactos se perderian avistamientos
  // buenos con un permission-denied.
  await assertSucceeds(
    setDoc(
      doc(comoAna(), 'avistamientos', 'obs1'),
      valido({ notes: 'x'.repeat(500) })
    )
  );
});

test('crear: el nombre comun de exactamente el tope pasa', async () => {
  await assertSucceeds(
    setDoc(
      doc(comoAna(), 'avistamientos', 'obs1'),
      valido({ commonName: 'x'.repeat(120) })
    )
  );
});

test('crear: notas gigantes se rechazan', async () => {
  await assertFails(
    setDoc(
      doc(comoAna(), 'avistamientos', 'obs1'),
      valido({ notes: 'x'.repeat(501) })
    )
  );
});

test('crear: un nombre comun vacio se rechaza', async () => {
  await assertFails(
    setDoc(doc(comoAna(), 'avistamientos', 'obs1'), valido({ commonName: '' }))
  );
});

test('crear: nombre comun demasiado largo se rechaza', async () => {
  await assertFails(
    setDoc(
      doc(comoAna(), 'avistamientos', 'obs1'),
      valido({ commonName: 'x'.repeat(121) })
    )
  );
});

test('crear: coordenadas imposibles se rechazan', async () => {
  await assertFails(
    setDoc(doc(comoAna(), 'avistamientos', 'obs1'), valido({ latitude: 95 }))
  );
  await assertFails(
    setDoc(doc(comoAna(), 'avistamientos', 'obs2'), valido({ longitude: -200 }))
  );
});

test('crear: tipos equivocados se rechazan', async () => {
  await assertFails(
    setDoc(
      doc(comoAna(), 'avistamientos', 'obs1'),
      valido({ latitude: '4.7235' })
    )
  );
  await assertFails(
    setDoc(doc(comoAna(), 'avistamientos', 'obs2'), valido({ notes: 42 }))
  );
});

test('crear: los opcionales en null pasan (foto que no subio, sin GPS)', async () => {
  await assertSucceeds(
    setDoc(
      doc(comoAna(), 'avistamientos', 'obs1'),
      valido({
        imagePath: null,
        latitude: null,
        longitude: null,
        type: null,
        userDisplayName: null,
      })
    )
  );
});

test('leer: cualquier sesion ve el mapa comunitario', async () => {
  await sembrar();
  await assertSucceeds(getDoc(doc(comoBeto(), 'avistamientos', 'obs1')));
});

test('leer: sin sesion no se ve nada', async () => {
  await sembrar();
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'avistamientos', 'obs1')));
});

test('editar: NI SIQUIERA el dueno puede reescribir su avistamiento', async () => {
  // Es el agujero que cierra este cambio: guardar una foto que la IA aprobo
  // y cambiarle despues la especie se saltaba el filtro entero.
  await sembrar();
  await assertFails(
    updateDoc(doc(comoAna(), 'avistamientos', 'obs1'), {
      commonName: 'Lo que yo quiera',
    })
  );
});

test('editar: otro explorador tampoco', async () => {
  await sembrar();
  await assertFails(
    updateDoc(doc(comoBeto(), 'avistamientos', 'obs1'), { commonName: 'X' })
  );
});

test('borrar: el dueno si puede (lo usa el Diario)', async () => {
  await sembrar();
  await assertSucceeds(deleteDoc(doc(comoAna(), 'avistamientos', 'obs1')));
});

test('borrar: otro explorador no puede', async () => {
  await sembrar();
  await assertFails(deleteDoc(doc(comoBeto(), 'avistamientos', 'obs1')));
});

// --- isAdmin() sobre una cuenta sin documento en `users` -------------------
// Antes `get(...).data.role` lanzaba un error de evaluacion y tumbaba la
// regla entera, asi que en un `isAdmin() || esElDueno` se negaba el acceso
// aunque la segunda condicion fuera cierta.

async function sembrarPerfil(uid, role) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {
      email: `${uid}@ejemplo.com`,
      displayName: uid,
      role,
      tokens: 0,
      isBanned: false,
    });
  });
}

async function sembrarCanje(id, uid) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'canjes', id), {
      userId: uid,
      costo: 10,
      estado: 'activo',
    });
  });
}

test('canjes: el dueno lee el suyo aunque aun no tenga perfil', async () => {
  await sembrarCanje('c1', ANA); // Ana NO tiene doc en users
  await assertSucceeds(getDoc(doc(comoAna(), 'canjes', 'c1')));
});

test('canjes: nadie lee el canje de otro', async () => {
  await sembrarCanje('c1', ANA);
  await assertFails(getDoc(doc(comoBeto(), 'canjes', 'c1')));
});

test('canjes: un administrador si lee el de otro', async () => {
  await sembrarCanje('c1', ANA);
  await sembrarPerfil(BETO, 'Administrador');
  await assertSucceeds(getDoc(doc(comoBeto(), 'canjes', 'c1')));
});

test('canjes: un Explorador con perfil sigue sin leer el de otro', async () => {
  await sembrarCanje('c1', ANA);
  await sembrarPerfil(BETO, 'Explorador');
  await assertFails(getDoc(doc(comoBeto(), 'canjes', 'c1')));
});

test('challenges: sumar completadoPor funciona sin perfil', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'challenges', 'd1'), {
      title: 'Insecto',
      assignedToUserId: null,
      completadoPor: 0,
    });
  });
  await assertSucceeds(
    updateDoc(doc(comoAna(), 'challenges', 'd1'), { completadoPor: 1 })
  );
});

test('challenges: no se puede saltar el contador de dos en dos', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'challenges', 'd1'), {
      title: 'Insecto',
      assignedToUserId: null,
      completadoPor: 0,
    });
  });
  await assertFails(
    updateDoc(doc(comoAna(), 'challenges', 'd1'), { completadoPor: 5 })
  );
});

test('challenges: un explorador no puede cambiar el titulo', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'challenges', 'd1'), {
      title: 'Insecto',
      assignedToUserId: null,
      completadoPor: 0,
    });
  });
  await assertFails(
    updateDoc(doc(comoAna(), 'challenges', 'd1'), { title: 'Lo que sea' })
  );
});

