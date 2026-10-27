import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:bubble/core/contracts/laser_target.dart';

/// Result of deterministic trajectory calculation including multi-bounce segments and hit target.
class TrajectoryResult {
  /// Ordered sequence of 2D vertices forming successive beam segments.
  final List<Vector2> points;

  /// Game component struck at the terminal point of the trajectory, if any.
  final PositionComponent? hitComponent;

  /// LaserTarget interface associated with the final hit.
  final LaserTarget? hitLaserTarget;

  /// Total cumulative path length across all segments.
  final double totalLength;

  const TrajectoryResult({
    required this.points,
    required this.totalLength,
    this.hitComponent,
    this.hitLaserTarget,
  });
}

/// Deterministic multi-segment laser trajectory calculator with lateral wall bounces.
class TrajectoryCalculator {
  TrajectoryCalculator._();

  /// Calculates the laser beam trajectory starting at [origin] along [initialDirection].
  ///
  /// Bounces off lateral side walls (`x = 0` and `x = gameWidth`) up to [maxBounces] times.
  /// Stops immediately when a valid [LaserTarget] is struck, or when ceiling/floor/range limits are hit.
  static TrajectoryResult calculate({
    required Vector2 origin,
    required Vector2 initialDirection,
    required double gameWidth,
    required double gameHeight,
    required Iterable<PositionComponent> potentialTargets,
    int maxBounces = 3,
    double maxLength = 2000.0,
  }) {
    final points = <Vector2>[origin.clone()];
    var currentOrigin = origin.clone();
    var currentDir = initialDirection.normalized();
    var remainingLength = maxLength;
    var totalLength = 0.0;

    PositionComponent? finalHitComponent;
    LaserTarget? finalHitTarget;

    for (var bounce = 0; bounce <= maxBounces; bounce++) {
      if (remainingLength <= 0.01) break;

      // Find the nearest eligible hit before comparing it with wall and edge events.
      var closestTargetDist = double.infinity;
      PositionComponent? closestComponent;
      LaserTarget? closestTarget;

      for (final comp in potentialTargets) {
        if (comp is! LaserTarget) continue;
        final target = comp as LaserTarget;
        if (!target.canReceiveLaserHit) continue;

        final dist = _intersectEllipse(
          currentOrigin,
          currentDir,
          comp.toAbsoluteRect(),
        );

        if (dist != null && dist > 0.01 && dist < closestTargetDist) {
          closestTargetDist = dist;
          closestComponent = comp;
          closestTarget = target;
        }
      }

      // 2. Calculate distance to nearest lateral wall (left x=0 or right x=gameWidth)
      var wallDist = double.infinity;

      if (currentDir.x < -1e-6) {
        // Heading towards left wall
        final d = (0.0 - currentOrigin.x) / currentDir.x;
        if (d > 0.01) {
          wallDist = d;
        }
      } else if (currentDir.x > 1e-6) {
        // Heading towards right wall
        final d = (gameWidth - currentOrigin.x) / currentDir.x;
        if (d > 0.01) {
          wallDist = d;
        }
      }

      // 3. Calculate distance to ceiling (y=0) or floor (y=gameHeight)
      var ceilingDist = double.infinity;
      if (currentDir.y < -1e-6) {
        final d = (0.0 - currentOrigin.y) / currentDir.y;
        if (d > 0.01) ceilingDist = d;
      } else if (currentDir.y > 1e-6) {
        final d = (gameHeight - currentOrigin.y) / currentDir.y;
        if (d > 0.01) ceilingDist = d;
      }

      // Only the nearest event can end this segment; later events are recalculated
      // after a bounce from the new origin and direction.
      final minEventDist = math.min(
        closestTargetDist,
        math.min(wallDist, ceilingDist),
      );

      final segmentDist = math.min(minEventDist, remainingLength);
      final nextPoint = currentOrigin + currentDir * segmentDist;

      points.add(nextPoint);
      totalLength += segmentDist;
      remainingLength -= segmentDist;

      // If a target bubble is struck first
      if (closestTargetDist <= segmentDist && closestTarget != null) {
        finalHitComponent = closestComponent;
        finalHitTarget = closestTarget;
        break;
      }

      // If maximum reach is reached or if ceiling/floor boundary is struck
      if (remainingLength <= 0.01 || ceilingDist <= segmentDist) {
        break;
      }

      // If a lateral wall is struck and bounces remain
      if (wallDist <= segmentDist && bounce < maxBounces) {
        currentOrigin = nextPoint;
        // Specular bounce: negate horizontal velocity component
        currentDir = Vector2(-currentDir.x, currentDir.y).normalized();
      } else {
        break;
      }
    }

    return TrajectoryResult(
      points: points,
      totalLength: totalLength,
      hitComponent: finalHitComponent,
      hitLaserTarget: finalHitTarget,
    );
  }

  /// Ray-to-axis-aligned-ellipse intersection check.
  static double? _intersectEllipse(
    Vector2 origin,
    Vector2 direction,
    Rect rect,
  ) {
    // Normalize the ray into unit-ellipse space, solve the quadratic there,
    // then return the nearest forward intersection in the original ray units.
    final radiusX = rect.width / 2;
    final radiusY = rect.height / 2;
    if (radiusX <= 0 || radiusY <= 0) return null;

    final offsetX = (origin.x - rect.center.dx) / radiusX;
    final offsetY = (origin.y - rect.center.dy) / radiusY;
    final directionX = direction.x / radiusX;
    final directionY = direction.y / radiusY;
    final a = directionX * directionX + directionY * directionY;
    final b = 2 * (offsetX * directionX + offsetY * directionY);
    final c = offsetX * offsetX + offsetY * offsetY - 1;
    final discriminant = b * b - 4 * a * c;
    if (a <= 0 || discriminant < 0) return null;

    final root = math.sqrt(discriminant);
    final nearDistance = (-b - root) / (2 * a);
    if (nearDistance >= 0) return nearDistance;

    final farDistance = (-b + root) / (2 * a);
    return farDistance >= 0 ? farDistance : null;
  }
}
