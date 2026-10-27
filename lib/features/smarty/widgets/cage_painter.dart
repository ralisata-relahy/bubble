// import 'dart:math' as math;
// import 'package:flutter/material.dart';

// // Draws a neon laser cage
// class LaserCagePainter extends CustomPainter {
//   LaserCagePainter({
//     required this.color,
//     required this.time,
//     required this.front,
//     required this.barCount,
//     this.widthFactor = 0.7,
//     this.heightFactor = 0.72,
//     this.centerYFactor = 0.50,
//     this.depth = 0.85,
//   });

//   final Color color;
//   final double time;
//   final bool front;
//   final int barCount;
//   final double widthFactor;
//   final double heightFactor;
//   final double centerYFactor;
//   final double depth;

//   @override
//   void paint(Canvas canvas, Size size) {
//     final w = size.width;
//     final h = size.height;

//     // Front face
//     final frontRect = Rect.fromCenter(
//       center: Offset(w / 2, h * centerYFactor),
//       width: w * widthFactor,
//       height: h * heightFactor,
//     );

//     // Back face
//     final backRect = Rect.fromCenter(
//       center: frontRect.center.translate(0, -h * 0.02),
//       width: frontRect.width * depth,
//       height: frontRect.height * depth,
//     );

//     final lines = <_Line>[];

//     if (front) {
//       // Front frame
//       lines.addAll([
//         _Line(frontRect.topLeft, frontRect.topRight),
//         _Line(frontRect.topRight, frontRect.bottomRight),
//         _Line(frontRect.bottomRight, frontRect.bottomLeft),
//         _Line(frontRect.bottomLeft, frontRect.topLeft),
//       ]);
//       // Vertical bars
//       for (var i = 1; i <= barCount; i++) {
//         final x = frontRect.left + frontRect.width * i / (barCount + 1);
//         lines.add(_Line(Offset(x, frontRect.top), Offset(x, frontRect.bottom)));
//       }
//     } else {
//       // Back frame
//       lines.addAll([
//         _Line(backRect.topLeft, backRect.topRight),
//         _Line(backRect.topRight, backRect.bottomRight),
//         _Line(backRect.bottomRight, backRect.bottomLeft),
//         _Line(backRect.bottomLeft, backRect.topLeft),
//         // Perspective edges connecting front and back
//         _Line(frontRect.topLeft, backRect.topLeft),
//         _Line(frontRect.topRight, backRect.topRight),
//         _Line(frontRect.bottomLeft, backRect.bottomLeft),
//         _Line(frontRect.bottomRight, backRect.bottomRight),
//       ]);
//     }

//     final glow = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round
//       ..strokeWidth = 7
//       ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
//     final core = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round
//       ..strokeWidth = 2.2;

//     final coreColor = Color.lerp(color, Colors.white, 0.65)!;

//     for (var i = 0; i < lines.length; i++) {
//       // Subtle electric flicker per line
//       final flicker = 0.85 + 0.15 * math.sin(time * 7 + i * 1.7);
//       glow.color = color.withValues(alpha: 0.65 * flicker);
//       core.color = coreColor.withValues(alpha: flicker);
//       canvas.drawLine(lines[i].a, lines[i].b, glow);
//       canvas.drawLine(lines[i].a, lines[i].b, core);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant LaserCagePainter old) =>
//       old.time != time ||
//       old.color != color ||
//       old.front != front ||
//       old.barCount != barCount ||
//       old.widthFactor != widthFactor ||
//       old.heightFactor != heightFactor ||
//       old.centerYFactor != centerYFactor ||
//       old.depth != depth;
// }

// class _Line {
//   const _Line(this.a, this.b);
//   final Offset a;
//   final Offset b;
// }

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Neon laser cage with animated construction / deconstruction.
class LaserCagePainter extends CustomPainter {
  LaserCagePainter({
    required this.color,
    required this.time,
    required this.front,
    required this.barCount,
    this.totalBars,
    this.activeBars,
    this.progress = 1.0,
    this.widthFactor = 0.7,
    this.heightFactor = 0.72,
    this.centerYFactor = 0.50,
    this.depth = 0.85,
  });

  final Color color;
  final double time;
  final bool front;
  final int barCount;

