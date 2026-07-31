import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class BirdSpecies {
  final String name;
  final String scientificName;
  final String emoji;
  final Color color;
  final String imageUrl;

  const BirdSpecies({
    required this.name,
    required this.scientificName,
    required this.emoji,
    required this.color,
    required this.imageUrl,
  });
}

class BirdZone {
  final String id;
  final String name;
  final String location;
  final String description;
  final String habitat;
  final double latitude;
  final double longitude;
  final Color color;
  final List<LatLng> areaPoints;
  final List<BirdSpecies> species;

  const BirdZone({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.habitat,
    required this.latitude,
    required this.longitude,
    required this.color,
    required this.areaPoints,
    required this.species,
  });
}

final List<BirdZone> birdZones = [
  BirdZone(
    id: 'humedal-este',
    name: 'Humedal de Mosquera',
    location: 'Sector este de Mosquera',
    description:
        'Zona húmeda con árboles de galería, ideal para observar aves de humedal y aves migratorias en la mañana.',
    habitat: 'Humedal y bosque de ribera',
    latitude: 4.7092,
    longitude: -74.2183,
    color: Color(0xFF1E5631),
    areaPoints: [
      LatLng(4.7068, -74.2215),
      LatLng(4.7103, -74.2210),
      LatLng(4.7110, -74.2178),
      LatLng(4.7080, -74.2170),
    ],
    species: [
      BirdSpecies(
        name: 'Garza blanca',
        scientificName: 'Egretta thula',
        emoji: '🦢',
        color: Color(0xFF4CAF50),
        imageUrl: 'https://images.unsplash.com/photo-1517849845537-4d257902454a?auto=format&fit=crop&w=900&q=80',
      ),
      BirdSpecies(
        name: 'Pato crestudo',
        scientificName: 'Sarkidiornis sylvicola',
        emoji: '🦆',
        color: Color(0xFF8BC34A),
        imageUrl: 'https://images.unsplash.com/photo-1474511320723-9a56873867b5?auto=format&fit=crop&w=900&q=80',
      ),
    ],
  ),
  BirdZone(
    id: 'bosque-cerro',
    name: 'Bosque del Cerro El Chical',
    location: 'Zona noroccidental',
    description:
        'Área de bosque con senderos y miradores donde se pueden encontrar aves de sotobosque y zonas abiertas.',
    habitat: 'Bosque andino y borde rural',
    latitude: 4.7146,
    longitude: -74.2267,
    color: Color(0xFF0F766E),
    areaPoints: [
      LatLng(4.7140, -74.2290),
      LatLng(4.7170, -74.2280),
      LatLng(4.7178, -74.2245),
      LatLng(4.7145, -74.2250),
    ],
    species: [
      BirdSpecies(
        name: 'Tórtola',
        scientificName: 'Columbina talpacoti',
        emoji: '🕊️',
        color: Color(0xFF4DB6AC),
        imageUrl: 'https://images.unsplash.com/photo-1544443918-0a8f4f2b7b6e?auto=format&fit=crop&w=900&q=80',
      ),
      BirdSpecies(
        name: 'Benteveo',
        scientificName: 'Pitangus sulphuratus',
        emoji: '🐦',
        color: Color(0xFF26A69A),
        imageUrl: 'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=900&q=80',
      ),
    ],
  ),
  BirdZone(
    id: 'laguna-norte',
    name: 'Laguna de la Vereda Norte',
    location: 'Ruta a la vereda norte',
    description:
        'Lugar con vegetación abierta y cuerpos de agua donde es frecuente ver aves de paso y aves de ambiente abierto.',
    habitat: 'Laguna y sabanas húmedas',
    latitude: 4.7038,
    longitude: -74.2065,
    color: Color(0xFFB45309),
    areaPoints: [
      LatLng(4.7010, -74.2090),
      LatLng(4.7050, -74.2085),
      LatLng(4.7055, -74.2045),
      LatLng(4.7022, -74.2050),
    ],
    species: [
      BirdSpecies(
        name: 'Cotorra',
        scientificName: 'Amazona autumnalis',
        emoji: '🦜',
        color: Color(0xFFFFA000),
        imageUrl: 'https://images.unsplash.com/photo-1444464666168-49d633b86797?auto=format&fit=crop&w=900&q=80',
      ),
      BirdSpecies(
        name: 'Golondrina',
        scientificName: 'Hirundinidae',
        emoji: '🪶',
        color: Color(0xFFFFC107),
        imageUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80',
      ),
    ],
  ),
  BirdZone(
    id: 'sendero-juan',
    name: 'Sendero El Jardín',
    location: 'Corredor ecológico del norte',
    description:
        'Ruta con árboles nativos, fácil para la observación de aves pequeñas, insectívoras y frugívoras.',
    habitat: 'Sendero ecológico y jardín comunitario',
    latitude: 4.7181,
    longitude: -74.2142,
    color: Color(0xFF7C3AED),
    areaPoints: [
      LatLng(4.7160, -74.2165),
      LatLng(4.7200, -74.2158),
      LatLng(4.7206, -74.2120),
      LatLng(4.7168, -74.2126),
    ],
    species: [
      BirdSpecies(
        name: 'Cucarachero',
        scientificName: 'Troglodytes aedon',
        emoji: '🐤',
        color: Color(0xFF8B5CF6),
        imageUrl: 'https://images.unsplash.com/photo-1470115636492-6d2b56f9596d?auto=format&fit=crop&w=900&q=80',
      ),
      BirdSpecies(
        name: 'Gorrión',
        scientificName: 'Passer domesticus',
        emoji: '🐦',
        color: Color(0xFFA78BFA),
        imageUrl: 'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=900&q=80',
      ),
    ],
  ),
];

List<BirdZone> filterBirdZones(
  List<BirdZone> zones, {
  String query = '',
  String? selectedSpecies,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return zones.where((zone) {
    final matchesQuery = normalizedQuery.isEmpty ||
        zone.name.toLowerCase().contains(normalizedQuery) ||
        zone.location.toLowerCase().contains(normalizedQuery) ||
        zone.description.toLowerCase().contains(normalizedQuery) ||
        zone.species.any(
          (species) =>
              species.name.toLowerCase().contains(normalizedQuery) ||
              species.scientificName.toLowerCase().contains(normalizedQuery),
        );

    final matchesSpecies = selectedSpecies == null ||
        selectedSpecies.isEmpty ||
        zone.species.any((species) => species.name == selectedSpecies);

    return matchesQuery && matchesSpecies;
  }).toList();
}

List<String> getAvailableSpecies(List<BirdZone> zones) {
  final species = <String>{};
  for (final zone in zones) {
    for (final speciesItem in zone.species) {
      species.add(speciesItem.name);
    }
  }
  return species.toList()..sort();
}
