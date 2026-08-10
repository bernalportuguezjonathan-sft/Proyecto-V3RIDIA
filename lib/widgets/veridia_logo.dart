import 'package:flutter/material.dart';
import '../theme/veridia_theme.dart';

/// Logo completo (colibrí + palabra VERIDIA).
class VeridiaLogo extends StatelessWidget {
  const VeridiaLogo({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/veridia_logo_completo.png',
      width: size,
      height: size,
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
