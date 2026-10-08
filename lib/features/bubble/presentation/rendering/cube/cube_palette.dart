import 'dart:ui';

/// Monochrome palette derived from a single base color.
///
/// Every tint used by the cube comes from [base], so the cube never
/// introduces colors of its own (no rainbow film).
class CubePalette {
  CubePalette(this.base)
      : veil = Color.lerp(base, white, 0.6)!,
        edge = Color.lerp(base, white, 0.5)!,
        highlight = Color.lerp(base, white, 0.85)!;

  static const white = Color(0xFFFFFFFF);
  static const shade = Color(0xFF0A1A33);

  final Color base;

  /// Milky soap-film tint used for the glass body.
  final Color veil;

  /// Light tint used for edges and bevels.
  final Color edge;

  /// Almost-white tint used for specular highlights.
  final Color highlight;
}