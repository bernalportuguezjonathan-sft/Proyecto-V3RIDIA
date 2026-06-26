import 'package:flutter/material.dart';

class TokenIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const TokenIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700),
            const Color(0xFFFFA500),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'V',
          style: TextStyle(
            color: const Color(0xFF8B6914),
            fontWeight: FontWeight.bold,
            fontSize: size * 0.6,
          ),
        ),
      ),
    );
  }
}
