import 'dart:math' as math;

import '../models/character_pose.dart';
import 'package:flutter/material.dart';

import 'edutainer_context.dart';
import 'paint_utils.dart';

/// Draws the ground shadow and animated feet beneath the character.
class GroundPainter {
  GroundPainter(this.ctx);
  final EdutainerContext ctx;
  EdutainerPose get pose => ctx.pose;

  void paintShadow(Canvas canvas) {
    final r = Rect.fromCenter(
      center: const Offset(200, 486),
      width: 250 - pose.bob * 30,
      height: 30,
    );
    canvas.drawOval(
      r,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void paintFoot(Canvas canvas, double cx, double lift, double side) {
    final cy = 452 - lift * 28;
    canvas.save();
    canvas.translate(cx + side * lift * 10, cy);
    canvas.rotate(side * lift * 0.28);
    final rect = Rect.fromCenter(center: Offset.zero, width: 86, height: 66);
    final oval = Path()..addOval(rect);
    canvas.drawPath(
        oval, Paint()..shader = ctx.bodyGradient.createShader(rect));

    // sole
    canvas.save();
    canvas.clipPath(oval);
    final seam = Path()
      ..moveTo(-45, 6)
      ..quadraticBezierTo(0, 24, 45, 6);
    final sole = Path.from(seam)
      ..lineTo(45, 40)
      ..lineTo(-45, 40)
      ..close();
    canvas.drawPath(
      sole,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFC9DDF2)],
        ).createShader(rect),
    );
    canvas.drawPath(
      seam,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0x55A30D16),
    );
    canvas.restore();

    // gloss
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-14, -16), width: 26, height: 10),
      Paint()..color = const Color(0x77FFFFFF),
    );
    canvas.restore();

    // motion ticks next to a lifted foot
    drawBurst(
      canvas,
      Offset(cx + side * (50 + lift * 10), cy - 4),
      side < 0 ? math.pi : 0,
      0.5,
      lift * 0.9,
      n: 2,
      inner: 6,
      outer: 20,
    );
  }
}
