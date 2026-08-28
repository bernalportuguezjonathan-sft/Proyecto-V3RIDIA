// PASO 1: copia este archivo y renómbralo a "supabase_config.dart" (misma carpeta).
// PASO 2: reemplaza los valores por los de tu proyecto de Supabase.
//   - supabaseUrl:     Supabase -> Project Settings -> Data API -> Project URL
//   - supabaseAnonKey: Supabase -> Project Settings -> API Keys -> anon public
// PASO 3: crea un bucket PÚBLICO llamado "observaciones" en Storage y ejecuta
//         supabase_rls.sql (SQL Editor) para sus políticas de acceso.
//
// ESTOS VALORES SON OBLIGATORIOS. Sin ellos NO hay dónde guardar las fotos y
// las observaciones se guardan sin imagen (se ve el marco vacío en el Diario).
//
// (Corregido el 2026-08-28: aquí decía que al dejarlo vacío las fotos "se
// suben a Firebase Storage". Eso es FALSO desde hace tiempo y costó una tarde
// de depuración: firebase_storage ya ni siquiera está en pubspec.yaml, y
// foto_service.dart dice explícitamente que Supabase es el único proveedor
// porque el bucket de Firebase nunca se aprovisionó -- responde 404.)

const String supabaseUrl = '';
const String supabaseAnonKey = '';
const String supabaseBucket = 'observaciones';
