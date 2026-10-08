import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/core/contracts/laser_target.dart';

/// A vibrant, high-impact laser beam component (line and glowing point) whose target
/// can be moved by the user, featuring rich visual effects and hit feedback.
class LaserBeam extends PositionComponent with HasGameReference<FlameGame> {
  LaserBeam({
    required Vector2 origin,
    Vector2? targetPosition,
    this.maxLength = 1200.0,
    this.color = const Color(0xFFFF2A2A),
    this.thickness = 3.5,
    this.obstacles = const [],
  }) : super(position: origin) {
    _targetPosition = targetPosition ?? (origin + Vector2(200, -100));
  }

  late Vector2 _targetPosition;
  final double maxLength;
  final Color color;
  final double thickness;
  final List<PositionComponent> obstacles;

  Vector2 _endPoint = Vector2.zero();
  PositionComponent? _hitTarget;
  PositionComponent? _previousTarget;

  /// Returns the current hit target, if any.
  PositionComponent? get hitTarget => _hitTarget;

  /// Updates the target position controlled by the user.
  void updateTarget(Vector2 newTarget) {
    _targetPosition = newTarget;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _castRay(dt);
  }

  /// Performs a raycast towards the user-controlled target position.
  void _castRay(double dt) {
    final toTarget = _targetPosition - position;
    final distanceToTarget = toTarget.length;
    if (distanceToTarget < 1e-5) return;

    final dir = toTarget.normalized();
    var closestDistance = math.min(distanceToTarget, maxLength);
    PositionComponent? currentTarget;

    // Combine explicit obstacles and all Bubble components in the game
    final targets = <PositionComponent>[...obstacles, ...game.children.whereType<Bubble>()];

    for (final target in targets) {
      if (target == this) continue;

      double? intersectionDistance;
      if (target is LaserTarget) {
        intersectionDistance = (target as LaserTarget).rayCast(position, dir);
      } else {
        final rect = target.toAbsoluteRect();
        intersectionDistance = _intersectRect(position, dir, rect);
      }

      if (intersectionDistance != null && intersectionDistance > 0 && intersectionDistance < closestDistance) {
        closestDistance = intersectionDistance;
        currentTarget = target;
      }
    }

    _endPoint = position + dir * closestDistance;
    _hitTarget = currentTarget;

    // Notify target if it implements LaserTarget
    if (_hitTarget is LaserTarget) {
      (_hitTarget as LaserTarget).onLaserHit(_endPoint, dt);
    }

    // Print statement when hitting or leaving a target
    if (_hitTarget != _previousTarget) {
      if (_hitTarget != null) {
        // ignore: avoid_print
        print('Laser touched target: $_hitTarget');
      } else {
        // ignore: avoid_print
        print('Laser left target');
      }
      _previousTarget = _hitTarget;
    }
  }

  /// Slab method for ray-rectangle intersection.
  double? _intersectRect(Vector2 origin, Vector2 dir, Rect rect) {
    double tMin = 0;
    double tMax = double.infinity;

    for (final axis in [0, 1]) {
      final orig = axis == 0 ? origin.x : origin.y;
      final dirc = axis == 0 ? dir.x : dir.y;
      final minVal = axis == 0 ? rect.left : rect.top;
      final maxVal = axis == 0 ? rect.right : rect.bottom;

      if (dirc.abs() < 1e-9) {
        if (orig < minVal || orig > maxVal) return null;
      } else {
        var t1 = (minVal - orig) / dirc;
        var t2 = (maxVal - orig) / dirc;
        if (t1 > t2) {
          final temp = t1;
          t1 = t2;
          t2 = temp;
        }
        tMin = math.max(tMin, t1);
        tMax = math.min(tMax, t2);
        if (tMin > tMax) return null;
      }
    }
    return tMin;
  }

  @override
  void render(Canvas canvas) {
    final endOffset = (_endPoint - position).toOffset();

    // 1. Outer glow layer for "wow" neon effect
    final outerGlow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = thickness * 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // 2. Inner glow layer
    final innerGlow = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = thickness * 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // 3. Core bright white-hot line
    final core = Paint()
      ..color = Colors.white
      ..strokeWidth = thickness * 0.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, endOffset, outerGlow);
    canvas.drawLine(Offset.zero, endOffset, innerGlow);
    canvas.drawLine(Offset.zero, endOffset, core);

    // Impact point with multi-layer glowing aura
    final impactColor = _hitTarget != null ? Colors.yellowAccent : color;
    
    final impactGlow = Paint()
      ..color = impactColor.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    canvas.drawCircle(endOffset, thickness * 2, impactGlow);
    canvas.drawCircle(endOffset, thickness * 1, Paint()..color = impactColor);
    canvas.drawCircle(endOffset, thickness * 0.6, Paint()..color = Colors.white);
  }
}
