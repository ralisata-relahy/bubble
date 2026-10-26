import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Single droplet particle generated when a bubble pops.
class PopParticle {
  PopParticle({
    required this.start,
    required this.dir,
    required this.speed,
    required this.radius,
    required this.delay,
    required this.life,
    required this.drag,
    required this.color,
    required this.big,
  });

  final Offset start;
  final Offset dir;
  final double speed;
  final double radius;
  final double delay;
  final double life;
  final double drag;
  final Color color;
  final bool big;
}

/// Handles the burst animation, retracting film, and liquid droplet particles for a popping bubble.
class BubblePopRenderer {
  BubblePopRenderer();

  static const double popDuration = 0.3;
  static const double holeDuration = 0.1;
  static const double holeFrac = holeDuration / popDuration;
  static const MaskFilter _bigDropBlur = MaskFilter.blur(BlurStyle.normal, 1.0);

  final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _haloPaint = Paint()
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  final Paint _dropPaint = Paint();

  /// Generates a randomized cluster of pop droplets spraying outwards from [popOrigin].
  List<PopParticle> createParticles({
    required Size bubbleSize,
    required Offset popOrigin,
    required double popMaxHole,
    required Color dropColor,
    required math.Random random,
  }) {
    final rx = bubbleSize.width / 2;
    final ry = bubbleSize.height / 2;
    final center = Offset(rx, ry);
    final particles = <PopParticle>[];

    final count = 22 + random.nextInt(7);
    for (var i = 0; i < count; i++) {
      final a = random.nextDouble() * 2 * math.pi;
      final start = center + Offset(math.cos(a) * rx, math.sin(a) * ry);
      final dist = (start - popOrigin).distance;
      final big = random.nextDouble() < 0.14;

      final out = Offset(math.cos(a), math.sin(a));
      final jitter = (random.nextDouble() - 0.5) * 0.9;
      final dir = Offset(
        out.dx * math.cos(jitter) - out.dy * math.sin(jitter),
        out.dx * math.sin(jitter) + out.dy * math.cos(jitter),
      );

      particles.add(
        PopParticle(
          start: start,
          dir: dir,
          speed: big
              ? 0.25 + random.nextDouble() * 0.35
              : 0.5 + random.nextDouble() * 1.1,
          radius: big
              ? 0.022 + random.nextDouble() * 0.018
              : 0.008 + random.nextDouble() * 0.010,
          delay: (dist / popMaxHole).clamp(0.0, 1.0) * holeDuration,
          life: big
              ? 0.45 + random.nextDouble() * 0.15
              : 0.22 + random.nextDouble() * 0.25,
          drag: big ? 2.5 : 4.0 + random.nextDouble() * 2.0,
          color: random.nextDouble() < 0.55 ? Colors.white : dropColor,
          big: big,
        ),
      );
    }
    return particles;
  }

  /// Calculates the current radius of the expanding puncture hole.
  double calculateHoleRadius({
    required double popProgress,
    required double maxHole,
  }) {
    return maxHole * (popProgress / holeFrac).clamp(0.0, 1.0);
  }

  /// Renders the popping effect: retracting rim film and flying liquid droplets.
  void renderPop({
    required Canvas canvas,
    required Size bubbleSize,
    required double popProgress,
    required Offset popOrigin,
    required double holeRadius,
    required Path ovalPath,
    required Color baseColor,
    required bool isRed,
    required List<PopParticle> particles,
    required void Function(Canvas canvas, {required bool hole}) paintBody,
  }) {
    final p = popProgress.clamp(0.0, 1.0);
    final shortSide = math.min(bubbleSize.width, bubbleSize.height);
    final tHole = (p / holeFrac).clamp(0.0, 1.0);

    // 1. Punctured bubble film with illuminated rim
    if (tHole < 1.0) {
      paintBody(canvas, hole: true);

      if (holeRadius > 0) {
        final a = 1 - tHole * tHole;
        canvas.save();
        canvas.clipPath(ovalPath);
        _rimPaint
          ..strokeWidth = shortSide * 0.03 * (1 - 0.5 * tHole)
          ..color = Colors.white.withValues(alpha: 0.6 * a);
        canvas.drawCircle(popOrigin, holeRadius, _rimPaint);
        _haloPaint
          ..strokeWidth = shortSide * 0.02
          ..color = (isRed ? const Color(0xFFFF1E1E) : baseColor).withValues(
            alpha: 0.35 * a,
          );
        canvas.drawCircle(popOrigin, holeRadius + shortSide * 0.02, _haloPaint);
        canvas.restore();
      }
    }

    // 2. Projected droplets with parabolic gravity trajectory
    final tNow = p * popDuration;
    final g = 1.4 * shortSide;
    for (final d in particles) {
      final tau = tNow - d.delay;
      if (tau < 0 || tau > d.life) continue;

      final k = tau / d.life;
      final fade = (1 - k) * math.sqrt(1 - k);
      final disp = d.speed * shortSide * (1 - math.exp(-d.drag * tau)) / d.drag;
      final pos = d.start + d.dir * disp + Offset(0, 0.5 * g * tau * tau);
      final r = shortSide * d.radius * (1 - 0.5 * k);
      if (r <= 0) continue;

      _dropPaint
        ..maskFilter = d.big ? _bigDropBlur : null
        ..color = d.color.withValues(alpha: (d.big ? 0.55 : 0.45) * fade);
      canvas.drawCircle(pos, r, _dropPaint);

      if (d.big) {
        _dropPaint
          ..maskFilter = null
          ..color = Colors.white.withValues(alpha: 0.8 * fade);
        canvas.drawCircle(
          pos + Offset(-r * 0.3, -r * 0.3),
          r * 0.3,
          _dropPaint,
        );
      }
    }
  }
}
