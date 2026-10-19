// ignore_for_file: unused_field

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:bubble/core/contracts/laser_target.dart';
import 'package:bubble/features/ai_buddy/edutainer.dart';

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
  LaserTarget? _previousTarget;

  // ── Paints réutilisés ──────────────────────────────────────────────

  late final Paint _outerGlow = Paint()
    ..color = color.withValues(alpha: 0.18)
    ..strokeWidth = thickness * 0.5
    ..strokeCap = StrokeCap.round;

  late final Paint _impactGlow = Paint();

  late final Paint _innerGlow = Paint()
    ..color = color.withValues(alpha: 0.75)
    ..strokeWidth = thickness * 0.5
    ..strokeCap = StrokeCap.round;

  late final Paint _core = Paint()
    ..color = Colors.white
    ..strokeWidth = thickness * 0.1
    ..strokeCap = StrokeCap.round;

  final Paint _impactMid = Paint();
  final Paint _impactCore = Paint()..color = Colors.white;

  // ── Edutainer ──────────────────────────────────────────────────────

  static const Size _edutainerSize = Size(150, 180);
  double _animationTime = 0;

  EdutainerPose get _pose =>
      EdutainerPose.idle(_animationTime).withEmotion(EdutainerEmotion.normal);

  EdutainerPainter _createEdutainerPainter() => EdutainerPainter(
    _pose,
    showShadow: true,
    laserColor: color,
    saucerColor: color,
  );

  Vector2 get _laserOrigin {
    final offset = _createEdutainerPainter().laserOrigin(_edutainerSize);
    // The character is painted centered around the component origin below.
    // Convert the painter's top-left-relative point into that same local space.
    return position +
        Vector2(
          offset.dx - _edutainerSize.width / 2,
          offset.dy - _edutainerSize.height / 2,
        );
  }

  PositionComponent? get hitTarget => _hitTarget;

  void updateTarget(Vector2 newTarget) {
    _targetPosition = newTarget;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _animationTime += dt;
    _castRay(dt);
  }

  void _castRay(double dt) {
    final laserOrigin = _laserOrigin;
    final toTarget = _targetPosition - laserOrigin;
    final distanceToTarget = toTarget.length;

    if (distanceToTarget < 1e-5) {
      _endPoint = laserOrigin;
      _hitTarget = null;
      _previousTarget = null;
      return;
    }

    final dir = toTarget.normalized();

    var closestDistance = math.min(distanceToTarget, maxLength);

    // Obstacles can clip the beam, but bubbles are only candidates at its tip.
    for (final obstacle in obstacles) {
      final intersectionDistance = _intersectRect(
        laserOrigin,
        dir,
        obstacle.toAbsoluteRect(),
      );

      if (intersectionDistance != null &&
          intersectionDistance > 0 &&
          intersectionDistance < closestDistance) {
        closestDistance = intersectionDistance;
      }
    }

    _endPoint = laserOrigin + dir * closestDistance;

    LaserTarget? pointTarget;
    PositionComponent? pointTargetComponent;
    for (final component in game.children.whereType<PositionComponent>()) {
      if (component is! LaserTarget) continue;
      final target = component as LaserTarget;
      if (!target.containsLaserPoint(_endPoint)) continue;

      pointTarget = target;
      pointTargetComponent = component;
      break;
    }

    _hitTarget = pointTarget?.canReceiveLaserHit == true
        ? pointTargetComponent
        : null;

    if (pointTarget != _previousTarget) {
      if (pointTarget?.canReceiveLaserHit == true) {
        pointTarget!.onLaserHit(_endPoint, dt);
      }
      _previousTarget = pointTarget;
    }
  }

  /// Ray / axis-aligned rectangle intersection.
  double? _intersectRect(Vector2 origin, Vector2 direction, Rect rect) {
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
    final startOffset = (_laserOrigin - position).toOffset();
    final endOffset = (_endPoint - position).toOffset();
    final direction = endOffset - startOffset;
    final length = direction.distance;
    if (length > 1e-5) {
      final normal = Offset(-direction.dy, direction.dx) / length;
      final flicker = 0.8 + 0.2 * math.sin(_animationTime * 22);
      Path beam(double startWidth, double endWidth) => Path()
        ..moveTo(
          startOffset.dx + normal.dx * startWidth,
          startOffset.dy + normal.dy * startWidth,
        )
        ..lineTo(
          endOffset.dx + normal.dx * endWidth,
          endOffset.dy + normal.dy * endWidth,
        )
        ..lineTo(
          endOffset.dx - normal.dx * endWidth,
          endOffset.dy - normal.dy * endWidth,
        )
        ..lineTo(
          startOffset.dx - normal.dx * startWidth,
          startOffset.dy - normal.dy * startWidth,
        )
        ..close();

      canvas.drawPath(
        beam(thickness * 2.6, thickness * 1.4),
        Paint()
          ..color = color.withValues(alpha: 0.45 * flicker)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        beam(thickness * 0.7, thickness * 0.35),
        Paint()
          ..shader = ui.Gradient.linear(startOffset, endOffset, [
            Colors.white.withValues(alpha: flicker),
            color.withValues(alpha: 0.9 * flicker),
          ]),
      );

      for (var i = 0; i < 3; i++) {
        final u = (_animationTime * 1.4 + i / 3) % 1.0;
        canvas.drawCircle(
          Offset.lerp(startOffset, endOffset, u)!,
          thickness * 0.9 * (1 - u * 0.4),
          Paint()..color = Colors.white.withValues(alpha: 0.9 * flicker),
        );
      }
    }

    final impactColor = _hitTarget != null ? Colors.yellowAccent : color;

    final flicker = 0.8 + 0.2 * math.sin(_animationTime * 22);
    canvas.drawCircle(
      endOffset,
      20,
      Paint()
        ..color = impactColor.withValues(alpha: 0.5 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final ring = (_animationTime * 1.2) % 1.0;
    canvas.drawCircle(
      endOffset,
      8 + ring * 24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = impactColor.withValues(alpha: (1 - ring) * 0.8 * flicker),
    );
    final radius = 13 + 3 * math.sin(_animationTime * 9);
    final star = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? radius : radius * 0.28;
      final angle = _animationTime * 2 + i * math.pi / 4;
      final point = endOffset + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()..color = Colors.white.withValues(alpha: 0.95 * flicker),
    );

    final edutainer = _createEdutainerPainter();
    canvas
      ..save()
      ..translate(-_edutainerSize.width / 2, -_edutainerSize.height / 2);
    edutainer.paint(canvas, _edutainerSize);
    canvas.restore();
  }
}
