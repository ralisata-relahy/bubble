import 'dart:math';
import 'dart:ui';

import 'cube_face.dart';
import 'cube_palette.dart';

/// Elongated oval highlight, positioned in the lit frame of a face.
///
/// [u], [v]: center in face coordinates; [length] / [thickness]: size as a
/// fraction of the face axes; [strength]: relative brightness.
class Glint {
  const Glint(this.u, this.v, this.length, this.thickness, this.strength);

  final double u, v, length, thickness, strength;
}

/// Fine details on a face: glass grain, micro-bubbles and specular glints.
class SurfaceDetailPainter {
  SurfaceDetailPainter({required this.side, required this.palette})
      : _soft = Paint()
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.006);

  /// Large glint near the lit corner, a small one beside it, and a glint
  /// at the far corner (main face only).
  static const _mainGlints = [
    Glint(0.22, 0.17, 0.36, 0.11, 1.0),
    Glint(0.62, 0.14, 0.12, 0.045, 0.7),
    Glint(0.86, 0.84, 0.12, 0.05, 0.5),
  ];

  /// Discreet glint for the other lit faces.
  static const _sideGlints = [
    Glint(0.22, 0.17, 0.2, 0.07, 0.6),
  ];

  final double side;
  final CubePalette palette;
  final Paint _soft;
  final Paint _fill = Paint();
  final Paint _line = Paint()..style = PaintingStyle.stroke;

  /// Paints details on [face]. The caller must clip the canvas to the face.
  void paint(Canvas c, CubeFace face, {required double time, required bool isMain}) {
    _paintSpecks(c, face, time);
    if (face.light > 0.15) {
      _paintGlints(c, face, time, isMain ? _mainGlints : _sideGlints);
    }
  }

  void _paintSpecks(Canvas c, CubeFace face, double time) {
    for (var i = 0; i < face.specks.length; i++) {
      final speck = face.specks[i];
      // Slow drift so the texture feels alive
      final u = speck.u + 0.012 * sin(time * 0.5 + i);
      final v = speck.v + 0.012 * cos(time * 0.43 + i * 1.7);
      final pos = face.pointAt(u, v);
      final r = speck.radius * side;

      if (speck.isBubble) {
        _line
          ..strokeWidth = side * 0.0015
          ..color = palette.highlight.withValues(alpha: speck.alpha);
        c.drawCircle(pos, r, _line);
        _fill.color = palette.highlight.withValues(alpha: speck.alpha * 0.9);
        c.drawCircle(pos + Offset(-r * 0.35, -r * 0.35), r * 0.28, _fill);
      } else {
        _fill.color = palette.highlight.withValues(
          alpha: speck.alpha * (0.5 + 0.5 * face.light),
        );
        c.drawCircle(pos, r, _fill);
      }
    }
  }

  void _paintGlints(Canvas c, CubeFace face, double time, List<Glint> glints) {
    final frame = face.litFrame();
    final strength = pow(face.light, 1.5).toDouble();
    final sway = 0.012 * sin(time * 0.7);

    for (final g in glints) {
      final pos = frame.at(g.u + sway, g.v);
      c.save();
      c.translate(pos.dx, pos.dy);
      c.rotate(frame.angle);
      _soft.color = palette.highlight.withValues(
        alpha: (g.strength * (0.35 + 0.45 * strength)).clamp(0.0, 0.85),
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: frame.uLength * g.length,
          height: frame.vLength * g.thickness,
        ),
        _soft,
      );
      c.restore();
    }
  }
}