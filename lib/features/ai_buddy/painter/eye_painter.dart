import 'dart:math' as math;

import '../models/character_pose.dart';
import 'package:flutter/material.dart';

import 'edutainer_context.dart';

// The single eye
class EyePainter {
  EyePainter(this.ctx);
  final EdutainerContext ctx;
  EdutainerPose get pose => ctx.pose;

  static const double _rx = 64.0, _ry = 60.0;

  void paint(Canvas canvas) {
    const eyeC = EdutainerContext.eyeCenter;
    final open = math.max(1 - pose.blink, 0.04);
    final m = pose.mischief.clamp(0.0, 1.0);
    final hr = pose.heart.clamp(0.0, 1.0);
    final sd = pose.sadness.clamp(0.0, 1.0);

    // eye shadow
    canvas.drawOval(
      Rect.fromCenter(center: eyeC, width: _rx * 2 + 14, height: _ry * 2 + 14),
      Paint()
        ..color = const Color.fromARGB(102, 255, 255, 255)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.translate(eyeC.dx, eyeC.dy);
    canvas.scale(1, open);
    final er = Rect.fromCenter(
      center: Offset.zero,
      width: _rx * 2,
      height: _ry * 2,
    );

    _sclera(canvas, er);

    canvas.save();
    canvas.clipPath(Path()..addOval(er));

    var lk = pose.look;
    if (lk.distance > 1) lk = lk / lk.distance;
    final ic = Offset(lk.dx * 16, lk.dy * 8);

    if (hr > 0.01) {
      _heartIris(canvas, ic, hr);
    } else {
      _normalIris(canvas, ic, m, sd);
    }
    if (m > 0.01) _angryLid(canvas, er, m);
    if (sd > 0.01) _sadLid(canvas, er, sd);
    _upperLidShadow(canvas, er);

    canvas.restore();
    canvas.drawOval(
      er,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0x33000000),
    );
    canvas.restore();
  }

  void _sclera(Canvas canvas, Rect er) {
    canvas.drawOval(
      er,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [Colors.white, Color(0xFFF4F7FB), Color(0xFFC9D6E6)],
          stops: [0, 0.7, 1],
        ).createShader(er),
    );
  }

  void _normalIris(Canvas canvas, Offset ic, double m, double sd) {
    final ir = Rect.fromCircle(center: ic, radius: 38);
    canvas.drawCircle(
      ic,
      38,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF6CC8FF), Color(0xFF1E6FE0), Color(0xFF0B2E9A)],
          stops: [0, 0.6, 1],
        ).createShader(ir),
    );
    canvas.drawCircle(
      ic,
      38,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF08226F),
    );

    // pupil: contracts when angry, widens when sad
    canvas.drawCircle(
      ic,
      21 - 5 * m + 4 * sd,
      Paint()..color = const Color(0xFF05060F),
    );
    // highlights, bigger when sad (watery look)
    canvas.drawCircle(
      ic + const Offset(16, -16),
      10 + 3 * sd,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      ic + const Offset(25, 6),
      4.5 + 1.5 * sd,
      Paint()..color = Colors.white,
    );
  }

  void _heartIris(Canvas canvas, Offset ic, double hr) {
    final pulse = 1 + 0.08 * math.sin(pose.time * 6);
    final size = 80 * hr * pulse;
    final heart = _heartPath(ic, size);
    canvas.drawPath(
      heart,
      Paint()
        ..color = const Color(0x55FF2D6F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFF8FB1), Color(0xFFFF2D6F), Color(0xFFB0124A)],
          stops: [0, 0.55, 1],
        ).createShader(heart.getBounds()),
    );
    canvas.drawCircle(
      ic + Offset(-size * 0.28, -size * 0.12),
      size * 0.12,
      Paint()..color = Colors.white,
    );
  }

  Path _heartPath(Offset c, double s) {
    return Path()
      ..moveTo(c.dx, c.dy + s * 0.5)
      ..cubicTo(c.dx - s * 0.9, c.dy + s * 0.05, c.dx - s * 0.5,
          c.dy - s * 0.6, c.dx, c.dy - s * 0.2)
      ..cubicTo(c.dx + s * 0.5, c.dy - s * 0.6, c.dx + s * 0.9,
          c.dy + s * 0.05, c.dx, c.dy + s * 0.5)
      ..close();
  }

  /// V-shaped lid: low in the middle, high at the outer corners.
  void _angryLid(Canvas canvas, Rect er, double m) {
    final outerY = -_ry * (1 - 0.3 * m);
    final centerY = -_ry * (1 - 0.5 * m);
    const ext = _rx + 6;
    final lid = Path()
      ..moveTo(-ext, -_ry - 6)
      ..lineTo(ext, -_ry - 6)
      ..lineTo(ext, outerY)
      ..lineTo(0, centerY)
      ..lineTo(-ext, outerY)
      ..close();
    canvas.drawPath(lid, Paint()..shader = ctx.bodyGradient.createShader(er));
  }

  /// Inverted V: high in the middle, low at the outer corners.
  void _sadLid(Canvas canvas, Rect er, double sd) {
    final outerY = -_ry * (1 - 0.75 * sd);
    final centerY = -_ry * (1 - 0.2 * sd);
    const ext = _rx + 6;
    final lid = Path()
      ..moveTo(-ext, -_ry - 6)
      ..lineTo(ext, -_ry - 6)
      ..lineTo(ext, outerY)
      ..lineTo(0, centerY)
      ..lineTo(-ext, outerY)
      ..close();
    canvas.drawPath(lid, Paint()..shader = ctx.bodyGradient.createShader(er));
  }

  void _upperLidShadow(Canvas canvas, Rect er) {
    canvas.drawRect(
      er,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0x44000000), Color(0x00000000)],
        ).createShader(er),
    );
  }

  /// Cross-pulse on the forehead, only while angry.
  void paintAngerMark(Canvas canvas) {
    if (pose.mischief <= 0.01) return;
    final s = pose.mischief * (1 + 0.1 * math.sin(pose.time * 9));
    canvas.save();
    canvas.translate(262, 214);
    canvas.scale(s);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9E0A15);
    const r = 17.0;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(sx * r * 0.28, sy * r)
            ..quadraticBezierTo(
                sx * r * 0.28, sy * r * 0.28, sx * r, sy * r * 0.28),
          p,
        );
      }
    }
    canvas.restore();
  }
}