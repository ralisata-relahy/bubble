import 'package:flutter/material.dart';

class SaucerPalette {
  const SaucerPalette({
    required this.stem,
    required this.discTop,
    required this.discMid,
    required this.discBottom,
    required this.discEdge,
    required this.ringGlow,
    required this.orbitArc,
    required this.orbGlow,
    required this.orbLight,
    required this.orbMid,
    required this.orbDark,
  });

  final List<Color> stem;
  final Color discTop, discMid, discBottom, discEdge;
  final Color ringGlow, orbitArc, orbGlow;
  final Color orbLight, orbMid, orbDark;

  factory SaucerPalette.from(Color? base) {
    if (base == null) {
      return const SaucerPalette(
        stem: [Color(0xFFE08A00), Color(0xFFFFD24A), Color(0xFFD97F00)],
        discTop: Color(0xFFFFE27A),
        discMid: Color(0xFFFFB81F),
        discBottom: Color(0xFFE08A00),
        discEdge: Color(0xFFC77700),
        ringGlow: Color(0xFFFFF6C8),
        orbitArc: Color(0xCCFFE066),
        orbGlow: Color(0xFFFFE066),
        orbLight: Color(0xFFFFF3A0),
        orbMid: Color(0xFFFFC01E),
        orbDark: Color(0xFFD98100),
      );
    }
    final hsl = HSLColor.fromColor(base);
    Color l(double d) =>
        hsl.withLightness((hsl.lightness + d).clamp(0.0, 1.0)).toColor();
    return SaucerPalette(
      stem: [l(-0.10), l(0.15), l(-0.14)],
      discTop: l(0.20),
      discMid: base,
      discBottom: l(-0.10),
      discEdge: l(-0.20),
      ringGlow: l(0.35),
      orbitArc: l(0.22).withAlpha(0xCC),
      orbGlow: l(0.22),
      orbLight: l(0.30),
      orbMid: base,
      orbDark: l(-0.12),
    );
  }
}