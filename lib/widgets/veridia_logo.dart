import 'package:flutter/material.dart';
import '../theme/veridia_theme.dart';

/// Logo completo (colibrí + palabra VERIDIA).
///
/// [size] es el ALTO del dibujo; el ancho sale de su proporción real. El PNG
/// viene recortado al contenido y con fondo transparente, así que quien lo
/// envuelva (por ejemplo [VeridiaMarcoLogo]) queda ajustado al logo en vez de
/// a un lienzo cuadrado lleno de espacio vacío.
class VeridiaLogo extends StatelessWidget {
  const VeridiaLogo({super.key, this.size = 160});

  /// Proporción real del PNG (300 x 349).
  ///
  /// Está aquí como constante y no se deduce de la imagen a propósito. Con
  /// solo `height`, el ancho de un `Image` no existe hasta que la imagen
  /// DECODIFICA: en el primer pintado vale cero, y cualquier padre que se
  /// ajuste al logo —[VeridiaMarcoLogo] en la pantalla de bienvenida— se
  /// encoge a su propio relleno y se queda así hasta que algo fuerza otro
  /// layout. En la web eso deja el marco convertido en una cápsula vacía en
  /// la PRIMERA pantalla de la app, y solo se endereza al redimensionar.
  ///
  /// Declarando las dos medidas, el hueco está reservado desde el primer
  /// cuadro y la imagen entra dentro cuando llega. `BoxFit.contain` sigue
  /// puesto: si algún día el PNG se reexporta con otra proporción, se
  /// encajará dentro del hueco en vez de deformarse.
  static const _proporcion = 300 / 349;

  /// Alto del dibujo; el ancho sale de [_proporcion].
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/veridia_logo_completo.png',
      height: size,
      width: size * _proporcion,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Logo de Veridia',
    );
  }
}

/// Solo el símbolo (colibrí), recortado en círculo con halo verde neón.
class VeridiaSymbol extends StatelessWidget {
  const VeridiaSymbol({super.key, this.size = 96, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VeridiaColors.surfaceContainerLowest,
        border: Border.all(
          color: VeridiaColors.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: VeridiaColors.secondary.withValues(alpha: 0.22),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.02,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/veridia_simbolo.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Símbolo de Veridia',
        ),
      ),
    );
  }
}
