-- ============================================================================
-- RLS de Veridia para Supabase Storage (bucket "observaciones")
-- Pegar y ejecutar en: Supabase -> SQL Editor -> New query -> Run
-- ============================================================================
--
-- LEE ESTO ANTES DE EJECUTAR: por qué NO hay SQL para "tablas de Supabase"
-- ----------------------------------------------------------------------------
-- Revisé el proyecto y Supabase aquí es SOLO un bucket de Storage
-- ("observaciones", ver lib/config/supabase_config.dart y
-- lib/services/foto_service.dart) para las fotos. No hay tablas Postgres
-- propias de la app -- toda la base de datos "de verdad" es Firestore. Por
-- eso este archivo solo toca `storage.objects` (la tabla que Supabase usa
-- por debajo para Storage), y la sección 6 de tu pedido sobre RLS "en todas
-- mis tablas" se reduce a esta única tabla.
--
-- Por qué NO hay políticas con auth.uid() -- y qué SÍ puedo darte
-- ----------------------------------------------------------------------------
-- La app NUNCA inicia sesión en Supabase Auth (grep en lib/ lo confirma: solo
-- se llama `Supabase.initialize(url, anonKey)`, nunca `supabase.auth.signIn*`).
-- Toda la identidad real vive en Firebase Auth. Eso significa que, para
-- Supabase, CADA petición -la tuya y la de cualquier otro usuario- llega como
-- el rol `anon`, sin ningún `auth.uid()` que comparar: siempre es NULL.
--
-- Una política tipo `auth.uid() = (storage.foldername(name))[1]` -que es lo
-- que pediste literalmente- NUNCA sería cierta con la configuración actual:
-- NULL nunca es igual a nada, así que esa política dejaría el bucket
-- COMPLETAMENTE INACCESIBLE para subir fotos, incluso para su propio dueño.
-- Escribir esa política tal cual habría roto la app en el primer intento de
-- subida.
--
-- Así que este archivo trae DOS partes:
--   PARTE A: lo que se puede hacer HOY, sin tocar nada más, y que sí protege
--            algo real (nadie puede sobrescribir ni borrar una foto ajena
--            por la vía de Storage, aunque tenga la clave "anon" pública).
--   PARTE B: las políticas de VERDAD por usuario (`auth.uid()` = el UID de
--            Firebase), comentadas y listas para cuando actives "Firebase"
--            como proveedor de terceros en Supabase Auth (Authentication ->
--            Sign In / Providers -> Third Party Auth -> Firebase). Sin ese
--            paso -que se hace en el panel, no por SQL- `auth.uid()` seguirá
--            siendo NULL y la Parte B no cambia nada por sí sola.
--
-- Nota sobre PUBLIC SELECT: el bucket es público a propósito (así lo pide el
-- propio comentario en supabase_config.dart) porque las fotos se muestran en
-- el mapa comunitario a CUALQUIER explorador, no solo al dueño. Por eso
-- ninguna de las dos partes restringe la LECTURA: solo restringen quién
-- puede escribir o borrar.


-- ============================================================================
-- PARTE A -- aplicable ahora mismo, no rompe nada
-- ============================================================================

-- 1) Activar RLS en la tabla que respalda Storage. Si ya estaba activo, esto
--    no hace nada (Postgres lo ignora sin error).
alter table storage.objects enable row level security;

-- 2) Limpieza: si ya existen políticas con estos nombres de una corrida
--    anterior de este mismo script, se reemplazan en vez de duplicarse.
drop policy if exists "observaciones_lectura_publica" on storage.objects;
drop policy if exists "observaciones_solo_insertar" on storage.objects;
drop policy if exists "observaciones_sin_actualizar" on storage.objects;
drop policy if exists "observaciones_sin_borrar" on storage.objects;

-- 3) LECTURA pública: es la razón de ser del bucket (mapa comunitario).
create policy "observaciones_lectura_publica"
on storage.objects for select
to public
using (bucket_id = 'observaciones');

