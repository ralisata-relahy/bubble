import 'package:flame/components.dart';

/// Interface representing an interactive target that can be hit by a laser beam.
abstract interface class LaserTarget {
  /// Casts a ray against the target and returns the distance `t`, or null if no hit.
  double? rayCast(Vector2 origin, Vector2 direction);

  /// Called when the laser beam hits this target.
  void onLaserHit(Vector2 point, double dt);
}
