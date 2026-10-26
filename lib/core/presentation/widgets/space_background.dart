import 'dart:math';

import 'package:flutter/material.dart';

/// Static responsive space background (no animations, very lightweight).
/// Usage: SpaceBackground(child: YourGame())
class SpaceBackground extends StatelessWidget {
  /// Widget placed above the starfield.
  final Widget? child;

  /// Number of stars per 10,000 logical pixels.
  final double density;

  /// Seed: identical values produce an identical sky.
  final int seed;

  /// Additional stars near the bottom edge (0 = none).
  final int groundStars;

  const SpaceBackground({
    super.key,
    this.child,
    this.density = 1.2,
    this.seed = 42,
    this.groundStars = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // RepaintBoundary: the starfield is not repainted during game motion.
        RepaintBoundary(
          child: CustomPaint(
            painter: _SpacePainter(
              density: density,
              seed: seed,
              groundStars: groundStars,
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}

/// Stores one star in normalized coordinates for a responsive background.
class _Star {
  final double x; // 0..1 (relative position)
  final double y; // 0..1
  final double size; // 0..1 (relative size)
  final Color color;

  _Star(this.x, this.y, this.size, this.color);
}

/// Generates [count] well-distributed stars (jittered grid).
/// [yMin]..[yMax] constrain the vertical range (0 = top, 1 = bottom).
List<_Star> _generateStars(
  Random rng,
  int count,
  Size size, {
  double yMin = 0,
  double yMax = 1,
}) {
  if (count <= 0) return [];

  const tints = [
    Colors.white,
    Color(0xFFCFE3FF), // bluish
    Color(0xFFFFF2D6), // warm
  ];

  final bandHeight = yMax - yMin;
  final aspect = size.width / (size.height * bandHeight);

  final cols = max(1, sqrt(count * aspect).ceil());
  final rows = max(1, (count / cols).ceil());
  final cellW = 1 / cols;
  final cellH = bandHeight / rows;

  final result = <_Star>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final x = (c + 0.2 + rng.nextDouble() * 0.6) * cellW;
      final y = yMin + (r + 0.2 + rng.nextDouble() * 0.6) * cellH;
      result.add(
        _Star(
          x,
          y,
          pow(rng.nextDouble(), 3).toDouble(), // predominantly small, few large
          tints[rng.nextInt(tints.length)],
        ),
      );
    }
  }
  return result;
}

/// Paints the seeded star field once behind the live game surface.
class _SpacePainter extends CustomPainter {
  final double density;
  final int seed;
  final int groundStars;

  _SpacePainter({
    required this.density,
    required this.seed,
    required this.groundStars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 10, 15, 51),
            Color.fromARGB(255, 12, 19, 53),
            Color.fromARGB(255, 19, 29, 83),
          ],
        ).createShader(rect),
    );

    // Star count determined by viewport surface area.
    final count = ((size.width * size.height) / 10000 * density).round();
    final rng = Random(seed);

    final stars = [
      ..._generateStars(rng, count, size),
      ..._generateStars(rng, groundStars, size, yMin: 0.85, yMax: 1.0),
    ];

    // Size scaled relative to shortest dimension to fit all displays.
    final unit = min(size.width, size.height);
    final paint = Paint();

    for (final s in stars) {
      final radius = unit * (0.0007 + s.size * 0.0028);
      final center = Offset(s.x * size.width, s.y * size.height);

      paint.color = s.color.withValues(alpha: 0.85);
      canvas.drawCircle(center, radius, paint);

      // Subtle glow halo for larger stars.
      if (s.size > 0.5) {
        paint.color = s.color.withValues(alpha: 0.12);
        canvas.drawCircle(center, radius * 3.5, paint);
      }
    }
  }

  // Only repaint if configuration properties change (resize triggers repaint automatically).
  @override
  bool shouldRepaint(covariant _SpacePainter old) =>
      old.density != density ||
      old.seed != seed ||
      old.groundStars != groundStars;
}
