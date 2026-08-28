import 'package:flutter/material.dart';

/// Un dibujo en píxeles: una rejilla de caracteres más la paleta que dice de
/// qué color es cada carácter.
///
/// El arte va en CÓDIGO y no en PNG a propósito:
/// - No mete binarios en git ni obliga a mantener @2x/@3x.
/// - Escala perfecto a cualquier densidad de pantalla, porque se pinta con
///   rectángulos y no se interpola nunca (que es lo que vuelve borroso el
///   pixel art cuando se carga como imagen en Flutter).
/// - Los accesorios son otra capa encima, así que un sombrero sirve para las
///   cinco mascotas sin redibujarlo cinco veces.
/// - Sigue la misma convención que el resto del proyecto: los catálogos —de
///   recompensas, de mascotas— viven en el código, no en Firestore.
///
/// El carácter `.` siempre es transparente.
class PixelArt {
  const PixelArt({required this.filas, required this.paleta});

  /// Filas de la rejilla, todas del mismo largo. `.` = transparente.
  final List<String> filas;

  final Map<String, Color> paleta;

  int get alto => filas.length;

  int get ancho => filas.isEmpty ? 0 : filas.first.length;

  /// Copia con otra paleta, para recolorear un accesorio sin redibujarlo.
  PixelArt conPaleta(Map<String, Color> otra) =>
      PixelArt(filas: filas, paleta: otra);

  /// Copia movida `dx` columnas y `dy` filas dentro de la misma rejilla.
  ///
  /// Es lo que permite que UN sombrero sirva para las cinco mascotas: cada
  /// una declara dónde tiene la cabeza (el colibrí la tiene a la izquierda,
  /// la catarina más arriba) y el accesorio se desplaza hasta ahí en vez de
  /// dibujarse cinco veces. Lo que se sale de la rejilla se recorta.
  PixelArt desplazado({int dx = 0, int dy = 0}) {
    if (dx == 0 && dy == 0) return this;
    final vacia = '.' * ancho;
    final movidas = <String>[];
    for (var fila = 0; fila < alto; fila++) {
      final origen = fila - dy;
      if (origen < 0 || origen >= alto) {
        movidas.add(vacia);
        continue;
      }
      final texto = filas[origen];
      final buffer = StringBuffer();
      for (var col = 0; col < ancho; col++) {
        final desde = col - dx;
        buffer.write(desde < 0 || desde >= texto.length ? '.' : texto[desde]);
      }
      movidas.add(buffer.toString());
    }
    return PixelArt(filas: movidas, paleta: paleta);
  }
}

/// Pinta una o varias [PixelArt] superpuestas dentro del espacio disponible.
class _PixelPainter extends CustomPainter {
  const _PixelPainter({required this.capas, required this.opacidad});

  final List<PixelArt> capas;
  final double opacidad;

  @override
  void paint(Canvas canvas, Size size) {
    if (capas.isEmpty) return;

    final rejilla = capas.first;
    if (rejilla.ancho == 0 || rejilla.alto == 0) return;

    final escalaX = size.width / rejilla.ancho;
    final escalaY = size.height / rejilla.alto;
    final pincel = Paint()..isAntiAlias = false;

    for (final capa in capas) {
      for (var fila = 0; fila < capa.filas.length; fila++) {
        final texto = capa.filas[fila];
        for (var col = 0; col < texto.length; col++) {
          final color = capa.paleta[texto[col]];
          if (color == null) continue;
          pincel.color = opacidad >= 1
              ? color
              : color.withValues(alpha: color.a * opacidad);
          // El +0.6 solapa un pelo cada rectángulo con el siguiente: sin él,
          // cuando la escala no es entera quedan líneas de fondo entre píxel
          // y píxel y el sprite se ve rayado.
          canvas.drawRect(
            Rect.fromLTWH(
              col * escalaX,
              fila * escalaY,
              escalaX + 0.6,
              escalaY + 0.6,
            ),
            pincel,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter viejo) =>
      viejo.capas != capas || viejo.opacidad != opacidad;
}

/// Dibuja un sprite quieto.
class PixelSprite extends StatelessWidget {
  const PixelSprite({
    super.key,
    required this.capas,
    required this.tamano,
    this.opacidad = 1,
  });

  /// Capas de abajo hacia arriba: primero la mascota, luego los accesorios.
  final List<PixelArt> capas;

  /// Lado del cuadrado en píxeles lógicos. Un sprite de 16x16 se ve nítido a
  /// 48 (mapa) y a 96 (Refugio): múltiplos exactos de la rejilla.
  final double tamano;

  final double opacidad;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(
        painter: _PixelPainter(capas: capas, opacidad: opacidad),
        isComplex: false,
      ),
    );
  }
}

/// El mismo sprite, pero vivo: respira y parpadea.
///
/// La animación NO son fotogramas dibujados a mano. El rebote es un
/// desplazamiento de un píxel de la rejilla y el parpadeo es una capa extra
/// que tapa los ojos, así que cada mascota se dibuja una sola vez y aun así
/// se mueve. Con cinco mascotas eso es la diferencia entre 5 dibujos y 15.
class PixelSpriteAnimado extends StatefulWidget {
  const PixelSpriteAnimado({
    super.key,
    required this.capas,
    required this.tamano,
    this.parpadeo,
    this.animar = true,
    this.opacidad = 1,
  });

  final List<PixelArt> capas;
  final double tamano;

  /// Capa que se pinta encima durante el parpadeo (los ojos cerrados).
  final PixelArt? parpadeo;

  final bool animar;
  final double opacidad;

  @override
  State<PixelSpriteAnimado> createState() => _PixelSpriteAnimadoState();
}

class _PixelSpriteAnimadoState extends State<PixelSpriteAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  /// Ocho pasos de 300 ms. El sprite sube un píxel en los pasos 2 y 3 (el
  /// "respiro") y cierra los ojos en el 6.
  static const _pasos = 8;
  static const _pasosArriba = {2, 3};
  static const _pasoParpadeo = 6;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300 * _pasos),
    );
    if (widget.animar) _controlador.repeat();
  }

  @override
  void didUpdateWidget(PixelSpriteAnimado viejo) {
    super.didUpdateWidget(viejo);
    if (widget.animar && !_controlador.isAnimating) {
      _controlador.repeat();
    } else if (!widget.animar && _controlador.isAnimating) {
      _controlador.stop();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alto = widget.capas.isEmpty ? 16 : widget.capas.first.alto;
    final unPixel = widget.tamano / alto;

    return SizedBox(
      width: widget.tamano,
      height: widget.tamano,
      child: AnimatedBuilder(
        animation: _controlador,
        builder: (context, _) {
          final paso = (_controlador.value * _pasos).floor() % _pasos;
          final capas = [
            ...widget.capas,
            if (widget.parpadeo != null && paso == _pasoParpadeo)
              widget.parpadeo!,
          ];
          return Transform.translate(
            offset: Offset(0, _pasosArriba.contains(paso) ? -unPixel : 0),
            child: PixelSprite(
              capas: capas,
              tamano: widget.tamano,
              opacidad: widget.opacidad,
            ),
          );
        },
      ),
    );
  }
}
