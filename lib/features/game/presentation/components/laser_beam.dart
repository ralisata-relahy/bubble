// ignore_for_file: unused_field

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bubble/audio_generation/sound_effect.dart';

import 'laser_label_box.dart';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:bubble/core/contracts/laser_target.dart';
import 'package:bubble/features/ai_buddy/edutainer.dart';

import '../bubble_game.dart';

/// A vibrant laser beam whose target can be moved by the user.
class LaserBeam extends PositionComponent with HasGameReference<BubbleGame> {
  final LaserLabelBox? _label;

  /// Espace entre le bas du mascotte et le panneau de texte.
  static const double _labelGap = 4;
  static const double _viewportMargin = 12;
  static const double _respawnOffset = 2 * 96 / 2.54;

  LaserBeam({
    required Vector2 origin,
    Vector2? targetPosition,
    this.maxLength = 1200.0,
    this.color = const Color.fromARGB(255, 42, 255, 209),
    this.thickness = 3.5,
    this.obstacles = const [],
    String? label,
    Color? labelColor,
  }) : _label = (label == null || label.isEmpty)
           ? null
           : LaserLabelBox(text: label, accentColor: labelColor ?? color),
       super(position: origin) {
    _endPoint = targetPosition ?? origin.clone();
    if (_label != null) add(_label);
  }

  void updateLabel(String newText, Color newColor) {
    _label
      ?..text = newText
      ..color = newColor;
  }

  double _edutainerScale = 1;
  Vector2 _shotOrigin = Vector2.zero();
  Vector2 _shotEnd = Vector2.zero();
  PositionComponent? _shotTargetComponent;
  LaserTarget? _shotLaserTarget;
  double _shotElapsed = 0;
  bool _shotReturning = false;
  bool _shotActive = false;

  static const double _outboundDuration = 0.3;
  static const double _returnDuration = 0.05;

  Size get _scaledEdutainerSize => Size(
    _edutainerSize.width * _edutainerScale,
    _edutainerSize.height * _edutainerScale,
  );

  final double maxLength;
  final Color color;
  final double thickness;
  final List<PositionComponent> obstacles;

  Vector2 _endPoint = Vector2.zero();

