import 'dart:math' as math;

import 'package:flame/components.dart';

/// Contract shared by moving bubble components that take part in collisions.
abstract class BubblePhysicsBody {
  /// Current 2D position in game world coordinates.
  Vector2 get position;

  /// Circular collision boundary radius.
  double get collisionRadius;

  /// Indicates whether the bubble can currently participate in collisions.
  bool get isCollisionActive;

  /// Normalized direction unit vector for linear drift.
  Vector2 get moveDir;

  /// Perpendicular unit vector for wave oscillation.
  Vector2 get movePerp;

  /// Un-oscillated center base position.
  Vector2 get centerBase;

  /// Movement speed in logical pixels per second.
  double get speed;

  /// Sinusoidal wave oscillation amplitude in pixels.
  double get waveAmplitude;

  /// Wave oscillation angular frequency in radians per second.
  double get waveFrequency;

  /// Accumulated elapsed time for the wave equation.
  double get waveTime;
  set waveTime(double value);
}

/// Separates overlapping bubbles and applies an elastic impulse along their normal.
/// It also adjusts each bubble's wave phase to avoid a visible position jump.
class BubbleCollisionResolver {
  BubbleCollisionResolver._();

  /// Default extra gap maintained between colliding bubble radii.
  static const double defaultPadding = 6.0;

  /// Elastic restitution coefficient for realistic bubble rebounds.
  static const double _restitution = 1.0;

  /// Minimum separation distance threshold before applying fallback separation.
  static const double _epsilon = 0.001;

  /// Detects and resolves elastic collision between two bubble physics bodies.
  static void resolve(
    BubblePhysicsBody bodyA,
    BubblePhysicsBody bodyB, {
    double padding = defaultPadding,
  }) {
    // Check collision active flags for both bodies.
    if (!bodyA.isCollisionActive || !bodyB.isCollisionActive) return;

    final delta = bodyB.position - bodyA.position;
    var distance = delta.length;
    final minDistance = bodyA.collisionRadius + bodyB.collisionRadius + padding;

    // No overlap detected.
    if (distance >= minDistance) return;

    // 1. Calculate normal unit vector between centers.
    Vector2 normal;
    if (distance < _epsilon) {
      // Exact overlap has no center-to-center direction; infer one from motion.
      final dirDiff = bodyA.moveDir - bodyB.moveDir;
      normal = dirDiff.length > _epsilon ? dirDiff.normalized() : Vector2(1, 0);
      distance = _epsilon;
    } else {
      normal = delta / distance;
    }

    // Treat squared radius as mass so larger bubbles move less when separated.
    final overlap = minDistance - distance;
    final massA = bodyA.collisionRadius * bodyA.collisionRadius;
    final massB = bodyB.collisionRadius * bodyB.collisionRadius;
    final totalMass = massA + massB;

    final weightA = massB / totalMass;
    final weightB = massA / totalMass;

    final separationA = normal * (overlap * weightA);
    final separationB = normal * (overlap * weightB);

    bodyA.position.sub(separationA);
    bodyA.centerBase.sub(separationA);

    bodyB.position.add(separationB);
    bodyB.centerBase.add(separationB);

    // Tangential motion is unchanged; only the normal velocity is exchanged.
    final velocityA = bodyA.moveDir * bodyA.speed;
    final velocityB = bodyB.moveDir * bodyB.speed;

    final vaNormal = velocityA.dot(normal);
    final vbNormal = velocityB.dot(normal);
    final relativeVelocity = vaNormal - vbNormal;

    // Bubbles are moving towards each other: apply rebound impulse.
    if (relativeVelocity > 0) {
      final impulse =
          (1.0 + _restitution) * relativeVelocity / (1.0 / massA + 1.0 / massB);

      velocityA.sub(normal * (impulse / massA));
      velocityB.add(normal * (impulse / massB));

      // Update body A kinematics.
      if (velocityA.length > _epsilon) {
        final oldPerpA = bodyA.movePerp.clone();
        bodyA.moveDir.setFrom(velocityA.normalized());
        bodyA.movePerp.setValues(-bodyA.moveDir.y, bodyA.moveDir.x);
        _preserveWaveContinuity(bodyA, oldPerpA);
      }

      // Update body B kinematics.
      if (velocityB.length > _epsilon) {
        final oldPerpB = bodyB.movePerp.clone();
        bodyB.moveDir.setFrom(velocityB.normalized());
        bodyB.movePerp.setValues(-bodyB.moveDir.y, bodyB.moveDir.x);
        _preserveWaveContinuity(bodyB, oldPerpB);
      }
    }
  }

  /// Recalculates wave phase to eliminate spatial discontinuities upon rebound.
  /// Prevents visual jitter when the orthogonal oscillation vector pivots.
  static void _preserveWaveContinuity(BubblePhysicsBody body, Vector2 oldPerp) {
    if (body.waveAmplitude <= _epsilon || body.waveFrequency <= _epsilon) {
      return;
    }

    // Calculate previous oscillatory offset.
    final oldWaveOffset =
        oldPerp *
        (math.sin(body.waveTime * body.waveFrequency) * body.waveAmplitude);

    // Project previous displacement onto the new orthogonal vector.
    final projection = oldWaveOffset.dot(body.movePerp);
    final normalizedScalar = (projection / body.waveAmplitude).clamp(-1.0, 1.0);

    // Derive coherent phase angle for the new direction.
    final targetAngle = math.asin(normalizedScalar);
    body.waveTime = targetAngle / body.waveFrequency;

    // Adjust centerBase so the sum (centerBase + wave) remains completely continuous.
    final newWaveOffset =
        body.movePerp *
        (math.sin(body.waveTime * body.waveFrequency) * body.waveAmplitude);
    body.centerBase.setFrom(body.position - newWaveOffset);
  }
}
