import 'package:flame/components.dart';

/// Domain interface representing a target that can be hit by a laser beam.
abstract interface class LaserTarget {
  /// Indicates whether the laser endpoint is inside this target.
  bool containsLaserPoint(Vector2 point);

  /// Indicates whether this target is currently able to react to the laser.
  bool get canReceiveLaserHit;

  /// Called when the laser beam hits this target.
  void onLaserHit(Vector2 point, double dt);
}
