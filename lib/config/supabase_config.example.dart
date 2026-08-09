// PASO 1: copia este archivo y renómbralo a "supabase_config.dart" (misma carpeta).
// PASO 2: reemplaza los valores por los de tu proyecto de Supabase.
//   - supabaseUrl:     Supabase -> Project Settings -> Data API -> Project URL
//   - supabaseAnonKey: Supabase -> Project Settings -> API Keys -> anon public
// PASO 3: crea un bucket PÚBLICO llamado "observaciones" en Storage.
//
// Si dejas los valores vacíos la app sigue funcionando: las fotos se suben
// entonces a Firebase Storage en vez de Supabase.

const String supabaseUrl = '';
const String supabaseAnonKey = '';
const String supabaseBucket = 'observaciones';
