// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bubble/core/services/audio/sound_effect.dart';
import 'package:bubble/features/game/controllers/game_controller.dart';
import 'package:bubble/features/smarty/widgets/cage_painter.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:bubble/core/contracts/laser_target.dart';
import 'package:bubble/features/smarty/smarty.dart';

import 'laser_label_box.dart';
import 'trajectory_calculator.dart';

import '../bubble_game.dart';

/// A vibrant laser beam whose target can be aimed and fired by the player.
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

  /// Spacing between mascot bottom and label panel.
  static const double _labelGap = 8;
  static const double _viewportMargin = 12;
  static const double _respawnOffset = 2 * 96 / 2.54;
  static const double _cageBuildDuration = 2; // seconds, 0 -> 1
  static const double _cageBarsPerSecond = 3.0; // bar retract speed

  double _cageProgress = 0;
  double? _activeBars;

  /// Updates the current prompt without rebuilding the laser component.
  void updateLabel(String newText, Color newColor) {
    _label
      ?..text = newText
      ..color = newColor;
  }

  /// Hides the question prompt panel without removing the mascot or laser.
  void hideLabel() => _label?.removeFromParent();

  double _smartyScale = 1;
  Vector2 _shotOrigin = Vector2.zero();
  Vector2 _shotEnd = Vector2.zero();
  List<Vector2> _shotPoints = [];
  double _totalShotLength = 0;
  PositionComponent? _shotTargetComponent;
  LaserTarget? _shotLaserTarget;
  double _shotElapsed = 0;
  bool _shotReturning = false;
  bool _shotActive = false;

  /// Length of the moving laser projectile segment (approx 38 pixels on 96 DPI).
  static const double projectileLength = 3 * 96 / 2.54;

  /// Projectile travel speed in logical pixels per second.
  static const double _projectileSpeed = 900.0;
  static const double _returnDuration = 0.05;

  Size get _scaledsmartySize =>
      Size(_smartySize.width * _smartyScale, _smartySize.height * _smartyScale);

  final double maxLength;
  final Color color;
  final double thickness;
  final List<PositionComponent> obstacles;

  Vector2 _endPoint = Vector2.zero();

  PositionComponent? _hitTarget;

  // ---------------------------------------------------------------------------
  // Reusable Paints
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // smarty Mascot Integration
  // ---------------------------------------------------------------------------

  static const Size _smartySize = Size(150, 180);
  double _animationTime = 0;

  SmartyPose get _pose {
    final gc = game.gameController;
    final emotion = (gc.isCaged.value && gc.barreCount.value > 0)
        ? SmartyEmotion.sad
        : SmartyEmotion.normal;
    return SmartyPose.idle(_animationTime).withEmotion(emotion);
  }

  SmartyPainter _createSmartyPainter() => SmartyPainter(
    _pose,
    showShadow: true,
    laserColor: color,
    saucerColor: color,
  );

  Vector2 get _laserOrigin {
    final smartySize = _scaledsmartySize;
    final offset = _createSmartyPainter().laserOrigin(smartySize);
    // The character is painted centered around the component origin below.
    // Convert the painter's top-left-relative point into that same local space.
    return position +
        Vector2(
          offset.dx - smartySize.width / 2,
          offset.dy - smartySize.height / 2,
        );
  }

  /// Bubble boundary line positioned above the laser.
  double get bubbleRespawnY => _laserOrigin.y - _respawnOffset;

  /// Exact origin point of the laser shot.
  Vector2 get laserOriginPoint => _laserOrigin;

  PositionComponent? get hitTarget => _hitTarget;

  /// Adapts mascot and label box to available viewport space.
  void fitToViewport(Vector2 viewportSize) {
    final maxLabelWidth = (viewportSize.x - _viewportMargin * 2)
        .clamp(48.0, 352.0)
        .toDouble();
    _label?.maxWidth = maxLabelWidth;

    final labelHeight = _label?.size.y ?? 0;
    final widthScale =
        (viewportSize.x - _viewportMargin * 2) / _smartySize.width;
    final heightScale =
        (viewportSize.y - labelHeight - _labelGap - _viewportMargin * 2) /
        _smartySize.height;
    _smartyScale = math
        .min(1.0, math.min(widthScale, heightScale))
        .clamp(0.45, 1.0)
        .toDouble();

    final smartySize = _scaledsmartySize;
    final minY = smartySize.height / 2 + _viewportMargin;
    final maxY = math.max(
      minY,
      viewportSize.y -
          smartySize.height / 2 -
          _labelGap -
          labelHeight -
          _viewportMargin,
    );
    position.setValues(
      viewportSize.x / 2,
      (viewportSize.y * 0.76).clamp(minY, maxY).toDouble(),
    );
    _label?.position.y = smartySize.height / 2 + _labelGap;
  }

  /// Fires along the exact preview path so aiming and impact use the same trajectory.
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

  /// Calculates and fires a projectile along trajectory with bounces toward [targetPosition].
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
    _updateCage(dt / game.simulationTimeSteps);
  }

  /// Eases the cage build level and the visible bars toward the controller state.
  void _updateCage(double realDt) {
    final gc = game.gameController;
    final wantCage = gc.isCaged.value;
    final bars = gc.barreCount.value.toDouble();

    _cageProgress = _approach(
      _cageProgress,
      wantCage ? 1.0 : 0.0,
      realDt / _cageBuildDuration,
    );

    // While the cage is absent, snap so a new game starts with all bars.
    if (!wantCage && _cageProgress == 0) {
      _activeBars = bars;
    } else {
      _activeBars = _approach(
        _activeBars ?? bars,
        bars,
        realDt * _cageBarsPerSecond,
      );
    }
  }

  double _approach(double value, double target, double step) => value < target
      ? math.min(value + step, target)
      : math.max(value - step, target);

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

      // Slices the visible projectile segment along the trajectory
      final currentPoints = _slicePath(tailDist, headDist);

      // Render beam segments
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

    final smarty = _createSmartyPainter();
    final smartySize = _scaledsmartySize;

    _paintCage(canvas, smartySize, front: false);
    canvas
      ..save()
      ..translate(-smartySize.width / 2, -smartySize.height / 2);
    smarty.paint(canvas, smartySize);
    canvas.restore();
    _paintCage(canvas, smartySize, front: true);
  }

  void _paintCage(Canvas canvas, Size size, {required bool front}) {
    if (_cageProgress <= 0) return;
    canvas
      ..save()
      ..translate(-size.width / 2, -size.height / 2);
    LaserCagePainter(
      color: color,
      time: _animationTime,
      front: front,
      barCount: game.gameController.barreCount.value,
      totalBars: GameController.initialBarCount,
      activeBars: _activeBars,
      progress: _cageProgress,
      widthFactor: 1.1,
      heightFactor: 1,
      centerYFactor: 0.5,
    ).paint(canvas, size);
    canvas.restore();
  }
}
