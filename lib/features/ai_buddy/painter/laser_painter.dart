import 'dart:math' as math;
import 'dart:ui' as ui;

import '../models/character_pose.dart';

import 'package:flutter/material.dart';

import 'edutainer_context.dart';
import 'paint_utils.dart';
import 'saucer_painter.dart';

/// Draws animated laser beams and impact labels for pose targets.
class LaserPainter {
  LaserPainter(this.ctx);
  final EdutainerContext ctx;
  EdutainerPose get pose => ctx.pose;
  Color get _color => ctx.laserColor;
  late final _saucer = SaucerPainter(ctx);

  void paint(Canvas canvas) {
    if (pose.laser <= 0 || pose.targets.isEmpty) return;
    final src = ctx.groupPoint(_saucer.laserOrigin);
    for (var i = 0; i < pose.targets.length; i++) {
      final dst = pose.targets[i];
      final flick = 0.8 + 0.2 * math.sin(pose.time * 22 + i * 1.7);
      final k = pose.laser * flick;
      final dir = dst - src;
      final len = dir.distance;
      if (len < 1) continue;

      _beam(canvas, src, dst, dir, len, k);
      _impact(canvas, dst, k, i);
      if (i < pose.labels.length && pose.labels[i].isNotEmpty) {
        _label(canvas, pose.labels[i], dst, dir, len);
      }
    }
  }

  void _beam(
    Canvas canvas,
    Offset src,
    Offset dst,
    Offset dir,
    double len,
    double k,
  ) {
    final n = Offset(-dir.dy, dir.dx) / len;
    Path beam(double w0, double w1) => Path()
      ..moveTo(src.dx + n.dx * w0, src.dy + n.dy * w0)
      ..lineTo(dst.dx + n.dx * w1, dst.dy + n.dy * w1)
      ..lineTo(dst.dx - n.dx * w1, dst.dy - n.dy * w1)
      ..lineTo(src.dx - n.dx * w0, src.dy - n.dy * w0)
      ..close();

    // glow
    canvas.drawPath(
      beam(9, 5),
      Paint()
        ..color = fade(_color, 0.45 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // core
    canvas.drawPath(
      beam(2.4, 1.2),
      Paint()
        ..shader = ui.Gradient.linear(src, dst, [
          fade(Colors.white, k),
          fade(_color, 0.9 * k),
        ]),
    );
    // travelling dots
    for (var j = 0; j < 3; j++) {
      final u = (pose.time * 1.4 + j / 3) % 1.0;
      canvas.drawCircle(
        Offset.lerp(src, dst, u)!,
        3.2 * (1 - u * 0.4),
        Paint()..color = fade(Colors.white, 0.9 * k),
      );
    }
  }

  void _impact(Canvas canvas, Offset p, double k, int i) {
    final t = pose.time;
    canvas.drawCircle(
      p,
      20,
      Paint()
        ..color = fade(_color, 0.5 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final ring = (t * 1.2 + i * 0.31) % 1.0;
    canvas.drawCircle(
      p,
      8 + ring * 24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = fade(_color, (1 - ring) * 0.8 * k),
    );
    final r = 13 + 3 * math.sin(t * 9 + i);
    final star = Path();
    for (var j = 0; j < 8; j++) {
      final rad = j.isEven ? r : r * 0.28;
      final a = t * 2 + j * math.pi / 4;
      final pt = p + Offset(math.cos(a), math.sin(a)) * rad;
      if (j == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = fade(Colors.white, 0.95 * k));
  }

  void _label(Canvas canvas, String text, Offset dst, Offset dir, double len) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF0B1F3A),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final c = dst + dir / len * 30;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: tp.width + 14, height: tp.height + 8),
      const Radius.circular(10),
    );
    canvas.drawRRect(r, Paint()..color = fade(Colors.white, 0.92 * pose.laser));
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }
}
