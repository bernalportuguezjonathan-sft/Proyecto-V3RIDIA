import 'package:flutter/foundation.dart' show kIsWeb;

import 'gemini_config.dart' as local;

/// Clave de Gemini que realmente usa la app, resuelta en tiempo de compilación.
///
/// Orden:
///  1. `--dart-define=GEMINI_API_KEY=...` si se pasó al build.
///  2. `lib/config/gemini_config.dart` — solo en Android/iOS/escritorio.
///  3. Nada: en web se devuelve vacío a propósito.
///
/// **Por qué web nunca cae al archivo local** (comprobado el 2026-08-28): una
/// `const String` de Dart termina en texto plano dentro de `main.dart.js`. Con
/// el sitio publicado en v3ridia.web.app, la clave quedaba descargable por
/// cualquiera con un `curl` — se verificó que aparecía en el bundle y que
/// respondía HTTP 200 sin ninguna restricción de origen. Eso es justo el
/// agujero que `functions/` fue escrito para cerrar, pero ese proxy necesita
/// el plan Blaze y todavía no está desplegado (ver la nota en
/// `especie_ia_service.dart`).
///
/// `kIsWeb` es una constante de compilación, así que en web la rama del
/// archivo local se elimina por tree-shaking y la clave **no llega al bundle**:
/// no depende de que nadie recuerde pasar una bandera. Si alguna vez se quiere
/// la IA en un web local, se pasa `--dart-define=GEMINI_API_KEY=...` a mano —
/// exponerla pasa a ser una decisión explícita, no el comportamiento por
/// defecto.
String get geminiApiKey {
  const desdeBuild = String.fromEnvironment('GEMINI_API_KEY');
  if (desdeBuild.isNotEmpty) return desdeBuild;
  if (kIsWeb) return '';
  return local.geminiApiKey;
}

/// true si la identificación con IA no se puede usar en esta compilación.
bool get faltaClaveGemini =>
    geminiApiKey.isEmpty || geminiApiKey.startsWith('PON_AQUI');
