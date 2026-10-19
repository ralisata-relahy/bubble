import 'package:flutter/material.dart';

import 'edutainer_context.dart';

// The big round body with its lighting.
class BodyPainter {
  BodyPainter(this.ctx);
  final EdutainerContext ctx;

  static final Path _bodyPath = Path()
    ..moveTo(200, 165)
    ..cubicTo(270, 165, 318, 250, 318, 330)
    ..cubicTo(318, 400, 265, 436, 200, 436)
    ..cubicTo(135, 436, 82, 400, 82, 330)
    ..cubicTo(82, 250, 130, 165, 200, 165)
    ..close();

  void paint(Canvas canvas) {
    final b = _bodyPath.getBounds();
    canvas.drawPath(
        _bodyPath, Paint()..shader = ctx.bodyGradient.createShader(b));

    canvas.save();
    canvas.clipPath(_bodyPath);
    _bounceLight(canvas);
    _rimLight(canvas);
    _highlights(canvas);
    canvas.restore();
  }

  void _bounceLight(Canvas canvas) {
    final bl = Rect.fromCenter(
      center: const Offset(200, 442),
      width: 260,
      height: 80,
    );
    canvas.drawOval(
      bl,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x77FF9AA0), Color(0x00FF9AA0)],
        ).createShader(bl),
    );
  }

  void _rimLight(Canvas canvas) {
    canvas.drawPath(
      _bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0x33FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _highlights(Canvas canvas) {
    canvas.save();
    canvas.translate(124, 238);
    canvas.rotate(-0.9);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 78, height: 15),
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
    canvas.drawCircle(
      const Offset(112, 276),
      5,
      Paint()..color = const Color(0x77FFFFFF),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(228, 186), width: 50, height: 10),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }
}