-- 4) ESCRITURA solo por INSERT, y solo con extensión de imagen y dentro de
--    una de las dos rutas que usa la app de verdad:
--      - "{uid}/{observationId}.jpg|.png"   (foto_service.dart: subirFotoObservacion)
--      - "perfiles/{uid}/{timestamp}.jpg|.png" (foto_service.dart: subirFotoPerfil)
--    Esto NO distingue "tu carpeta" de "la carpeta de otro" -eso exige la
--    Parte B-, pero sí cierra la puerta a subir binarios sueltos como
--    "../../lo-que-sea" o sobrescribir rutas que no siguen el patrón de la
--    app. El límite real de "cada quien solo su carpeta" está hoy en que
--    solo la Cloud Function `guardarObservacion` (Admin SDK) crea el
--    documento de Firestore que hace visible una foto en la app: una subida
--    fuera de tu propia carpeta queda huérfana y nadie la ve nunca.
create policy "observaciones_solo_insertar"
on storage.objects for insert
to anon, authenticated
with check (
  bucket_id = 'observaciones'
  and (
    -- {uid}/{observationId}.ext  (dos segmentos)
    (
      array_length(storage.foldername(name), 1) = 1
      and name ~ '^[A-Za-z0-9_-]{1,64}/[A-Za-z0-9_-]{1,64}\.(jpg|jpeg|png)$'
    )
    or
    -- perfiles/{uid}/{timestamp}.ext  (tres segmentos)
    (
      (storage.foldername(name))[1] = 'perfiles'
      and name ~ '^perfiles/[A-Za-z0-9_-]{1,64}/[0-9]{1,20}\.(jpg|jpeg|png)$'
    )
  )
);

-- 5) SIN actualizar: el propio código del cliente ya evita `upsert: true`
--    porque el bucket "solo permite crear objetos" (ver el comentario en
--    _subir() de foto_service.dart) -- esta política es lo que hace cierto
--    ese comentario a nivel de base de datos, no solo de convención.
create policy "observaciones_sin_actualizar"
on storage.objects for update
to anon, authenticated
using (false);

-- 6) SIN borrar desde el cliente. Nada en la app borra fotos hoy; si algún
--    día hace falta (moderación, cuenta eliminada), hazlo con la
--    service_role key desde una Cloud Function, nunca desde el cliente.
create policy "observaciones_sin_borrar"
on storage.objects for delete
to anon, authenticated
using (false);


-- ============================================================================
-- PARTE B -- RLS de verdad por usuario (auth.uid() = UID de Firebase)
-- ============================================================================
-- REQUISITO PREVIO (una sola vez, en el panel, no aquí):
--   Supabase -> Authentication -> Sign In / Providers -> Third Party Auth
--   -> Add provider -> Firebase -> pega el Project ID ("v3ridia").
-- A partir de ahí, cuando el cliente Flutter mande el ID TOKEN de Firebase
-- en la petición a Supabase (con `Supabase.instance.client.auth.setSession`
-- o pasando el JWT en el header `Authorization`), `auth.uid()` pasa a valer
-- el UID de Firebase de quien llama. SIN ese paso, todo lo de abajo evalúa
-- `auth.uid()` como NULL y equivale a "nadie puede escribir nada".
--
-- Descomenta y ejecuta esto DESPUÉS de activar el proveedor:
--
-- drop policy if exists "observaciones_solo_insertar" on storage.objects;
-- create policy "observaciones_insertar_propia_carpeta"
-- on storage.objects for insert
-- to authenticated
-- with check (
--   bucket_id = 'observaciones'
--   and (storage.foldername(name))[1] = auth.uid()::text
-- );
--
-- create policy "observaciones_perfil_propia_carpeta"
-- on storage.objects for insert
-- to authenticated
-- with check (
--   bucket_id = 'observaciones'
--   and (storage.foldername(name))[1] = 'perfiles'
--   and (storage.foldername(name))[2] = auth.uid()::text
-- );
--
-- Con esto sí es cierto, palabra por palabra, lo que pediste: cada usuario
-- solo puede escribir dentro de su propia carpeta, verificado contra su
-- identidad real y no contra lo que el cliente diga que es.
