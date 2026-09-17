import '../theme/veridia_theme.dart';
import '../utils/texto_busqueda.dart';

class Observation {
  Observation({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.location,
    required this.notes,
    required this.dateTime,
    this.imagePath,
    this.latitude,
    this.longitude,
    this.type,
    this.userId,
    this.userDisplayName,
  });

  final String id;
  final String commonName;
  final String scientificName;
  final String location;
  final String notes;
  final DateTime dateTime;
  final String? imagePath;
  final double? latitude;
  final double? longitude;
  final String? type;
  final String? userId;
  final String? userDisplayName;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// true si `imagePath` es una URL descargable (Supabase o Firebase Storage).
  bool get hasPhoto => imagePath != null && imagePath!.startsWith('http');

  Map<String, dynamic> toMap() {
    return {
      'commonName': commonName,
      'scientificName': scientificName,
      'location': location,
      'notes': notes,
      'dateTime': aIsoUtc(dateTime),
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'userId': userId,
      'userDisplayName': userDisplayName,
    };
  }

  factory Observation.fromMap(String id, Map<String, dynamic> map) {
    return Observation(
      id: id,
      commonName: map['commonName'] as String? ?? 'Especie observada',
      scientificName: map['scientificName'] as String? ?? 'Sin confirmar',
      location: map['location'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      dateTime: deIso(map['dateTime'] as String? ?? '') ?? DateTime.now(),
      imagePath: map['imagePath'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      type: map['type'] as String?,
      userId: map['userId'] as String?,
      userDisplayName: map['userDisplayName'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Topes de longitud de cada campo
// ---------------------------------------------------------------------------
// Son EXACTAMENTE los mismos que valida `firestore.rules` en
// `avistamientoValido()`. Si se cambia uno hay que cambiar el otro.
//
// Existen en los dos sitios a propósito y con papeles distintos: el cliente
// recorta antes de escribir para que un texto largo de la IA no acabe en un
// permission-denied que el explorador no entiende, y la regla los vuelve a
// comprobar para que un cliente modificado tampoco pueda saltárselos.
//
// El que de verdad hacía falta es `notes`: sale de la descripción que devuelve
// Gemini, que es texto libre. Pedirle "1 o 2 frases" no es una garantía.

const topeCommonName = 120;
const topeScientificName = 160;
const topeLocation = 200;
const topeNotes = 500;
const topeImagePath = 500;
const topeType = 40;
const topeUserDisplayName = 120;

/// Recorta un texto al tope, sin partir una letra por la mitad.
///
/// Se mide con `length` de Dart (unidades UTF-16), que para cualquier carácter
/// fuera del plano básico cuenta MÁS que el `size()` de las reglas de
/// Firestore. Equivocarse por ese lado es inofensivo: recorta de más, nunca
/// de menos, así que lo que se escribe siempre cabe.
String recortarCampo(String texto, int tope) {
  if (texto.length <= tope) return texto;
  var corte = tope;
  // Cortar entre las dos mitades de un par sustituto dejaría media letra y un
  // texto inválido que Firestore rechaza.
  final ultima = texto.codeUnitAt(corte - 1);
  if (ultima >= 0xD800 && ultima <= 0xDBFF) corte -= 1;
  return texto.substring(0, corte).trimRight();
}

/// El texto ya limpio, o null si venía vacío o solo con espacios.
///
/// La IA puede devolver `""` en vez de null, y un nombre común vacío no es un
/// nombre: la regla exige que tenga al menos un carácter.
String? textoONull(String? texto) {
  final limpio = texto?.trim();
  return (limpio == null || limpio.isEmpty) ? null : limpio;
}

/// La coordenada si es utilizable, o null.
///
/// Descarta NaN, infinitos y puntos fuera del planeta. Un valor así no se
/// puede dibujar en el mapa y además hace que la regla rechace el avistamiento
/// entero, así que es mejor guardar el avistamiento sin punto que perderlo.
double? coordenadaValida(double? valor, {required double maximo}) {
  if (valor == null || valor.isNaN || valor.isInfinite) return null;
  if (valor < -maximo || valor > maximo) return null;
  return valor;
}

/// true si la observación responde a la búsqueda (nombre común, científico,
/// tipo, lugar, notas o quién la registró).
///
/// Es difusa: tolera errores de tipeo razonables (ver
/// `utils/texto_busqueda.dart`), así "colibries" o "colibrí" encuentran
/// igual una foto guardada como "Colibrí Chillón".
bool observacionCoincide(Observation observacion, String consulta) {
  final campos = [
    observacion.commonName,
    observacion.scientificName,
    observacion.type ?? '',
    observacion.location,
    observacion.notes,
    observacion.userDisplayName ?? '',
  ].join(' ');
  return coincideDifuso(campos, consulta);
}

/// Filtra avistamientos por texto libre y, opcionalmente, por especie exacta
/// (la misma que selecciona el chip de especies del mapa).
List<Observation> filtrarObservaciones(
  List<Observation> observaciones, {
  String query = '',
  String? especie,
}) {
  return observaciones.where((observacion) {
    if (!observacionCoincide(observacion, query)) return false;
    if (especie == null || especie.isEmpty) return true;
    final nombres = '${observacion.commonName} ${observacion.scientificName}';
    return coincideDifuso(nombres, especie);
  }).toList();
}

/// Nombre con el que se guarda una especie que la IA no logró identificar.
/// No cuenta como "especie única": inflaría la cifra sin aportar nada.
const _especieSinIdentificar = {
  'especie observada',
  'sin confirmar',
  'referencia visual',
};

/// true si la observación tiene una especie de verdad detrás.
bool especieIdentificada(Observation observacion) => !_especieSinIdentificar
    .contains(observacion.commonName.trim().toLowerCase());

/// Cuántas especies DISTINTAS e identificadas hay en una lista.
///
/// Vive aquí y no en cada pantalla porque el carnet, los logros y la
/// analítica tienen que contar exactamente igual: si una dijera 12 especies y
/// otra 15, la que se ve peor parece rota.
int especiesDistintasDe(Iterable<Observation> observaciones) => observaciones
    .where(especieIdentificada)
    .map((o) => o.commonName.trim().toLowerCase())
    .toSet()
    .length;
