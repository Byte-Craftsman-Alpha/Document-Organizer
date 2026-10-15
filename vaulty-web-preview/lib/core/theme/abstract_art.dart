import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_extensions.dart';
/// Decorative vector art uses the same tonal palette in either brightness.
class AbstractArt extends StatelessWidget {
  const AbstractArt({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _Art(
          context.tokens.mint,
          context.colors.primaryContainer,
          context.colors.primary,
          context.tokens.warning,
          context.colors.secondary,
        ),
        size: Size.infinite,
      ),
    ),
  );
}
class _Art extends CustomPainter {
  _Art(this.mint, this.container, this.coral, this.sand, this.accent);
  final Color mint, container, coral, sand, accent;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final p = Paint()..isAntiAlias = true;

    // Pixel squircle pebble base
    p.color = mint.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 8, 54, 54),
        const Radius.circular(22),
      ),
      p,
    );

    // Complementary circle pill
    p.color = container.withValues(alpha: 0.9);
    canvas.drawCircle(const Offset(66, 32), 26, p);

    // Pixel accent small pill
    p.color = accent.withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 58, 28, 14),
        const Radius.circular(7),
      ),
      p,
    );

    // Floating document tile with tilt
    canvas.save();
    canvas.translate(54, 62);
    canvas.rotate(-math.pi / 12);
    p.color = coral;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -20, 52, 42),
        const Radius.circular(14),
      ),
      p,
    );

    // Stylized document lines
    p.color = container;
    p.strokeWidth = 3.5;
    p.strokeCap = StrokeCap.round;
    p.style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-14, -6), const Offset(14, -6), p);
    canvas.drawLine(const Offset(-14, 4), const Offset(4, 4), p);
    p.style = PaintingStyle.fill;
    canvas.restore();

    // Warm sand pebble dot
    p.color = sand;
    canvas.drawCircle(const Offset(82, 78), 11, p);

    // Tiny orbital spark
    p.color = mint;
    canvas.drawCircle(const Offset(34, 20), 4, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_Art old) =>
      mint != old.mint ||
      container != old.container ||
      coral != old.coral ||
      sand != old.sand ||
      accent != old.accent;
}
