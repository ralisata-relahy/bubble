import 'dart:ui';

import 'cube_face.dart';
import 'cube_palette.dart';
import 'face_outline.dart';

/// Paints the glass itself: back faces, the milky volume of front faces,
/// the dense rim and the bevelled edges.
class GlassPainter {
  GlassPainter({
    required this.side,
    required this.palette,
    required this.outline,
  })  : _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = side * 0.085
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.022),
        _glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = side * 0.016
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.01),
        _line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

  final double side;
  final CubePalette palette;
  final FaceOutline outline;

  final Paint _rim;
  final Paint _glow;
  final Paint _line;
  final Paint _fill = Paint();

  /// Back face seen through the glass: faint and slightly darkened.
  void paintBack(Canvas c, CubeFace face) {
    final path = outline.build(face.corners);
    _fill.color = palette.base.withValues(alpha: 0.05);
    c.drawPath(path, _fill);
    _fill.color = CubePalette.shade.withValues(alpha: 0.10);
    c.drawPath(path, _fill);
    _stroke(c, path, side * 0.0025, palette.edge.withValues(alpha: 0.26));
  }

  /// Volume of a front face. The caller must clip the canvas to [path].
  void paintVolume(Canvas c, CubeFace face, Path path) {
    final frame = face.litFrame();
    final center = face.center;
    final radius = (face.corners[0] - center).distance;
    final light = face.light;

    // Milky center fading to a slightly tinted edge, like a soap film
    final focal = center + (frame.origin - center) * 0.25;
    _fill.shader = Gradient.radial(
      focal,
      radius * 1.1,
      [
        palette.veil.withValues(alpha: 0.30 + 0.14 * light),
        palette.veil.withValues(alpha: 0.12 + 0.06 * light),
        palette.base.withValues(alpha: (0.16 + 0.14 * face.fresnel).clamp(0.0, 0.4)),
      ],
      const [0.0, 0.65, 1.0],
    );
    c.drawPath(path, _fill);

    // Light dark veil on shaded faces for volume
    _fill.shader = Gradient.linear(
      frame.origin,
      frame.opposite,
      [
        CubePalette.shade.withValues(alpha: 0.03 * (1 - light)),
        CubePalette.shade.withValues(alpha: 0.16 * (1 - light)),
      ],
    );
    c.drawPath(path, _fill);
    _fill.shader = null;

    // Dense whitish rim along the outline (denser at grazing angles)
    _rim.color = palette.veil.withValues(
      alpha: (0.34 + 0.30 * face.fresnel + 0.12 * light).clamp(0.0, 0.8),
    );
    c.drawPath(path, _rim);
  }

  /// Bevel, glow and edge strokes, drawn above the volume (not clipped).
  void paintEdges(Canvas c, CubeFace face, Path path, double pulse) {
    final light = face.light;

    // Inner bevel: a bright seam and a faint one (wall thickness)
    _stroke(
      c,
      outline.build(face.corners, inset: 0.05),
      side * 0.003,
      palette.highlight.withValues(alpha: 0.22 + 0.22 * light),
    );
    _stroke(
      c,
      outline.build(face.corners, inset: 0.11),
      side * 0.0018,
      palette.edge.withValues(alpha: 0.07 + 0.06 * light),
    );

    // Soft glow + thin soft stroke (no hard colored lines)
    _glow.color = palette.edge.withValues(alpha: (0.10 + 0.22 * light).clamp(0.0, 0.35));
    c.drawPath(path, _glow);
    _stroke(
      c,
      path,
      side * 0.0035,
      palette.edge.withValues(alpha: (0.22 + 0.30 * light + pulse).clamp(0.0, 0.7)),
    );

    if (light > 0.15) {
      _stroke(
        c,
        path,
        side * 0.0018,
        CubePalette.white.withValues(alpha: (0.10 + 0.40 * light).clamp(0.0, 0.55)),
      );
    }
  }

  void _stroke(Canvas c, Path path, double width, Color color) {
    _line
      ..strokeWidth = width
      ..color = color;
    c.drawPath(path, _line);
  }
}