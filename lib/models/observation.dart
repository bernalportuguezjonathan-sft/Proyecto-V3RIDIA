class Observation {
  Observation({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.location,
    required this.notes,
    required this.dateTime,
  });

  final String id;
  final String commonName;
  final String scientificName;
  final String location;
  final String notes;
  final DateTime dateTime;
}
