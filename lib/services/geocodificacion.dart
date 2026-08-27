import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Un lugar encontrado en el mapa mundial, no solo entre las zonas
/// curadas de Veridia (humedales, laguna, parques...).
class LugarEncontrado {
  const LugarEncontrado({
    required this.nombre,
    required this.categoria,
    required this.latitude,
    required this.longitude,
  });

  final String nombre;

  /// Ej: "laguna", "parque", "ciudad"... viene tal cual de OpenStreetMap.
  final String categoria;

  final double latitude;
  final double longitude;

  factory LugarEncontrado.fromJson(Map<String, dynamic> json) {
    return LugarEncontrado(
      nombre: json['display_name'] as String? ?? 'Lugar sin nombre',
      categoria: json['type'] as String? ?? json['class'] as String? ?? 'lugar',
      latitude: double.parse(json['lat'] as String),
      longitude: double.parse(json['lon'] as String),
    );
  }
}

class LugarBusquedaException implements Exception {
  LugarBusquedaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Busca lugares reales por nombre (ríos, veredas, laguna de la Herrera,
/// barrios...), estén o no en el mapa curado de Veridia.
///
/// Usa Nominatim, el geocodificador gratuito de OpenStreetMap: no exige
/// clave, pero su política de uso pide como máximo ~1 petición por segundo y
/// un User-Agent que identifique la app — por eso solo se llama al enviar la
/// búsqueda, nunca en cada tecla.
class GeocodificacionService {
  GeocodificacionService._();

  /// Identifica la app ante Nominatim, como exige su política de uso.
  /// Sin contacto personal: no hace falta y no hay por qué compartirlo.
  static const _userAgent = 'VeridiaApp/1.0 (proyecto educativo SENA)';

  /// Cundinamarca y alrededores, para que "Funza" no traiga primero una
  /// ciudad homónima en otro país. No se acota del todo (`bounded=0`) para
  /// que un lugar real fuera de esa caja —Bogotá, otro departamento— se
  /// pueda seguir encontrando, solo que con menos prioridad.
  static const _cajaCundinamarca = '-75.0,5.4,-73.4,3.8';

  static Future<List<LugarEncontrado>> buscar(String consulta) async {
    final texto = consulta.trim();
    if (texto.isEmpty) return [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': texto,
      'format': 'jsonv2',
      'limit': '6',
      'countrycodes': 'co',
      'viewbox': _cajaCundinamarca,
      'bounded': '0',
      'accept-language': 'es',
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw LugarBusquedaException(
          'El buscador de lugares no respondió (código ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((item) => LugarEncontrado.fromJson(item as Map<String, dynamic>))
          .toList();
    } on LugarBusquedaException {
      rethrow;
    } catch (e) {
      debugPrint('GeocodificacionService.buscar error: $e');
      throw LugarBusquedaException(
        'No se pudo buscar el lugar. Revisa tu conexión a internet.',
      );
    }
  }
}
