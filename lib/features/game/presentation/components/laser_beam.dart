// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bubble/core/services/audio/sound_effect.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:bubble/core/contracts/laser_target.dart';
import 'package:bubble/features/ai_buddy/edutainer.dart';

import 'laser_label_box.dart';
import 'trajectory_calculator.dart';

import '../bubble_game.dart';

/// A vibrant laser beam whose target can be moved by the user.
class LaserBeam extends PositionComponent with HasGameReference<BubbleGame> {
  LaserBeam({
    required this.soundEffects,
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

  final SoundEffects soundEffects;
  final LaserLabelBox? _label;

  /// Espace entre le bas du mascotte et le panneau de texte.
  static const double _labelGap = 4;
  static const double _viewportMargin = 12;
  static const double _respawnOffset = 2 * 96 / 2.54;

  /// Updates the current prompt without rebuilding the laser component.
  void updateLabel(String newText, Color newColor) {
    _label
      ?..text = newText
      ..color = newColor;
  }

  /// Retire le panneau de question sans supprimer la mascotte ni le laser.
  void hideLabel() => _label?.removeFromParent();

  double _edutainerScale = 1;
  Vector2 _shotOrigin = Vector2.zero();
  Vector2 _shotEnd = Vector2.zero();
  List<Vector2> _shotPoints = [];
  double _totalShotLength = 0;
  PositionComponent? _shotTargetComponent;
  LaserTarget? _shotLaserTarget;
  double _shotElapsed = 0;
  bool _shotReturning = false;
  bool _shotActive = false;

  /// Longueur du projectile laser de 1 cm (environ 38 pixels sur base 96 DPI).
  static const double projectileLength = 3 * 96 / 2.54;

  /// Vitesse de deplacement du projectile en pixels par seconde.
  static const double _projectileSpeed = 900.0;
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

  /// Origine exacte de depart du tir laser.
  Vector2 get laserOriginPoint => _laserOrigin;

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

  /// Lance un tir en suivant exactement la trajectoire precalculee de la visee.
  /// Fires along the exact preview path so aiming and impact use the same result.
  void fireTrajectory(TrajectoryResult trajectory) {
    if (_shotActive || trajectory.points.isEmpty) return;
    unawaited(soundEffects.play(Sfx.laser));
    _shotOrigin = trajectory.points.first.clone();
    _shotPoints = List<Vector2>.from(trajectory.points);
    _totalShotLength = trajectory.totalLength;
    _shotEnd = trajectory.points.last.clone();
    _shotTargetComponent = trajectory.hitComponent;
    _shotLaserTarget = trajectory.hitLaserTarget;
    _shotElapsed = 0;
    _shotReturning = false;
    _shotActive = true;
    _hitTarget = null;
    _endPoint = _shotOrigin.clone();
  }

  /// Lance un tir le long de la trajectoire avec ricochets jusqu a la premiere cible rencontree.
  /// Calculates and fires a path toward [targetPosition] when no preview exists.
  void fireAt(Vector2 targetPosition) {
    if (_shotActive) return;
    final toTarget = targetPosition - _laserOrigin;
    if (toTarget.length < 1e-4) return;

    final trajectory = TrajectoryCalculator.calculate(
      origin: _laserOrigin,
      initialDirection: toTarget.normalized(),
      gameWidth: game.size.x,
      gameHeight: game.size.y,
      potentialTargets: game.children.whereType<PositionComponent>(),
      maxBounces: 2,
      maxLength: maxLength,
    );
    fireTrajectory(trajectory);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animationTime += dt / game.simulationTimeSteps;
    _updateShot(dt);
  }

  void _updateShot(double dt) {
    if (!_shotActive) return;

    _shotElapsed += dt;
    if (_shotReturning) {
      final progress = (_shotElapsed / _returnDuration).clamp(0.0, 1.0);
      if (progress >= 1) {
        _shotActive = false;
        _hitTarget = null;
      }
      return;
    }

    final headDist = _shotElapsed * _projectileSpeed;
    _endPoint = _pointAlongPath(headDist.clamp(0.0, _totalShotLength));

    if (headDist >= _totalShotLength) {
      _hitTarget = _shotTargetComponent;
      final target = _shotLaserTarget;
      if (target != null && target.canReceiveLaserHit) {
        target.onLaserHit(_shotEnd, dt);
      }
      _shotReturning = true;
      _shotElapsed = 0;
    }
  }

  Vector2 _pointAlongPath(double targetDist) {
    if (_shotPoints.isEmpty) return _shotOrigin;
    if (targetDist <= 0) return _shotPoints.first;

    var accumulated = 0.0;
    for (var i = 0; i < _shotPoints.length - 1; i++) {
      final p1 = _shotPoints[i];
      final p2 = _shotPoints[i + 1];
      final segLength = (p2 - p1).length;

      if (accumulated + segLength >= targetDist) {
        final t = (targetDist - accumulated) / segLength;
        return p1 + (p2 - p1) * t;
      }
      accumulated += segLength;
    }
    return _shotPoints.last;
  }

  List<Vector2> _slicePath(double startDist, double endDist) {
    if (_shotPoints.isEmpty || endDist <= 0) return [];
    final start = math.max(0.0, startDist);
    final end = math.min(_totalShotLength, endDist);
    if (start >= end) return [];

    final result = <Vector2>[];
    result.add(_pointAlongPath(start));

    var accumulated = 0.0;
    for (var i = 0; i < _shotPoints.length - 1; i++) {
      final p1 = _shotPoints[i];
      final p2 = _shotPoints[i + 1];
      final segLength = (p2 - p1).length;
      final segEnd = accumulated + segLength;

      if (accumulated > start && accumulated < end) {
        result.add(p1);
      }
      accumulated = segEnd;
    }
    result.add(_pointAlongPath(end));
    return result;
  }

  @override
  void render(Canvas canvas) {
    if (_shotActive && !_shotReturning) {
      final flicker = 0.85 + 0.15 * math.sin(_animationTime * 24);
      final headDist = _shotElapsed * _projectileSpeed;
      final tailDist = math.max(0.0, headDist - projectileLength);

      // Decoupe le troncon de 1 cm le long de la trajectoire
      final currentPoints = _slicePath(tailDist, headDist);

      // Rendu des segments de faisceau
      for (var i = 0; i < currentPoints.length - 1; i++) {
        final startOffset = (currentPoints[i] - position).toOffset();
        final endOffset = (currentPoints[i + 1] - position).toOffset();
        final direction = endOffset - startOffset;
        final length = direction.distance;
        if (length < 1e-4) continue;

        final normal = Offset(-direction.dy, direction.dx) / length;
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
      }
    }

    if (_shotActive && _shotReturning) {
      final impactEndOffset = (_endPoint - position).toOffset();
      final impactColor = _hitTarget != null ? Colors.yellowAccent : color;
      final flicker = 0.8 + 0.2 * math.sin(_animationTime * 22);
      canvas.drawCircle(
        impactEndOffset,
        20,
        Paint()
          ..color = impactColor.withValues(alpha: 0.5 * flicker)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      final ring = (_animationTime * 1.2) % 1.0;
      canvas.drawCircle(
        impactEndOffset,
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
        final point =
            impactEndOffset + Offset(math.cos(angle), math.sin(angle)) * r;
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
