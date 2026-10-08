// ignore_for_file: unused_field

import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../game/bubble_game.dart';
import '../bubble/bubble.dart';

/// A vibrant, high-impact laser beam component (line and glowing point) whose target
/// can be moved by the user, featuring rich visual effects and hit feedback.
class LaserBeam extends PositionComponent with HasGameReference<BubbleGame> {
  LaserBeam({
    required Vector2 origin,
    Vector2? targetPosition,
    this.maxLength = 1200.0,
    this.color = const Color.fromARGB(255, 42, 255, 209),
    this.thickness = 3.5, required List<SpriteComponent> obstacles,
  }) : super(position: origin) {
    _targetPosition = targetPosition ?? (origin + Vector2(200, -100));
  }

  late Vector2 _targetPosition;
  final double maxLength;
  final Color color;
  final double thickness;

  Vector2 _endPoint = Vector2.zero();
  PositionComponent? _hitTarget;
  PositionComponent? _previousTarget;
  // ── Paints réutilisés (zéro allocation par frame) ──
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

  // ── Soucoupe volante (emoji, créée une seule fois) ──
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

  /// Returns the current hit target, if any.
  PositionComponent? get hitTarget => _hitTarget;

  /// Updates the target position controlled by the user.
  void updateTarget(Vector2 newTarget) {
    _targetPosition = newTarget;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _saucerTime += dt;
    _castRay(dt);
  }

  /// Performs a raycast towards the user-controlled target position.
  void _castRay(double dt) {
    final toTarget = _targetPosition - position;
    final distanceToTarget = toTarget.length;
    if (distanceToTarget > 1e-5) {
      final dir = toTarget.normalized();
      _endPoint = position + dir * math.min(distanceToTarget, maxLength);
    } else {
      _endPoint = position.clone();
    }

    Bubble? currentTarget;
    for (final bubble in game.children.whereType<Bubble>()) {
      if (bubble.containsLaserPoint(_endPoint)) {
        currentTarget = bubble;
        break;
      }
    }
    _hitTarget = currentTarget;

    if (currentTarget != null && currentTarget != _previousTarget) {
      currentTarget.onLaserHit(_endPoint, dt);
    }
    _previousTarget = currentTarget;
  }

  @override
  void render(Canvas canvas) {
    final endOffset = (_endPoint - position).toOffset();

    canvas.drawLine(Offset.zero, endOffset, _outerGlow);
    canvas.drawLine(Offset.zero, endOffset, _innerGlow);
    canvas.drawLine(Offset.zero, endOffset, _core);

    final impactColor = _hitTarget != null ? Colors.yellowAccent : color;

    _impactGlow.color = impactColor.withValues(alpha: 0.6);
    canvas.drawCircle(endOffset, thickness * 2, _impactGlow);

    _impactMid.color = impactColor;
    canvas.drawCircle(endOffset, thickness, _impactMid);
    canvas.drawCircle(endOffset, thickness * 0.6, _impactCore);

    final bob = math.sin(_saucerTime * 2) * 2;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 100), width: 100, height: 20),
      _saucerShadow,
    );
    canvas
      ..save()
      ..translate(0, bob)
      ..rotate(-15 * math.pi / 180);
    _saucer.paint(canvas, Offset(-_saucer.width / 2-10, -_saucer.height / 2 + 45));
    canvas.restore();
  }
}
