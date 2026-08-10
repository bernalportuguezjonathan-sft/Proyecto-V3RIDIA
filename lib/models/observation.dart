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
      'dateTime': dateTime.toIso8601String(),
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
      dateTime:
          DateTime.tryParse(map['dateTime'] as String? ?? '') ?? DateTime.now(),
      imagePath: map['imagePath'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      type: map['type'] as String?,
      userId: map['userId'] as String?,
      userDisplayName: map['userDisplayName'] as String?,
    );
  }
}
