/// Normaliza un texto para comparar: minúsculas y sin tildes/diéresis.
///
/// Centralizado aquí porque vivía copiado en `models/observation.dart` y
/// `models/bird_zone.dart`, cada uno con su propia tabla de acentos.
String normalizarTexto(String texto) {
  const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sinTilde = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caracter = String.fromCharCode(rune);
    final i = conTilde.indexOf(caracter);
    buffer.write(i >= 0 ? sinTilde[i] : caracter);
  }
  return buffer.toString();
}

/// Palabras de un texto ya normalizado, separadas por cualquier carácter que
/// no sea letra o número.
List<String> palabrasDe(String texto) => normalizarTexto(
  texto,
).split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty).toList();

/// Distancia de edición entre dos textos: cuántas letras hay que insertar,
/// borrar, cambiar o TRASPONER (intercambiar dos letras contiguas) para
/// convertir uno en el otro.
///
/// Incluye la trasposición aparte (variante Damerau-Levenshtein restringida)
/// porque es el error de tipeo más común al escribir rápido en el celular:
/// sin ella, "graza" quedaría a distancia 2 de "garza" (dos sustituciones) y
/// el margen de tolerancia normal no lo perdonaría; con ella queda a
/// distancia 1, como de verdad se siente el error.
int distanciaLevenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final filas = a.length + 1;
  final columnas = b.length + 1;
  final d = List.generate(filas, (_) => List<int>.filled(columnas, 0));
  for (var i = 0; i < filas; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j < columnas; j++) {
    d[0][j] = j;
  }

  for (var i = 1; i < filas; i++) {
    for (var j = 1; j < columnas; j++) {
      final costo = a[i - 1] == b[j - 1] ? 0 : 1;
      var valor = [
        d[i - 1][j] + 1, // borrar
        d[i][j - 1] + 1, // insertar
        d[i - 1][j - 1] + costo, // sustituir
      ].reduce((x, y) => x < y ? x : y);

      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final trasposicion = d[i - 2][j - 2] + 1;
        if (trasposicion < valor) valor = trasposicion;
      }

      d[i][j] = valor;
    }
  }
  return d[a.length][b.length];
}

/// Cuántos errores de tipeo se toleran según el largo de la palabra.
///
/// Palabras muy cortas (3 letras o menos) no toleran ninguno: con tan poca
/// información, "un" y "en" quedarían a distancia 1 y se confundirían entre
/// sí. A partir de ahí la tolerancia crece con el largo, como el modo
/// "fuzziness: AUTO" de los buscadores de texto habituales.
int _tolerancia(int largo) {
  if (largo <= 3) return 0;
  if (largo <= 5) return 1;
  if (largo <= 8) return 2;
  return 3;
}

/// true si dos palabras ya normalizadas se consideran "la misma": iguales,
/// una contiene a la otra (para buscar mientras se escribe) o están dentro
/// del margen de tipeo tolerado para su largo.
bool palabrasSimilares(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b || a.contains(b) || b.contains(a)) return true;
  final tolerancia = _tolerancia(a.length < b.length ? a.length : b.length);
  if (tolerancia == 0) return false;
  return distanciaLevenshtein(a, b) <= tolerancia;
}

/// true si CADA palabra de [consulta] tiene alguna palabra parecida dentro
/// de [textoCompleto] (ya sea el texto entero o cualquiera de sus palabras).
///
/// Exigir todas las palabras (no solo una) evita falsos positivos: buscar
/// "garza real" no debería devolver cualquier avistamiento que solo mencione
/// "real" en la nota.
bool coincideDifuso(String textoCompleto, String consulta) {
  final consultaPalabras = palabrasDe(consulta);
  if (consultaPalabras.isEmpty) return true;

  final normalizado = normalizarTexto(textoCompleto);
  final palabrasTexto = palabrasDe(textoCompleto);

  return consultaPalabras.every((palabraConsulta) {
    if (normalizado.contains(palabraConsulta)) return true;
    return palabrasTexto.any(
      (palabraTexto) => palabrasSimilares(palabraTexto, palabraConsulta),
    );
  });
}
