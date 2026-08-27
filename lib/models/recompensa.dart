import 'package:flutter/material.dart';

import '../theme/veridia_theme.dart';

/// Qué desbloquea una recompensa al canjearla.
enum TipoRecompensa {
  /// Insignia que se muestra en el perfil del explorador.
  insignia,

  /// Marco de color para la foto de perfil.
  marco,

  /// Título que acompaña al nombre.
  titulo,

  /// Algo que un administrador tiene que entregar fuera de la app.
  fisica,
}

extension TipoRecompensaX on TipoRecompensa {
  String get etiqueta => switch (this) {
    TipoRecompensa.insignia => 'Insignia',
    TipoRecompensa.marco => 'Marco',
    TipoRecompensa.titulo => 'Título',
    TipoRecompensa.fisica => 'Experiencia',
  };

  /// Se puede canjear más de una vez.
  ///
  /// Una insignia, un marco o un título repetidos no aportan nada; una
  /// experiencia (una salida de campo, otro kit) sí se puede volver a pedir.
  bool get repetible => this == TipoRecompensa.fisica;

  /// true si la recompensa cambia algo visible en el perfil.
  bool get cambiaElPerfil => this != TipoRecompensa.fisica;
}

class Recompensa {
  const Recompensa({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.costo,
    required this.tipo,
    required this.icono,
    required this.color,
    this.valor,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final int costo;
  final TipoRecompensa tipo;
  final IconData icono;
  final Color color;

  /// Dato que la recompensa aplica al perfil (texto del título, color del
  /// marco...). null en las que no cambian nada visual.
  final String? valor;
}

/// Catálogo fijo de recompensas. Vive en el código y no en Firestore a
/// propósito: los precios son parte del balance del juego, no contenido que
/// un administrador deba poder cambiar en caliente.
///
/// La economía es 1 Veridium por foto verificada + bono al cerrar un desafío,
/// así que los precios están pensados para que la primera insignia se sienta
/// cercana y las experiencias exijan constancia real.
const List<Recompensa> catalogoRecompensas = [
  Recompensa(
    id: 'insignia_explorador',
    nombre: 'Insignia Explorador',
    descripcion:
        'Tu primer sello: acredita que ya registraste especies reales.',
    costo: 10,
    tipo: TipoRecompensa.insignia,
    icono: Icons.explore_rounded,
    color: VeridiaColors.primary,
    valor: '🧭',
  ),
  Recompensa(
    id: 'insignia_guardian',
    nombre: 'Guardián de Humedales',
    descripcion:
        'Para quienes documentan la fauna de los humedales de la Sabana.',
    costo: 25,
    tipo: TipoRecompensa.insignia,
    icono: Icons.water_drop_rounded,
    color: VeridiaColors.secondary,
    valor: '💧',
  ),
  Recompensa(
    id: 'marco_esmeralda',
    nombre: 'Marco Esmeralda',
    descripcion: 'Un aro verde neón alrededor de tu foto de perfil.',
    costo: 40,
    tipo: TipoRecompensa.marco,
    icono: Icons.filter_frames_rounded,
    color: VeridiaColors.secondary,
    valor: 'esmeralda',
  ),
  Recompensa(
    id: 'titulo_naturalista',
    nombre: 'Título: Naturalista de Campo',
    descripcion: 'Aparece junto a tu nombre en el ranking y en tu perfil.',
    costo: 60,
    tipo: TipoRecompensa.titulo,
    icono: Icons.workspace_premium_rounded,
    color: VeridiaColors.veridium,
    valor: 'Naturalista de Campo',
  ),
  Recompensa(
    id: 'marco_dorado',
    nombre: 'Marco Dorado',
    descripcion: 'Reservado para exploradores con recorrido: oro sobre verde.',
    costo: 90,
    tipo: TipoRecompensa.marco,
    icono: Icons.auto_awesome_rounded,
    color: VeridiaColors.veridium,
    valor: 'dorado',
  ),
  Recompensa(
    id: 'certificado_aporte',
    nombre: 'Certificado de contribución',
    descripcion:
        'Se genera al instante con tus avistamientos aportados al monitoreo.',
    costo: 120,
    tipo: TipoRecompensa.fisica,
    icono: Icons.workspace_premium_outlined,
    color: VeridiaColors.tertiary,
  ),
  Recompensa(
    id: 'salida_guiada',
    nombre: 'Salida de campo guiada',
    descripcion:
        'Reservas tu cupo en la próxima jornada de avistamiento con guía.',
    costo: 200,
    tipo: TipoRecompensa.fisica,
    icono: Icons.hiking_rounded,
    color: VeridiaColors.primary,
  ),
  Recompensa(
    id: 'kit_campo',
    nombre: 'Kit de campo Veridia',
    descripcion:
        'Reclamas una libreta de campo y una lupa para seguir documentando.',
    costo: 300,
    tipo: TipoRecompensa.fisica,
    icono: Icons.backpack_rounded,
    color: VeridiaColors.secondary,
  ),
];

Recompensa? recompensaPorId(String id) {
  for (final recompensa in catalogoRecompensas) {
    if (recompensa.id == id) return recompensa;
  }
  return null;
}

/// Estado de un canje ya pagado.
///
/// Todo canje nuevo nace `activo`: el explorador paga y la recompensa es
/// suya en el acto, sin que un administrador tenga que aprobar nada.
/// `pendiente` y `entregado` solo existen para poder leer los canjes que se
/// crearon con el flujo anterior, que sí exigía aprobación.
enum EstadoCanje { activo, pendiente, entregado }

EstadoCanje estadoCanjeDesde(String? texto) => switch (texto) {
  'entregado' => EstadoCanje.entregado,
  'pendiente' => EstadoCanje.pendiente,
  _ => EstadoCanje.activo,
};

extension EstadoCanjeX on EstadoCanje {
  String get clave => name;

  String get etiqueta => switch (this) {
    EstadoCanje.activo => 'Canjeado',
    EstadoCanje.pendiente => 'Canjeado',
    EstadoCanje.entregado => 'Entregado',
  };

  Color get color => switch (this) {
    EstadoCanje.activo => VeridiaColors.secondary,
    EstadoCanje.pendiente => VeridiaColors.secondary,
    EstadoCanje.entregado => VeridiaColors.primary,
  };
}

/// Una recompensa ya comprada por un explorador.
class Canje {
  const Canje({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.recompensaId,
    required this.nombre,
    required this.costo,
    required this.fecha,
    required this.estado,
  });

  final String id;
  final String userId;
  final String userDisplayName;
  final String recompensaId;
  final String nombre;
  final int costo;
  final DateTime fecha;
  final EstadoCanje estado;

  Recompensa? get recompensa => recompensaPorId(recompensaId);

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userDisplayName': userDisplayName,
    'recompensaId': recompensaId,
    'nombre': nombre,
    'costo': costo,
    'fecha': aIsoUtc(fecha),
    'estado': estado.clave,
  };

  factory Canje.fromMap(String id, Map<String, dynamic> map) => Canje(
    id: id,
    userId: map['userId'] as String? ?? '',
    userDisplayName: map['userDisplayName'] as String? ?? 'Explorador',
    recompensaId: map['recompensaId'] as String? ?? '',
    nombre: map['nombre'] as String? ?? 'Recompensa',
    costo: (map['costo'] as num?)?.toInt() ?? 0,
    fecha: deIso(map['fecha'] as String? ?? '') ?? DateTime.now(),
    estado: estadoCanjeDesde(map['estado'] as String?),
  );
}
