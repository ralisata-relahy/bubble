import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:bubble/core/contracts/laser_target.dart';

/// Resultat du calcul de trajectoire avec ricochets.
class TrajectoryResult {
  /// Ensemble des points ordonnes formant les segments successifs du faisceau.
  final List<Vector2> points;

  /// Composant finalement touche a l'extremite du tir, s'il existe.
  final PositionComponent? hitComponent;

  /// Cible laser associee a l'impact final.
  final LaserTarget? hitLaserTarget;

  /// Longueur totale cumulee de tous les segments.
  final double totalLength;

  const TrajectoryResult({
    required this.points,
    required this.totalLength,
    this.hitComponent,
    this.hitLaserTarget,
  });
}

/// Calculateur deterministe de trajectoire multi-segments avec ricochets lateraux.
class TrajectoryCalculator {
  TrajectoryCalculator._();

  /// Calcule la trajectoire partant de [origin] le long de [initialDirection].
  /// Ricoche sur les parois laterales `x = 0` et `x = gameWidth` jusqu'a [maxBounces].
  /// S'arrete des qu'une cible [LaserTarget] est rencontree ou que le plafond/sol/portee max est atteint.
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
      double closestTargetDist = double.infinity;
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

      // 2. Calcule la distance jusqu'au prochain mur lateral (gauche x=0 ou droite x=gameWidth)
      double wallDist = double.infinity;

      if (currentDir.x < -1e-6) {
        // Se dirige vers la gauche
        final d = (0.0 - currentOrigin.x) / currentDir.x;
        if (d > 0.01) {
          wallDist = d;
        }
      } else if (currentDir.x > 1e-6) {
        // Se dirige vers la droite
        final d = (gameWidth - currentOrigin.x) / currentDir.x;
        if (d > 0.01) {
          wallDist = d;
        }
      }

      // 3. Calcule la distance jusqu'au plafond (y=0) ou sol (y=gameHeight)
      double ceilingDist = double.infinity;
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

      // Si une cible est frappee en premier
      if (closestTargetDist <= segmentDist && closestTarget != null) {
        finalHitComponent = closestComponent;
        finalHitTarget = closestTarget;
        break;
      }

      // Si la portee maximale est atteinte ou si on touche le plafond/sol
      if (remainingLength <= 0.01 || ceilingDist <= segmentDist) {
        break;
      }

      // Si on touche un mur lateral et qu'on a le droit de rebondir
      if (wallDist <= segmentDist && bounce < maxBounces) {
        currentOrigin = nextPoint;
        // Ricochet : inverse la vitesse horizontale dx
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

  /// Intersection rayon - ellipse alignee sur les axes.
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
