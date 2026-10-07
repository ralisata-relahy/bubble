import 'dart:math';

/// Time-based motion of the cube: damped spring on yaw (see [poke]),
/// floating and slight scale breathing.
class CubeMotion {
  CubeMotion({
    required this.baseYaw,
    required this.basePitch,
    double? phase,
  }) : _phase = phase ?? Random().nextDouble() * 2 * pi;

  final double baseYaw;
  final double basePitch;
  final double _phase; // desynchronizes multiple cubes

  double _time = 0;
  double _offset = 0;
  double _velocity = 0;

  /// Floating position, -1..1.
  double bob = 0;

  /// Scale multiplier around 1 (breathing).
  double scale = 1;

  double get yaw => baseYaw + _offset;
  double get pitch => basePitch;

  /// Time shifted by the cube phase, shared by all animated effects.
  double get phasedTime => _time + _phase;

  /// On touch / collision: cube snaps and returns in place.
  void poke([double strength = 1]) => _velocity += strength.clamp(-2.0, 2.0) * 4.0;

  void update(double dt) {
    dt = dt.clamp(0.0, 0.05); // spring stability
    _time += dt;

    if (dt > 0) {
      final acceleration = -14 * _offset - 3.2 * _velocity;
      _velocity += acceleration * dt;
      _offset += _velocity * dt;
    }

    bob = sin(phasedTime * 1.1);
    scale = 1 + 0.015 * sin(phasedTime * 1.9);
  }
}