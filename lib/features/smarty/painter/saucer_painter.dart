import 'dart:math' as math;

import '../models/smarty_pose.dart';

import 'package:flutter/material.dart';

import 'smarty_context.dart';
import 'paint_utils.dart';

/// Draws the saucer, antenna, and orb used as the character's laser origin.
class SaucerPainter {
  /// Creates the painter with shared pose and palette data.
  SaucerPainter(this.ctx);
  final SmartyContext ctx;
  SmartyPose get pose => ctx.pose;

  /// Returns the orb position after applying its animation around the antenna.
  Offset get laserOrigin {
    const center = Offset(200, 165);
    final angle = math.sin(pose.time * 3) * 0.04;
    final relative = SmartyContext.orb - center;
    return center +
        Offset(
          relative.dx * math.cos(angle) - relative.dy * math.sin(angle),
          relative.dx * math.sin(angle) + relative.dy * math.cos(angle),
        );
  }

  void paint(Canvas canvas) {
    final t = pose.time;
    final sp = ctx.saucer;
    final amber = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: sp.stem,
    );

    _stem(canvas, amber);

    canvas.save();
    canvas.translate(200, 165);
    canvas.rotate(math.sin(t * 3) * 0.04);
    canvas.translate(-200, -165);

    _disc(canvas, t);

    final orbit = Rect.fromCenter(
      center: const Offset(200, 122),
      width: 164,
      height: 46,
    );
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = sp.orbitArc;
    void orbitArcs() {
      canvas.drawArc(orbit, t * 5, 0.9, false, orbitPaint);
      canvas.drawArc(orbit, t * 5 + math.pi, 0.9, false, orbitPaint);
    }

    // back half of the orbit
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 400, 122));
    orbitArcs();
    canvas.restore();

    _neck(canvas, amber);
    _orb(canvas, t);

    // front half of the orbit
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 122, 400, 600));
    orbitArcs();
    canvas.restore();

    canvas.restore();

    drawBurst(
      canvas,
      laserOrigin,
      -math.pi / 4,
      0.38,
      pose.laser * (0.5 + 0.5 * math.sin(t * 10)),
      n: 3,
      inner: 38,
      outer: 58,
    );
  }

  void _stem(Canvas canvas, LinearGradient amber) {
    final stem = Path()
      ..moveTo(185, 176)
      ..lineTo(189, 130)
      ..lineTo(211, 130)
      ..lineTo(215, 176)
      ..close();
    canvas.drawPath(
      stem,
      Paint()
        ..shader = amber.createShader(const Rect.fromLTWH(185, 130, 30, 46)),
    );
  }

  void _disc(Canvas canvas, double t) {
    final sp = ctx.saucer;
    final disc = Rect.fromCenter(
      center: const Offset(200, 122),
      width: 132,
      height: 34,
    );
    canvas.drawOval(
      disc.shift(const Offset(0, 7)),
      Paint()..color = sp.discEdge,
    );
    canvas.drawOval(
      disc,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sp.discTop, sp.discMid, sp.discBottom],
        ).createShader(disc),
    );
    final ring = Rect.fromCenter(
      center: const Offset(200, 121),
      width: 108,
      height: 20,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = sp.ringGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawArc(
      ring,
      t * 4,
      1.0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  void _neck(Canvas canvas, LinearGradient amber) {
    canvas.drawRRect(
      RRect.fromLTRBR(192, 104, 208, 124, const Radius.circular(4)),
      Paint()
        ..shader = amber.createShader(const Rect.fromLTWH(192, 104, 16, 20)),
    );
  }

  void _orb(Canvas canvas, double t) {
    final sp = ctx.saucer;
    const orb = SmartyContext.orb;
    final glow = 0.45 + 0.35 * pose.laser * (0.5 + 0.5 * math.sin(t * 10));
    canvas.drawCircle(
      orb,
      40,
      Paint()
        ..color = fade(sp.orbGlow, glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    final orbRect = Rect.fromCircle(center: orb, radius: 24);
    canvas.drawCircle(
      orb,
      24,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [sp.orbLight, sp.orbMid, sp.orbDark],
          stops: const [0, 0.55, 1],
        ).createShader(orbRect),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(191, 82), width: 14, height: 8),
      Paint()..color = const Color(0xCCFFFFFF),
    );
    canvas.drawCircle(
      const Offset(207, 99),
      2.5,
      Paint()..color = const Color(0x99FFFFFF),
    );
  }
}
