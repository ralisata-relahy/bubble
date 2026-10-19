import 'dart:math' as math;

import '../models/character_pose.dart';
import '../models/saucePalette.dart';
import 'package:flutter/material.dart';

// Shared state + geometry used by every part painter.
class EdutainerContext {
  EdutainerContext({
    required this.pose,
    this.laserColor = const Color(0xFF4DF0FF),
    Color? bodyColor,
    Color? saucerColor,
  })  : bodyGradient = _buildBodyGradient(bodyColor),
        saucer = SaucerPalette.from(saucerColor);

  final EdutainerPose pose;
  final Color laserColor;
  final RadialGradient bodyGradient;
  final SaucerPalette saucer;

  static const Size designSize = Size(400, 520);
  static const Offset pivot = Offset(200, 436);
  static const Offset orb = Offset(200, 92);
  static const Offset eyeCenter = Offset(205, 272);

  double get dy => -pose.bob * 10;
  double get sx => 1 + pose.squash * 0.05;
  double get sy => 1 - pose.squash * 0.06;

  Offset groupPoint(Offset p) {
    var q = p - pivot;
    q = Offset(q.dx * sx, q.dy * sy);
    final c = math.cos(pose.tilt), s = math.sin(pose.tilt);
    q = Offset(q.dx * c - q.dy * s, q.dx * s + q.dy * c);
    return q + pivot + Offset(0, dy);
  }

  static RadialGradient _buildBodyGradient(Color? base) {
    if (base == null) {
      return const RadialGradient(
        center: Alignment(-0.35, -0.5),
        radius: 1.0,
        colors: [Color(0xFFFF6A5C), Color(0xFFE41E1E), Color(0xFFA30D16)],
        stops: [0, 0.55, 1],
      );
    }
    final hsl = HSLColor.fromColor(base);
    Color shade(double d) =>
        hsl.withLightness((hsl.lightness + d).clamp(0.0, 1.0)).toColor();
    return RadialGradient(
      center: const Alignment(-0.35, -0.5),
      radius: 1.0,
      colors: [shade(0.17), base, shade(-0.16)],
      stops: const [0, 0.55, 1],
    );
  }
}
