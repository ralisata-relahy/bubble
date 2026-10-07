import 'dart:ui';

import 'cube_palette.dart';

/// Soft shadow and caustic light under the floating cube.
class GroundPainter {
  GroundPainter({required this.side, required this.palette})
      : _shadow = Paint()
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.03),
        _caustic = Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.035);

  final double side;
  final CubePalette palette;
  final Paint _shadow;
  final Paint _caustic;

  /// [bob] is the floating position (-1..1): the shadow is smaller and
  /// paler when the cube ascends.
  void paint(Canvas c, Offset cubeCenter, double bob) {
    final scale = 1 - 0.08 * bob;
    final spot = cubeCenter.translate(0, side * 0.44);

    _shadow.color = const Color(0xFF000000).withValues(alpha: 0.19 * (1 - 0.25 * bob));
    c.drawOval(
      Rect.fromCenter(center: spot, width: side * 0.62 * scale, height: side * 0.07 * scale),
      _shadow,
    );

    // Light focused by the glass in the middle of the shadow
    _caustic.color = palette.base.withValues(alpha: 0.22 * (1 + 0.2 * bob));
    c.drawOval(
      Rect.fromCenter(center: spot, width: side * 0.30 * scale, height: side * 0.028 * scale),
      _caustic,
    );
  }
}