  PositionComponent? _hitTarget;
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
    final edutainerSize = _scaledEdutainerSize;
    final offset = _createEdutainerPainter().laserOrigin(edutainerSize);
    // The character is painted centered around the component origin below.
    // Convert the painter's top-left-relative point into that same local space.
    return position +
        Vector2(
          offset.dx - edutainerSize.width / 2,
          offset.dy - edutainerSize.height / 2,
        );
  }

  /// Ligne de réapparition des bulles, deux centimètres au-dessus du laser.
  double get bubbleRespawnY => _laserOrigin.y - _respawnOffset;

  PositionComponent? get hitTarget => _hitTarget;

  /// Adapte la mascotte et son panneau à l'espace disponible dans le canvas.
  void fitToViewport(Vector2 viewportSize) {
    final maxLabelWidth = (viewportSize.x - _viewportMargin * 2)
        .clamp(48.0, 352.0)
        .toDouble();
    _label?.maxWidth = maxLabelWidth;

    final labelHeight = _label?.size.y ?? 0;
    final widthScale =
        (viewportSize.x - _viewportMargin * 2) / _edutainerSize.width;
    final heightScale =
        (viewportSize.y - labelHeight - _labelGap - _viewportMargin * 2) /
        _edutainerSize.height;
    _edutainerScale = math
        .min(1.0, math.min(widthScale, heightScale))
        .clamp(0.45, 1.0)
        .toDouble();

    final edutainerSize = _scaledEdutainerSize;
    final minY = edutainerSize.height / 2 + _viewportMargin;
    final maxY = math.max(
      minY,
      viewportSize.y -
          edutainerSize.height / 2 -
          _labelGap -
          labelHeight -
          _viewportMargin,
    );
    position.setValues(
      viewportSize.x / 2,
      (viewportSize.y * 0.76).clamp(minY, maxY).toDouble(),
    );
    _label?.position.y = edutainerSize.height / 2 + _labelGap;
  }

  /// Lance un tir jusqu'au point demandé, arrêté par la première bulle rencontrée.
  void fireAt(Vector2 targetPosition) {
    if (_shotActive) return;
    SoundEffects.play(Sfx.laser);
    _shotOrigin = _laserOrigin;
    final toTarget = targetPosition - _shotOrigin;
    final distance = math.min(toTarget.length, maxLength);
    if (distance < 1e-5) return;

    final direction = toTarget.normalized();
    var impactDistance = distance;
    PositionComponent? impactTarget;
    LaserTarget? laserTarget;

    for (final obstacle in obstacles) {
      final intersection = _intersectRect(
        _shotOrigin,
        direction,
        obstacle.toAbsoluteRect(),
      );
      if (intersection != null &&
          intersection > 0 &&
          intersection < impactDistance) {
        impactDistance = intersection;
        impactTarget = null;
      }
    }

    for (final component in game.children.whereType<PositionComponent>()) {
      if (component is! LaserTarget) continue;
      final target = component as LaserTarget;
      if (!target.canReceiveLaserHit) continue;

      final intersection = _intersectEllipse(
        _shotOrigin,
        direction,
        component.toAbsoluteRect(),
      );
      if (intersection != null &&
          intersection > 0 &&
          intersection < impactDistance) {
        impactDistance = intersection;
        impactTarget = component;
        laserTarget = target;
      }
    }

    _shotEnd = _shotOrigin + direction * impactDistance;
    _shotTargetComponent = impactTarget;
    _shotLaserTarget = laserTarget;
    _shotElapsed = 0;
    _shotReturning = false;
    _shotActive = true;
    _hitTarget = null;
    _endPoint = _shotOrigin.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);

    _animationTime += dt;
    _updateShot(dt);
  }

  void _updateShot(double dt) {
    if (!_shotActive) return;

    _shotElapsed += dt;
    if (_shotReturning) {
      final progress = (_shotElapsed / _returnDuration).clamp(0.0, 1.0);
      _endPoint = Vector2(
        _shotEnd.x + (_shotOrigin.x - _shotEnd.x) * progress,
        _shotEnd.y + (_shotOrigin.y - _shotEnd.y) * progress,
      );
      if (progress >= 1) {
        _shotActive = false;
        _hitTarget = null;
      }
      return;
    }

    final progress = (_shotElapsed / _outboundDuration).clamp(0.0, 1.0);
    _endPoint = Vector2(
      _shotOrigin.x + (_shotEnd.x - _shotOrigin.x) * progress,
      _shotOrigin.y + (_shotEnd.y - _shotOrigin.y) * progress,
    );
    if (progress >= 1) {
      _hitTarget = _shotTargetComponent;
      final target = _shotLaserTarget;
      if (target != null && target.canReceiveLaserHit) {
        target.onLaserHit(_shotEnd, dt);
      }
      _shotReturning = true;
      _shotElapsed = 0;
    }
  }

  /// Distance at which a ray first enters an axis-aligned ellipse.
  double? _intersectEllipse(Vector2 origin, Vector2 direction, Rect rect) {
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
    final startOffset = (_shotOrigin - position).toOffset();
    final endOffset = (_endPoint - position).toOffset();
    final direction = endOffset - startOffset;
    final length = direction.distance;
    if (_shotActive && length > 1e-5) {
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

    if (_shotActive) {
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
    }

    final edutainer = _createEdutainerPainter();
    final edutainerSize = _scaledEdutainerSize;
    canvas
      ..save()
      ..translate(-edutainerSize.width / 2, -edutainerSize.height / 2);
    edutainer.paint(canvas, edutainerSize);
    canvas.restore();
  }
}
