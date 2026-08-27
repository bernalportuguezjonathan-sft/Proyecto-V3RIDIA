import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../theme/veridia_theme.dart';
import '../utils/texto_busqueda.dart';

class BirdSpecies {
  final String name;
  final String scientificName;
  final String descriptionHabitat;
  final String emoji;
  final Color color;
  final String imageUrl;

  const BirdSpecies({
    required this.name,
    required this.scientificName,
    required this.descriptionHabitat,
    required this.emoji,
    required this.color,
    required this.imageUrl,
  });

  factory BirdSpecies.fromJson(Map<String, dynamic> json) {
    final name = json['nombre_comun'] as String;
    return BirdSpecies(
      name: name,
      scientificName: json['nombre_cientifico'] as String,
      descriptionHabitat:
          json['descripcion'] as String? ??
          json['descripcion_habitat'] as String? ??
          '',
      emoji: _emojiForSpecies(name),
      color: _colorForSpecies(name),
      imageUrl:
          json['url_imagen'] as String? ?? json['imagen_url'] as String? ?? '',
    );
  }
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

  factory BirdZone.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final coordinates = json['coordenadas'] as Map<String, dynamic>;
    final latitude = (coordinates['latitud'] as num).toDouble();
    final longitude = (coordinates['longitud'] as num).toDouble();
    final speciesJson =
        (json['especies'] as List<dynamic>? ??
                json['especies_destacadas'] as List<dynamic>)
            .map((item) => BirdSpecies.fromJson(item as Map<String, dynamic>))
            .toList();

    return BirdZone(
      id: id,
      name: json['nombre_zona'] as String? ?? json['nombre'] as String,
      location: json['municipio'] as String? ?? 'Mosquera',
      description:
          json['descripcion_zona'] as String? ??
          json['descripcion'] as String? ??
          '',
      habitat:
          json['habitat'] as String? ??
          json['descripcion_zona'] as String? ??
          '',
      latitude: latitude,
      longitude: longitude,
      color: _colorForZone(id),
      areaPoints: _areaPointsForZone(id, latitude, longitude),
      species: speciesJson,
    );
  }
}

