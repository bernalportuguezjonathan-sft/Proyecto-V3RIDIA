import 'package:flutter/material.dart';

import '../models/mascota.dart';
import '../theme/veridia_theme.dart';
import 'mascota_vista.dart';
import 'pixel_sprite.dart';

/// Un hábitat diminuto de 16 bits para poner DETRÁS de la mascota.
///
/// Los sprites siempre se dibujaron flotando sobre el fondo de la app, así que
/// una mascota se leía como un icono más entre otros. Con dos árboles, un
/// horizonte y algo de suelo detrás, pasa a leerse como una criatura que está
/// en algún sitio — que es lo que la vuelve suya y no un adorno.
///
/// La rejilla es de 16×16, la misma que usan los sprites de mascota
/// (`lib/models/mascota_sprites.dart`), para que cada píxel del hábitat caiga
/// exactamente sobre un píxel de la mascota y las dos capas queden alineadas a
/// cualquier tamaño. Los sprites de mascota NO se tocan: esto es una capa
/// nueva por debajo.
///
/// El `.` es transparente, igual que en el resto del pixel art del proyecto.
const _habitat = <String>[
  'cccccccccccccccc',
  'cccccccccccccccc',
  'ffccccccccccccff',
  'fFccccccccccccFf',
  'FFccccccccccccFF',
  'fFccccccccccccFf',
  '.t.cccccccccc.t.',
  '.t.dddddddddd.t.',
  '.t.dddddddddd.t.',
  'dddddddddddddddd',
  'dddddddddddddddd',
  'dddddddddddddddd',
  'gggggggggggggggg',
  'gsgggsggggsggggs',
  'ssssssssssssssss',
  'ssssssssssssssss',
];

/// La paleta del hábitat se TIÑE con el color de la mascota que lo habita.
///
/// Es lo que hace que el cuadrito de la rana sea un humedal verde y el del
/// currucutú un bosque nocturno más cálido, sin dibujar un hábitat distinto
/// para cada una. El tronco se queda en su marrón: es lo único que no cambia
/// de una especie a otra y sirve de ancla para que todas las variantes sigan
/// leyéndose como el mismo bosque.
Map<String, Color> _paleta(Color acento) => {
  'c': Color.lerp(const Color(0xFF04140F), acento, 0.06)!,
  'd': Color.lerp(const Color(0xFF0A2C22), acento, 0.18)!,
  'F': Color.lerp(const Color(0xFF052A1E), acento, 0.20)!,
  'f': Color.lerp(const Color(0xFF0B4632), acento, 0.35)!,
  't': const Color(0xFF2A1E12),
  'g': Color.lerp(const Color(0xFF0C3A26), acento, 0.25)!,
  's': const Color(0xFF071C14),
};

/// La mascota dentro de su hábitat, enmarcada.
///
/// [tamano] es el lado del cuadro, sin contar el marco. Conviene que sea
/// múltiplo de 16 (48, 64, 80, 96) para que la rejilla caiga en píxeles
/// enteros y no se vea rayada.
class MascotaVitrina extends StatelessWidget {
  const MascotaVitrina({
    super.key,
    required this.mascota,
    this.equipado = const {},
    this.tamano = 64,
    this.animar = true,
    this.onTap,
  });

  final Mascota mascota;
  final Map<RanuraAccesorio, Accesorio> equipado;
  final double tamano;
  final bool animar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(VeridiaRadii.sm);

    final cuadro = Container(
      decoration: BoxDecoration(
        borderRadius: radio,
        border: Border.all(
          color: mascota.color.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: mascota.color.withValues(alpha: 0.22),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      // El recorte va DENTRO del borde: sin él, las esquinas cuadradas del
      // hábitat asomarían por fuera del redondeo del marco.
      child: ClipRRect(
        borderRadius: radio,
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: Stack(
            children: [
              Positioned.fill(
                child: PixelSprite(
                  capas: [
                    PixelArt(filas: _habitat, paleta: _paleta(mascota.color)),
                  ],
                  tamano: tamano,
                ),
              ),
              // La mascota conserva su propio widget y, con él, su animación
              // de respiración y parpadeo: aquí solo se le pone algo detrás.
              Positioned.fill(
                child: MascotaVista(
                  mascota: mascota,
                  equipado: equipado,
                  tamano: tamano,
                  animar: animar,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return cuadro;
    return GestureDetector(onTap: onTap, child: cuadro);
  }
}
