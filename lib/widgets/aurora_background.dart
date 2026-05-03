import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.voidBlack,
            Color(0xFF15102A),
            Color(0xFF0D1B2A),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _OrbPainter(),
        child: child,
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.violetGlow.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.12), radius: size.shortestSide * 0.55));
    canvas.drawRect(rect, glow);

    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.cyanAccent.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.1, size.height * 0.75), radius: size.shortestSide * 0.5));
    canvas.drawRect(rect, glow2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