Future<List<BirdZone>> loadBirdZones() async {
  try {
    final String jsonString = await rootBundle.loadString(
      'assets/data/mosquera_birds.json',
    );
    final List<dynamic> zonesJson = jsonDecode(jsonString) as List<dynamic>;
    return zonesJson
        .map((item) => BirdZone.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Color _colorForZone(String id) {
  switch (id) {
    case 'humedal-guali':
      return VeridiaColors.primary;
    case 'laguna-la-herrera':
      return const Color(0xFF0F766E);
    case 'parque-principal-mosquera':
      return const Color(0xFFB45309);
    case 'parque-de-la-sabana':
      return const Color(0xFF7C3AED);
    default:
      return VeridiaColors.primary;
  }
}

Color _colorForSpecies(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tingua')) return const Color(0xFF4CAF50);
  if (lower.contains('garza')) return const Color(0xFF8BC34A);
  if (lower.contains('pato')) return const Color(0xFF388E3C);
  if (lower.contains('monjita')) return const Color(0xFF66BB6A);
  if (lower.contains('copetón') || lower.contains('copeton')) {
    return const Color(0xFF3F51B5);
  }
  if (lower.contains('mirla')) return const Color(0xFF009688);
  if (lower.contains('colibrí') || lower.contains('colibri')) {
    return const Color(0xFFFFA000);
  }
  return VeridiaColors.primary;
}

String _emojiForSpecies(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tingua')) return '🦆';
  if (lower.contains('garza')) return '🦢';
  if (lower.contains('pato')) return '🦆';
  if (lower.contains('monjita')) return '🐦';
  if (lower.contains('copetón') || lower.contains('copeton')) return '🐦';
  if (lower.contains('mirla')) return '🐦';
  if (lower.contains('colibrí') || lower.contains('colibri')) return '🪶';
  return '🐦';
}

List<LatLng> _areaPointsForZone(String id, double latitude, double longitude) {
  switch (id) {
    case 'humedal-guali':
      return [
        LatLng(latitude - 0.0035, longitude - 0.0025),
        LatLng(latitude + 0.0010, longitude - 0.0020),
        LatLng(latitude + 0.0014, longitude + 0.0013),
        LatLng(latitude - 0.0020, longitude + 0.0010),
      ];
    case 'laguna-la-herrera':
      return [
        LatLng(latitude - 0.0032, longitude - 0.0018),
        LatLng(latitude + 0.0020, longitude - 0.0015),
        LatLng(latitude + 0.0018, longitude + 0.0020),
        LatLng(latitude - 0.0021, longitude + 0.0018),
      ];
    case 'parque-principal-mosquera':
      return [
        LatLng(latitude - 0.0020, longitude - 0.0019),
        LatLng(latitude + 0.0018, longitude - 0.0016),
        LatLng(latitude + 0.0017, longitude + 0.0017),
        LatLng(latitude - 0.0018, longitude + 0.0014),
      ];
    case 'parque-de-la-sabana':
      return [
        LatLng(latitude - 0.0018, longitude - 0.0015),
        LatLng(latitude + 0.0019, longitude - 0.0012),
        LatLng(latitude + 0.0017, longitude + 0.0016),
        LatLng(latitude - 0.0017, longitude + 0.0013),
      ];
    default:
      return [
        LatLng(latitude - 0.0015, longitude - 0.0010),
        LatLng(latitude + 0.0015, longitude - 0.0010),
        LatLng(latitude + 0.0015, longitude + 0.0010),
        LatLng(latitude - 0.0015, longitude + 0.0010),
      ];
  }
}

/// Todo el texto buscable de una zona en un solo bloque: nombre, ubicación,
/// descripción y sus especies (comunes y científicas).
String _textoBuscableDeZona(BirdZone zone) => [
  zone.name,
  zone.location,
  zone.description,
  zone.habitat,
  for (final s in zone.species) ...[s.name, s.scientificName],
].join(' ');

/// Filtra zonas por texto libre y, si se eligió un chip, por especie exacta.
///
/// La búsqueda de texto es difusa (ver `utils/texto_busqueda.dart`): admite
/// errores de tipeo razonables y no exige que la palabra esté completa, así
/// "graza" o "gars" encuentran igual "Garza Real".
List<BirdZone> filterBirdZones(
  List<BirdZone> zones, {
  String query = '',
  String? selectedSpecies,
}) {
  return zones.where((zone) {
    final matchesQuery = coincideDifuso(_textoBuscableDeZona(zone), query);

    final matchesSpecies =
        selectedSpecies == null ||
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

/// true si el punto cae dentro del polígono de la zona (ray casting).
bool zonaContiene(BirdZone zona, double lat, double lng) {
  final puntos = zona.areaPoints;
  if (puntos.length < 3) return false;

  var dentro = false;
  for (var i = 0, j = puntos.length - 1; i < puntos.length; j = i++) {
    final yi = puntos[i].latitude, xi = puntos[i].longitude;
    final yj = puntos[j].latitude, xj = puntos[j].longitude;
    final cruza =
        (yi > lat) != (yj > lat) &&
        lng < (xj - xi) * (lat - yi) / (yj - yi) + xi;
    if (cruza) dentro = !dentro;
  }
  return dentro;
}

/// Zona a la que pertenece un punto: primero por polígono y, si cae fuera de
/// todos, la más cercana dentro de [radioKm].
///
/// Los polígonos de las zonas son pequeños (unos cientos de metros) y el GPS
/// de un celular tiene error: sin el radio de cortesía, casi ninguna foto
/// quedaría asignada a su zona.
BirdZone? zonaDePunto(
  List<BirdZone> zonas,
  double lat,
  double lng, {
  double radioKm = 3,
}) {
  for (final zona in zonas) {
    if (zonaContiene(zona, lat, lng)) return zona;
  }

  const distancia = Distance();
  BirdZone? mejor;
  var mejorKm = double.infinity;
  for (final zona in zonas) {
    final km = distancia.as(
      LengthUnit.Kilometer,
      LatLng(lat, lng),
      LatLng(zona.latitude, zona.longitude),
    );
    if (km < mejorKm) {
      mejorKm = km.toDouble();
      mejor = zona;
    }
  }
  return mejorKm <= radioKm ? mejor : null;
}
