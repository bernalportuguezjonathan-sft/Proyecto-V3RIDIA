import 'package:flutter/material.dart';

import '../models/mascota.dart';
import '../theme/veridia_theme.dart';
import 'pixel_sprite.dart';

/// La mascota dibujada con lo que lleve puesto.
///
/// Compone tres cosas en el orden correcto:
/// 1. El aura, DETRÁS de todo.
/// 2. La mascota, con su parpadeo.
/// 3. El accesorio de cabeza, desplazado según dónde tenga la cabeza ESA
///    mascota (ver `anclaCabeza`).
///
/// El objeto no es una capa de la rejilla sino un sprite aparte pegado abajo
/// a la derecha: dibujarlo dentro de los 16x16 obligaría a dejar libre un
/// cuarto del lienzo en las cinco mascotas, y quedarían todas raquíticas.
class MascotaVista extends StatelessWidget {
  const MascotaVista({
    super.key,
    required this.mascota,
    this.equipado = const {},
    this.tamano = 64,
    this.animar = true,
    this.opacidad = 1,
  });

  final Mascota mascota;

  /// Accesorio puesto en cada ranura. Una ranura sin entrada va vacía.
  final Map<RanuraAccesorio, Accesorio> equipado;

  final double tamano;
  final bool animar;
  final double opacidad;

  @override
  Widget build(BuildContext context) {
    final aura = equipado[RanuraAccesorio.aura];
    final cabeza = equipado[RanuraAccesorio.cabeza];
    final objeto = equipado[RanuraAccesorio.objeto];

    final capas = <PixelArt>[
      if (aura != null) aura.sprite,
      mascota.sprite,
      if (cabeza != null)
        cabeza.sprite.desplazado(
          dx: mascota.anclaCabeza.dx.round(),
          dy: mascota.anclaCabeza.dy.round(),
        ),
    ];

    final cuerpo = PixelSpriteAnimado(
      capas: capas,
      parpadeo: mascota.parpadeo,
      tamano: tamano,
      animar: animar,
      opacidad: opacidad,
    );

    if (objeto == null) return cuerpo;

    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          cuerpo,
          Positioned(
            right: -tamano * 0.06,
            bottom: tamano * 0.04,
            child: PixelSprite(
              capas: [objeto.sprite],
              tamano: tamano * 0.42,
              opacidad: opacidad,
            ),
          ),
        ],
      ),
    );
  }
}

/// La mascota dentro de un disco de color, para listas y cabeceras.
class MascotaAvatar extends StatelessWidget {
  const MascotaAvatar({
    super.key,
    required this.mascota,
    this.equipado = const {},
    this.tamano = 72,
    this.animar = true,
    this.apagada = false,
  });

  final Mascota mascota;
  final Map<RanuraAccesorio, Accesorio> equipado;
  final double tamano;
  final bool animar;

  /// Se dibuja en gris cuando el explorador todavía no la tiene.
  final bool apagada;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: apagada
            ? VeridiaColors.surfaceContainerHigh
            : mascota.color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: apagada
              ? VeridiaColors.outlineVariant
              : mascota.color.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Center(
        child: MascotaVista(
          mascota: mascota,
          equipado: equipado,
          tamano: tamano * 0.72,
          animar: animar && !apagada,
          opacidad: apagada ? 0.35 : 1,
        ),
      ),
    );
  }
}
