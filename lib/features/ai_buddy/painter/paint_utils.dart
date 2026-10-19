import 'dart:math' as math;

import 'package:flutter/material.dart';

// Color 
Color fade(Color c, double o) =>
    c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

double deg(double d) => d * math.pi / 180;

/// Yellow "action lines"
void drawBurst(
  Canvas c,
  Offset o,
  double a0,
  double spread,
  double alpha, {
  int n = 3,
  double inner = 14,
  double outer = 30,
}) {
  if (alpha <= 0.03) return;
  final p = Paint()
    ..color = fade(const Color(0xFFFFD21F), alpha)
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < n; i++) {
    final a = a0 + (i - (n - 1) / 2) * spread;
    final d = Offset(math.cos(a), math.sin(a));
    c.drawLine(o + d * inner, o + d * outer, p);
  }
}
