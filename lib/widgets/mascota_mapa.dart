import 'package:flutter/material.dart';

import '../models/mascota.dart';
import '../theme/veridia_theme.dart';
import 'mascota_vista.dart';

/// La mascota sobre el botón de registrar especie, en su placa.
///
/// La placa no es decoración: sin ella el sprite se pierde contra el mapa.
/// Las teselas de OpenStreetMap son claras y llenas de líneas y etiquetas, y
/// un dibujo de 16x16 con contorno oscuro encima de eso se lee como una
/// mancha más. El fondo le da un borde limpio contra el que recortarse.
///
/// El color sale de la propia mascota, aclarado: cada compañero trae su placa
/// y se distinguen entre sí de un vistazo, sin pintar cinco fondos a mano. Se
/// mantiene pálido a propósito —los sprites tienen contornos oscuros y sobre
/// un fondo saturado se emborronarían— y pequeño, para que destaque a la
/// mascota sin convertirse él mismo en el elemento grande de la esquina.
class MascotaEnMapa extends StatelessWidget {
  const MascotaEnMapa({
    super.key,
    required this.mascota,
    this.equipado = const {},
    this.tamano = 34,
    this.conPlaca = true,
  });

  final Mascota mascota;
  final Map<RanuraAccesorio, Accesorio> equipado;

  /// Lado del sprite. La placa se dimensiona a partir de él.
  final double tamano;

  final bool conPlaca;

  @override
  Widget build(BuildContext context) {
    final sprite = MascotaVista(
      mascota: mascota,
      equipado: equipado,
      tamano: tamano,
    );
    if (!conPlaca) return sprite;

    // Aclarar el color de la mascota en vez de usarlo tal cual: el verde de
    // la rana a plena saturación se comía su propio sprite.
    final fondo = Color.lerp(mascota.color, Colors.white, 0.72)!;
    final borde = Color.lerp(mascota.color, Colors.black, 0.25)!;

    return Container(
      width: tamano * 1.34,
      height: tamano * 1.34,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(fondo, Colors.white, 0.35)!, fondo],
        ),
        borderRadius: BorderRadius.circular(tamano * 0.3),
        border: Border.all(color: borde, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: sprite,
    );
  }
}

/// Lo que la mascota tiene que decir, en una tarjeta baja y estrecha.
///
/// Aparece sola cuando el consejo CAMBIA (llegaste a un humedal, cayó la
/// noche, sumaste una especie más), no cada pocos segundos, y se puede cerrar.
/// Tocarla abre el Refugio.
class ConsejoMascota extends StatelessWidget {
  const ConsejoMascota({
    super.key,
    required this.mascota,
    required this.mensaje,
    required this.onCerrar,
    required this.onAbrirRefugio,
    this.equipado = const {},
  });

  final Mascota mascota;
  final String mensaje;
  final VoidCallback onCerrar;
  final VoidCallback onAbrirRefugio;
  final Map<RanuraAccesorio, Accesorio> equipado;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VeridiaRadii.lg),
        onTap: onAbrirRefugio,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          decoration: BoxDecoration(
            color: VeridiaColors.surfaceContainer,
            borderRadius: BorderRadius.circular(VeridiaRadii.lg),
            border: Border.all(color: mascota.color.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MascotaVista(mascota: mascota, equipado: equipado, tamano: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mascota.mejora,
                      style: TextStyle(
                        fontFamily: VeridiaFonts.body,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: mascota.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mensaje,
                      style: const TextStyle(
                        fontFamily: VeridiaFonts.body,
                        fontSize: 12,
                        height: 1.3,
                        color: VeridiaColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCerrar,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(
                  Icons.close_rounded,
                  color: VeridiaColors.onSurfaceVariant,
                ),
                tooltip: 'Ocultar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