  /// Number of bar slots (positions stay fixed when a bar is removed).
  /// Defaults to [barCount].
  final int? totalBars;

  /// Fractional number of visible bars (4.5 = 4 full bars + 1 half retracted).
  /// Defaults to [barCount].
  final double? activeBars;

  /// Global construction: 0 = empty, 1 = fully built. Frame first, then bars.
  final double progress;

  final double widthFactor;
  final double heightFactor;
  final double centerYFactor;
  final double depth;

  /// Share of [progress] used to draw the frame; the bars use the rest.
  static const double _framePhase = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final w = size.width;
    final h = size.height;

    final frontRect = Rect.fromCenter(
      center: Offset(w / 2, h * centerYFactor),
      width: w * widthFactor,
      height: h * heightFactor,
    );
    final backRect = Rect.fromCenter(
      center: frontRect.center.translate(0, -h * 0.02),
      width: frontRect.width * depth,
      height: frontRect.height * depth,
    );

    final frameT = (progress / _framePhase).clamp(0.0, 1.0);
    final lines = <_Line>[];

    // Frame edges are drawn one after the other.
    void addFrame(List<(Offset, Offset)> edges) {
      for (var i = 0; i < edges.length; i++) {
        final t = (frameT * edges.length - i).clamp(0.0, 1.0);
        lines.add(_Line(edges[i].$1, edges[i].$2, t));
      }
    }

    if (front) {
      addFrame([
        (frontRect.topLeft, frontRect.topRight),
        (frontRect.topRight, frontRect.bottomRight),
        (frontRect.bottomRight, frontRect.bottomLeft),
        (frontRect.bottomLeft, frontRect.topLeft),
      ]);

      // Bars drop from the top, staggered left to right.
      final total = totalBars ?? barCount;
      final active = activeBars ?? barCount.toDouble();
      const barsPhase = 1 - _framePhase;
      final window = barsPhase * 0.4;
      final spread = barsPhase - window;

      for (var i = 0; i < total; i++) {
        final visible = (active - i).clamp(0.0, 1.0);
        if (visible <= 0) continue;

        final start = _framePhase + spread * (total <= 1 ? 0 : i / (total - 1));
        final build = Curves.easeOutCubic.transform(
          ((progress - start) / window).clamp(0.0, 1.0),
        );
        final t = math.min(build, visible);

        final x = frontRect.left + frontRect.width * (i + 1) / (total + 1);
        lines.add(
          _Line(Offset(x, frontRect.top), Offset(x, frontRect.bottom), t),
        );
      }
    } else {
      addFrame([
        (backRect.topLeft, backRect.topRight),
        (backRect.topRight, backRect.bottomRight),
        (backRect.bottomRight, backRect.bottomLeft),
        (backRect.bottomLeft, backRect.topLeft),
        (frontRect.topLeft, backRect.topLeft),
        (frontRect.topRight, backRect.topRight),
        (frontRect.bottomLeft, backRect.bottomLeft),
        (frontRect.bottomRight, backRect.bottomRight),
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
    final tip = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final coreColor = Color.lerp(color, Colors.white, 0.65)!;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.t <= 0) continue;

      final flicker = 0.85 + 0.15 * math.sin(time * 7 + i * 1.7);
      glow.color = color.withValues(alpha: 0.65 * flicker);
      core.color = coreColor.withValues(alpha: flicker);

      final end = Offset.lerp(line.a, line.b, line.t)!;
      canvas.drawLine(line.a, end, glow);
      canvas.drawLine(line.a, end, core);

      // Bright spark at the tip while the line is growing or retracting.
      if (line.t < 1) canvas.drawCircle(end, 4, tip);
    }
  }

  @override
  bool shouldRepaint(covariant LaserCagePainter old) =>
      old.time != time ||
      old.color != color ||
      old.front != front ||
      old.barCount != barCount ||
      old.totalBars != totalBars ||
      old.activeBars != activeBars ||
      old.progress != progress ||
      old.widthFactor != widthFactor ||
      old.heightFactor != heightFactor ||
      old.centerYFactor != centerYFactor ||
      old.depth != depth;
}

class _Line {
  const _Line(this.a, this.b, [this.t = 1.0]);
  final Offset a;
  final Offset b;

  /// Drawn fraction of the line (0 to 1).
  final double t;
}