// ignore_for_file: unused_field

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:bubble/core/contracts/laser_target.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';

/// A vibrant laser beam whose target can be moved by the user.
class LaserBeam extends PositionComponent with HasGameReference<FlameGame> {
  LaserBeam({
    required Vector2 origin,
    Vector2? targetPosition,
    this.maxLength = 1200.0,
    this.color = const Color.fromARGB(255, 42, 255, 209),
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

  // ── Paints réutilisés ──────────────────────────────────────────────

  late final Paint _outerGlow = Paint()
    ..color = color.withValues(alpha: 0.18)
    ..strokeWidth = thickness * 5
    ..strokeCap = StrokeCap.round;

  late final Paint _impactGlow = Paint();

  late final Paint _innerGlow = Paint()
    ..color = color.withValues(alpha: 0.75)
    ..strokeWidth = thickness * 2.5
    ..strokeCap = StrokeCap.round;

  late final Paint _core = Paint()
    ..color = Colors.white
    ..strokeWidth = thickness * 0.4
    ..strokeCap = StrokeCap.round;

  final Paint _impactMid = Paint();
  final Paint _impactCore = Paint()..color = Colors.white;

  // ── Soucoupe volante ──────────────────────────────────────────────

  static const double _saucerSize = 100;
  double _saucerTime = 0;

  late final TextPainter _saucer = TextPainter(
    text: const TextSpan(
      text: '🛸',
      style: TextStyle(fontSize: _saucerSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final Paint _saucerShadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.9)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

  PositionComponent? get hitTarget => _hitTarget;

  void updateTarget(Vector2 newTarget) {
    _targetPosition = newTarget;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _saucerTime += dt;
    _castRay(dt);
  }

  void _castRay(double dt) {
    final toTarget = _targetPosition - position;
    final distanceToTarget = toTarget.length;

    if (distanceToTarget < 1e-5) {
      _endPoint = position.clone();
      _hitTarget = null;
      return;
    }

    final dir = toTarget.normalized();

    var closestDistance = math.min(distanceToTarget, maxLength);
    PositionComponent? currentTarget;

    final targets = <PositionComponent>[
      ...obstacles,
      ...game.children.whereType<Bubble>(),
    ];

    for (final target in targets) {
      if (target == this) continue;

      double? intersectionDistance;

      if (target is LaserTarget) {
        intersectionDistance = (target as LaserTarget).rayCast(position, dir);
      } else {
        final rect = target.toAbsoluteRect();
        intersectionDistance = _intersectRect(
          position,
          dir,
          rect,
        );
      }

      if (intersectionDistance != null &&
          intersectionDistance > 0 &&
          intersectionDistance < closestDistance) {
        closestDistance = intersectionDistance;
        currentTarget = target;
      }
    }

    _endPoint = position + dir * closestDistance;
    _hitTarget = currentTarget;

    if (_hitTarget is LaserTarget) {
      (_hitTarget as LaserTarget).onLaserHit(_endPoint, dt);
    }

    _previousTarget = _hitTarget;
  }

  /// Ray / axis-aligned rectangle intersection.
  double? _intersectRect(
    Vector2 origin,
    Vector2 direction,
    Rect rect,
  ) {
    double? tMin;
    double? tMax;

    if (direction.x.abs() < 1e-8) {
      if (origin.x < rect.left || origin.x > rect.right) {
        return null;
      }
    } else {
      final tx1 = (rect.left - origin.x) / direction.x;
      final tx2 = (rect.right - origin.x) / direction.x;

      tMin = math.min(tx1, tx2);
      tMax = math.max(tx1, tx2);
    }

    if (direction.y.abs() < 1e-8) {
      if (origin.y < rect.top || origin.y > rect.bottom) {
        return null;
      }
    } else {
      final ty1 = (rect.top - origin.y) / direction.y;
      final ty2 = (rect.bottom - origin.y) / direction.y;

      final tyMin = math.min(ty1, ty2);
      final tyMax = math.max(ty1, ty2);

      if (tMin == null) {
        tMin = tyMin;
        tMax = tyMax;
      } else {
        tMin = math.max(tMin, tyMin);
        tMax = math.min(tMax!, tyMax);
      }
    }

    if (tMin == null || tMax == null) {
      return null;
    }

    if (tMax < 0 || tMin > tMax) {
      return null;
    }

    return tMin >= 0 ? tMin : tMax;
  }

  @override
  void render(Canvas canvas) {
    final endOffset = (_endPoint - position).toOffset();

    canvas.drawLine(
      Offset.zero,
      endOffset,
      _outerGlow,
    );

    canvas.drawLine(
      Offset.zero,
      endOffset,
      _innerGlow,
    );

    canvas.drawLine(
      Offset.zero,
      endOffset,
      _core,
    );

    final impactColor =
        _hitTarget != null ? Colors.yellowAccent : color;

    _impactGlow.color = impactColor.withValues(alpha: 0.6);

    canvas.drawCircle(
      endOffset,
      thickness * 2,
      _impactGlow,
    );

    _impactMid.color = impactColor;

    canvas.drawCircle(
      endOffset,
      thickness,
      _impactMid,
    );

    canvas.drawCircle(
      endOffset,
      thickness * 0.6,
      _impactCore,
    );

    final bob = math.sin(_saucerTime * 2) * 2;

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 100),
        width: 100,
        height: 20,
      ),
      _saucerShadow,
    );

    canvas
      ..save()
      ..translate(0, bob)
      ..rotate(-15 * math.pi / 180);

    _saucer.paint(
      canvas,
      Offset(
        -_saucer.width / 2 - 10,
        -_saucer.height / 2 + 45,
      ),
    );

    canvas.restore();
  }
}