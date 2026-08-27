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
