import 'package:flutter/material.dart';

import '../theme/veridia_theme.dart';
import 'observation.dart';

/// Qué mide un logro. Todo sale de datos que la app YA guarda: no hay que
/// registrar nada nuevo ni llevar contadores aparte que se puedan desincronizar.
enum MetricaLogro { veridiumsGanados, especiesDistintas, registros, desafios }

extension MetricaLogroX on MetricaLogro {
  /// Cómo se nombra la unidad en singular y plural, para escribir el
  /// requisito sin un `if` en cada logro.
  String unidad(int cantidad) => switch (this) {
    MetricaLogro.veridiumsGanados => 'Veridiums ganados',
    MetricaLogro.especiesDistintas =>
      cantidad == 1 ? 'especie distinta' : 'especies distintas',
    MetricaLogro.registros => cantidad == 1 ? 'registro' : 'registros',
    MetricaLogro.desafios =>
      cantidad == 1 ? 'desafío completado' : 'desafíos completados',
  };
}

/// Retrato de lo que lleva hecho un explorador.
class EstadisticasExplorador {
  const EstadisticasExplorador({
    this.veridiumsGanados = 0,
    this.especiesDistintas = 0,
    this.registros = 0,
    this.desafios = 0,
  });

  /// Construye el retrato a partir de los avistamientos del explorador.
  ///
  /// Un solo sitio que cuenta, para que el perfil, el carnet y los logros
  /// nunca discrepen entre ellos.
  factory EstadisticasExplorador.de({
    required int veridiumsGanados,
    required List<Observation> fotos,
    required int desafios,
  }) => EstadisticasExplorador(
    veridiumsGanados: veridiumsGanados,
    especiesDistintas: especiesDistintasDe(fotos),
    registros: fotos.length,
    desafios: desafios,
  );

  final int veridiumsGanados;
  final int especiesDistintas;
  final int registros;
  final int desafios;

  int valorDe(MetricaLogro metrica) => switch (metrica) {
    MetricaLogro.veridiumsGanados => veridiumsGanados,
    MetricaLogro.especiesDistintas => especiesDistintas,
    MetricaLogro.registros => registros,
    MetricaLogro.desafios => desafios,
  };
}

/// Algo que se GANA haciendo, no comprando.
///
/// Es la diferencia con las recompensas del catálogo: una recompensa se paga
/// con Veridiums y dice "ahorré"; un logro no se puede comprar y dice "hice
/// esto". El certificado de contribución vivía en la tienda y por eso no
/// acreditaba nada — cualquiera con 120 Veridiums lo tenía sin haber aportado
/// una sola especie al monitoreo. Aquí solo lo consigue quien de verdad
/// registró lo que dice el requisito.
///
/// El catálogo vive en el código, igual que el de recompensas y el de
/// mascotas: las metas son balance del juego, no contenido editable en
/// caliente.
class Logro {
  const Logro({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.metrica,
    required this.meta,
    required this.icono,
    required this.color,
    this.emblema,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final MetricaLogro metrica;

  /// Cuánto hace falta de [metrica] para conseguirlo.
  final int meta;

  final IconData icono;
  final Color color;

  /// Emoji corto para exhibirlo en el perfil y en el carnet, donde no cabe un
  /// icono con su color.
  final String? emblema;

  bool conseguido(EstadisticasExplorador stats) =>
      stats.valorDe(metrica) >= meta;

  /// Avance hacia el logro, de 0.0 a 1.0.
  double progreso(EstadisticasExplorador stats) =>
      meta <= 0 ? 1 : (stats.valorDe(metrica) / meta).clamp(0.0, 1.0);

  /// Cuánto falta, en las unidades de la métrica. 0 si ya está.
  int restante(EstadisticasExplorador stats) {
    final falta = meta - stats.valorDe(metrica);
    return falta < 0 ? 0 : falta;
  }

  /// "20 especies distintas", listo para pintar bajo el nombre.
  String get requisito => '$meta ${metrica.unidad(meta)}';
}

/// Catálogo de logros, del más fácil al más exigente.
///
/// Las metas están calibradas contra la economía real (1 Veridium por foto
/// más las mejoras de mascota): el primero se consigue el primer día y el
/// último exige salir muchas veces, que es lo que tiene que costar.
const List<Logro> catalogoLogros = [
  Logro(
    id: 'primer_avistamiento',
    nombre: 'Primer avistamiento',
    descripcion: 'Registraste tu primera especie con la cámara.',
    metrica: MetricaLogro.registros,
    meta: 1,
    icono: Icons.eco_rounded,
    color: VeridiaColors.primary,
    emblema: '🌱',
  ),
  Logro(
    id: 'ojo_entrenado',
    nombre: 'Ojo entrenado',
    descripcion: 'Diez especies distintas ya no se confunden entre sí.',
    metrica: MetricaLogro.especiesDistintas,
    meta: 10,
    icono: Icons.visibility_rounded,
    color: VeridiaColors.secondary,
    emblema: '👁️',
  ),
  Logro(
    id: 'constancia_campo',
    nombre: 'Constancia de campo',
    descripcion: 'Volviste al campo suficientes veces para ganar 150.',
    metrica: MetricaLogro.veridiumsGanados,
    meta: 150,
    icono: Icons.local_fire_department_rounded,
    color: VeridiaColors.veridium,
    emblema: '🔥',
  ),
  Logro(
    id: 'cierra_desafios',
    nombre: 'Cazador de desafíos',
    descripcion: 'Cinco desafíos cerrados de principio a fin.',
    metrica: MetricaLogro.desafios,
    meta: 5,
    icono: Icons.emoji_events_rounded,
    color: VeridiaColors.veridium,
    emblema: '🏆',
  ),
  // El que antes se compraba en la tienda por 120 Veridiums. Un certificado
  // que se paga no certifica nada: ahora acredita aporte real al monitoreo.
  Logro(
    id: 'certificado_aporte',
    nombre: 'Certificado de contribución',
    descripcion:
        'Veinte especies distintas aportadas al monitoreo de Cundinamarca. '
        'Este certificado acredita tu aporte y no se puede comprar.',
    metrica: MetricaLogro.especiesDistintas,
    meta: 20,
    icono: Icons.workspace_premium_rounded,
    color: VeridiaColors.tertiary,
    emblema: '📜',
  ),
  Logro(
    id: 'guardian_sabana',
    nombre: 'Guardián de la Sabana',
    descripcion: 'Cuarenta especies distintas: media Sabana documentada.',
    metrica: MetricaLogro.especiesDistintas,
    meta: 40,
    icono: Icons.shield_rounded,
    color: VeridiaColors.secondary,
    emblema: '🛡️',
  ),
];

Logro? logroPorId(String? id) {
  if (id == null) return null;
  for (final logro in catalogoLogros) {
    if (logro.id == id) return logro;
  }
  return null;
}

/// Logros ya conseguidos, en el orden del catálogo.
List<Logro> logrosConseguidos(EstadisticasExplorador stats) =>
    catalogoLogros.where((l) => l.conseguido(stats)).toList();

/// Los que faltan, ordenados por lo cerca que están: el siguiente que se
/// puede conseguir va primero, que es el único que motiva.
List<Logro> logrosPendientes(EstadisticasExplorador stats) {
  final pendientes = catalogoLogros.where((l) => !l.conseguido(stats)).toList()
    ..sort((a, b) => b.progreso(stats).compareTo(a.progreso(stats)));
  return pendientes;
}
