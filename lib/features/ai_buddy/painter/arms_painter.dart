import 'dart:math' as math;

import '../models/character_pose.dart';
import 'package:flutter/material.dart';

import 'edutainer_context.dart';
import 'paint_utils.dart';

// Raised arm and lowered arm.
class ArmsPainter {
  ArmsPainter(this.ctx);
  final EdutainerContext ctx;
  EdutainerPose get pose => ctx.pose;

  void paint(Canvas canvas) {
    // raised arm
    var a = deg(-150) + pose.waveArm * 0.3;
    final tipUp = _arm(canvas, const Offset(100, 318), a, 92, 15, 27);
    drawBurst(
      canvas,
      tipUp,
      a - 0.4,
      0.55,
      pose.waveArm.abs(),
      n: 3,
      inner: 36,
      outer: 54,
    );
    // lowered arm
    a = deg(24) + pose.downArm * 0.25;
    _arm(canvas, const Offset(298, 335), a, 68, 17, 32);
  }

  // Draws a tapered balloon
  Offset _arm(
    Canvas canvas,
    Offset c1,
    double ang,
    double len,
    double r1,
    double r2,
  ) {
    final c2 = c1 + Offset(math.cos(ang), math.sin(ang)) * len;
    final phi = math.acos((r1 - r2) / len);
    Offset pt(Offset c, double r, double a) =>
        c + Offset(math.cos(a), math.sin(a)) * r;
    final p1a = pt(c1, r1, ang + phi), p2a = pt(c2, r2, ang + phi);
    final p1b = pt(c1, r1, ang - phi);
    final path = Path()
      ..moveTo(p1a.dx, p1a.dy)
      ..lineTo(p2a.dx, p2a.dy)
      ..arcTo(Rect.fromCircle(center: c2, radius: r2), ang + phi, -2 * phi,
          false)
      ..lineTo(p1b.dx, p1b.dy)
      ..arcTo(Rect.fromCircle(center: c1, radius: r1), ang - phi,
          -(2 * math.pi - 2 * phi), false)
      ..close();
    canvas.drawPath(
      path,
      Paint()..shader = ctx.bodyGradient.createShader(path.getBounds()),
    );
    // shoulder seam
    canvas.drawArc(
      Rect.fromCircle(center: c1, radius: r1 + 1),
      ang + math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x44A30D16),
    );
    // gloss on the hand
    canvas.save();
    canvas.translate(c2.dx - r2 * 0.3, c2.dy - r2 * 0.45);
    canvas.rotate(-0.7);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r2 * 0.9, height: r2 * 0.32),
      Paint()..color = const Color(0x88FFFFFF),
    );
    canvas.restore();
    return c2;
  }
}
