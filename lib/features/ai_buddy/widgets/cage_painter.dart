import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws a neon laser cage rendered in two passes: back edges + depth
/// connectors, then front face bars with an electric flicker effect.
class LaserCagePainter extends CustomPainter {
  LaserCagePainter({
    required this.color,
    required this.time,
    required this.front,
    required this.barCount,
    this.widthFactor = 0.94,
    this.heightFactor = 0.72,
    this.centerYFactor = 0.50,
    this.depth = 0.85,
  });

  final Color color;
  final double time;
  final bool front;
  final int barCount;
  final double widthFactor;
  final double heightFactor;
  final double centerYFactor;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Front face
    final frontRect = Rect.fromCenter(
      center: Offset(w / 2, h * centerYFactor),
      width: w * widthFactor,
      height: h * heightFactor,
    );

    // Back face
    final backRect = Rect.fromCenter(
      center: frontRect.center.translate(0, -h * 0.02),
      width: frontRect.width * depth,
      height: frontRect.height * depth,
    );

    final lines = <_Line>[];

    if (front) {
      // Front frame
      lines.addAll([
        _Line(frontRect.topLeft, frontRect.topRight),
        _Line(frontRect.topRight, frontRect.bottomRight),
        _Line(frontRect.bottomRight, frontRect.bottomLeft),
        _Line(frontRect.bottomLeft, frontRect.topLeft),
      ]);
      // Vertical bars
      for (var i = 1; i <= barCount; i++) {
        final x = frontRect.left + frontRect.width * i / (barCount + 1);
        lines.add(_Line(Offset(x, frontRect.top), Offset(x, frontRect.bottom)));
      }
    } else {
      // Back frame
      lines.addAll([
        _Line(backRect.topLeft, backRect.topRight),
        _Line(backRect.topRight, backRect.bottomRight),
        _Line(backRect.bottomRight, backRect.bottomLeft),
        _Line(backRect.bottomLeft, backRect.topLeft),
        // Perspective edges connecting front and back
        _Line(frontRect.topLeft, backRect.topLeft),
        _Line(frontRect.topRight, backRect.topRight),
        _Line(frontRect.bottomLeft, backRect.bottomLeft),
        _Line(frontRect.bottomRight, backRect.bottomRight),
      ]);
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;

    final coreColor = Color.lerp(color, Colors.white, 0.65)!;

    for (var i = 0; i < lines.length; i++) {
      // Subtle electric flicker per line
      final flicker = 0.85 + 0.15 * math.sin(time * 7 + i * 1.7);
      glow.color = color.withValues(alpha: 0.65 * flicker);
      core.color = coreColor.withValues(alpha: flicker);
      canvas.drawLine(lines[i].a, lines[i].b, glow);
      canvas.drawLine(lines[i].a, lines[i].b, core);
    }
  }

  @override
  bool shouldRepaint(covariant LaserCagePainter old) =>
      old.time != time ||
      old.color != color ||
      old.front != front ||
      old.barCount != barCount ||
      old.widthFactor != widthFactor ||
      old.heightFactor != heightFactor ||
      old.centerYFactor != centerYFactor ||
      old.depth != depth;
}

class _Line {
  const _Line(this.a, this.b);
  final Offset a;
  final Offset b;
}
