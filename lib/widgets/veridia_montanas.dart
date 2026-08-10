import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/veridia_theme.dart';

/// Paisaje de montañas y pinos dibujado a mano (vectorial: escala en cualquier
/// pantalla y se tiñe con la paleta, sin cargar imágenes).
///
/// Se usa como fondo de Bienvenida, Login y Registro.
class VeridiaMontanas extends StatelessWidget {
  const VeridiaMontanas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cielo: verde profundo con un resplandor cálido en el horizonte.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF061007), Color(0xFF0C2010), Color(0xFF13301A)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: const _PaisajePainter())),
        // Velo verde: baja el contraste del paisaje para que el texto mande.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xE6091609), Color(0xB30C1D0D), Color(0xF2050F06)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _PaisajePainter extends CustomPainter {
  const _PaisajePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Tres cordilleras, de la más lejana a la más cercana.
    _cordillera(
      canvas,
      size,
      baseY: h * 0.52,
      altura: h * 0.20,
      cumbres: 4,
      desfase: 0.0,
      color: const Color(0xFF16301B),
      nieve: true,
    );
    _cordillera(
      canvas,
      size,
      baseY: h * 0.60,
      altura: h * 0.17,
      cumbres: 5,
      desfase: 0.35,
      color: const Color(0xFF1C3D22),
      nieve: true,
    );
    _cordillera(
      canvas,
      size,
      baseY: h * 0.68,
      altura: h * 0.12,
      cumbres: 6,
      desfase: 0.7,
      color: const Color(0xFF224A29),
      nieve: false,
    );

    // Laderas boscosas en primer plano.
    final colinas = Paint()..color = const Color(0xFF1A3B20);
    final trazoColinas = Path()..moveTo(0, h);
    trazoColinas.lineTo(0, h * 0.78);
    trazoColinas.quadraticBezierTo(w * 0.22, h * 0.70, w * 0.45, h * 0.77);
    trazoColinas.quadraticBezierTo(w * 0.72, h * 0.85, w, h * 0.74);
    trazoColinas.lineTo(w, h);
    trazoColinas.close();
    canvas.drawPath(trazoColinas, colinas);

    _bosque(
      canvas,
      size,
      y: h * 0.80,
      escala: 0.72,
      color: const Color(0xFF122C17),
    );
    _bosque(
      canvas,
      size,
      y: h * 0.90,
      escala: 1.0,
      color: const Color(0xFF0C1F10),
    );
  }

  /// Dibuja una fila de cumbres triangulares con laderas suavizadas.
  void _cordillera(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double altura,
    required int cumbres,
    required double desfase,
    required Color color,
    required bool nieve,
  }) {
    final w = size.width;
    final ancho = w / cumbres;
    final trazo = Path()..moveTo(-ancho, baseY);

    final picos = <Offset>[];
    for (var i = 0; i <= cumbres; i++) {
      // Variación determinista: mismo relieve en cada repintado.
      final variacion = math.sin((i + desfase) * 2.3) * 0.22 + 1.0;
      final x = ancho * i - ancho * 0.5;
      final y = baseY - altura * variacion;
      picos.add(Offset(x, y));
      trazo.lineTo(x, y);
      trazo.lineTo(x + ancho * 0.5, baseY);
    }
    trazo.lineTo(w + ancho, baseY);
    trazo.lineTo(w + ancho, size.height);
    trazo.lineTo(-ancho, size.height);
    trazo.close();

    canvas.drawPath(trazo, Paint()..color = color);

    if (!nieve) return;

    // Casquetes: un triángulo pequeño colgando de cada cumbre.
    final blanco = Paint()..color = const Color(0x40D7E7D2);
    for (final pico in picos) {
      final capa = Path()
        ..moveTo(pico.dx, pico.dy)
        ..lineTo(pico.dx - altura * 0.16, pico.dy + altura * 0.26)
        ..lineTo(pico.dx - altura * 0.06, pico.dy + altura * 0.18)
        ..lineTo(pico.dx + altura * 0.05, pico.dy + altura * 0.28)
        ..lineTo(pico.dx + altura * 0.15, pico.dy + altura * 0.24)
        ..close();
      canvas.drawPath(capa, blanco);
    }
  }

  /// Franja de pinos de alturas alternadas.
  void _bosque(
    Canvas canvas,
    Size size, {
    required double y,
    required double escala,
    required Color color,
  }) {
    final pincel = Paint()..color = color;
    final alto = size.height * 0.09 * escala;
    final paso = size.width * 0.055;

    for (var i = -1; i * paso < size.width + paso; i++) {
      final x = i * paso;
      final variacion = 0.75 + (math.sin(i * 1.7) + 1) * 0.22;
      _pino(canvas, Offset(x, y), alto * variacion, pincel);
    }
  }

  void _pino(Canvas canvas, Offset base, double alto, Paint pincel) {
    final ancho = alto * 0.46;
    final trazo = Path()
      ..moveTo(base.dx, base.dy - alto)
      ..lineTo(base.dx - ancho * 0.42, base.dy - alto * 0.52)
      ..lineTo(base.dx - ancho * 0.22, base.dy - alto * 0.56)
      ..lineTo(base.dx - ancho * 0.60, base.dy)
      ..lineTo(base.dx + ancho * 0.60, base.dy)
      ..lineTo(base.dx + ancho * 0.22, base.dy - alto * 0.56)
      ..lineTo(base.dx + ancho * 0.42, base.dy - alto * 0.52)
      ..close();
    canvas.drawPath(trazo, pincel);
  }

  @override
  bool shouldRepaint(covariant _PaisajePainter oldDelegate) => false;
}

/// Marco redondeado con borde verde y halo, para encuadrar el logo.
class VeridiaMarcoLogo extends StatelessWidget {
  const VeridiaMarcoLogo({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: VeridiaColors.surfaceContainerLowest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: VeridiaColors.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: VeridiaColors.secondary.withValues(alpha: 0.18),
            blurRadius: 34,
            spreadRadius: -6,
          ),
        ],
      ),
      child: child,
    );
  }
}
