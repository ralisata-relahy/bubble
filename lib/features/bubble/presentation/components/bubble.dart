import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'dart:ui';

import 'package:bubble/core/contracts/knowledge_bubble_host.dart';
import 'package:bubble/core/contracts/laser_target.dart';
import 'package:bubble/core/physics/bubble_collision_resolver.dart';
import 'package:bubble/core/services/audio/sound_effect.dart';
import 'package:bubble/core/services/haptics_service.dart';
import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_heat_effect.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_pop_renderer.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_renderer.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show Canvas, Colors, FontWeight, Size, TextStyle;
import 'package:google_fonts/google_fonts.dart';

import 'bubble_label.dart';

/// Primary Flame component representing a floating interactive bubble in the game world.
///
/// Coordinates wave kinematics, elastic collision resolution, laser targeting,
/// thermal heating effects, burst animation, and graphic rendering.
class Bubble extends PositionComponent
    with HasGameReference<FlameGame>
    implements LaserTarget, BubblePhysicsBody {
  /// Creates a bubble with specified position and motion/visual configuration.
  Bubble({
    required Vector2 position,
    this.config = const BubbleConfig(),
    this.textColor = Colors.white,
    this.canPop = _defaultCanPop,
    this.isBurstBubble = false,
    this.onTargetImpact,
    this.onWrongImpact,
    this.onPopped,
    Random? random,
    this.soundEffects,
    this.hapticsService,
  }) : _random = random ?? Random(),
       super(
         position: position,
         size: Vector2(config.style.size.width, config.style.size.height),
         anchor: Anchor.center,
       );

  /// Color of the text displayed inside the bubble.
  final Color textColor;

  /// Configuration specifying shape, style, speed, and wave parameters.
  final BubbleConfig config;

  /// Predicate determining whether this bubble matches the active question's expected answer.
  final bool Function(String text) canPop;

  /// Indicates if this bubble was generated as part of a knowledge celebration scatter.
  final bool isBurstBubble;

  /// Callback fired on successful impact when the laser strikes the correct target bubble.
  final void Function(Vector2 pos)? onTargetImpact;

  /// Callback fired when the laser strikes an incorrect bubble.
  final void Function()? onWrongImpact;

  /// Called once when this bubble is first popped, before its removal from the scene.
  final void Function(String text, bool wasTarget)? onPopped;

  /// Sound effect service for audio playback on impact and popping.
  final SoundEffects? soundEffects;

  /// Haptic feedback service for tactile feedback on incorrect hits.
  final HapticsService? hapticsService;

  /// Default fallback validator for true/false questions.
  static bool _defaultCanPop(String t) {
    final s = t.trim().toLowerCase();
    return s == 'vrai' || s == 'vraie';
  }

  final Random _random;

  /// True if this bubble's text matches the correct answer.
  bool get isTarget => canPop(_text);

  // ---------------------------------------------------------------------------
  // Kinematics and Movement Properties
  // ---------------------------------------------------------------------------

  late String _text = config.text;
  BubbleLabel? _label;
  late BubbleRenderer _renderer;
  late Vector2 _dir;
  late Vector2 _perp;
  late final Vector2 _centerBase;
  late double _t;
  double _squash = 0;
  double _rendererAcc = 0;

  // ---------------------------------------------------------------------------
  // BubblePhysicsBody Contract Implementation
  // ---------------------------------------------------------------------------

  @override
  Vector2 get moveDir => _dir;

  @override
  Vector2 get centerBase => _centerBase;

  @override
  Vector2 get movePerp => _perp;

  @override
  double get speed => config.speed;

  @override
  double get waveAmplitude => config.waveAmplitude;

  @override
  double get waveFrequency => config.waveFrequency;

  @override
  double get waveTime => _t;

  @override
  set waveTime(double value) => _t = value;

  @override
  bool get isCollisionActive => !_isPopping && !_isHidden && _opacity >= 0.5;

  @override
  double get collisionRadius => (size.x + size.y) / 4;

  /// Resolves elastic collision with another physics body using the shared collision resolver.
  void checkAndResolveCollision(
    dynamic other, {
    double padding = BubbleCollisionResolver.defaultPadding,
  }) {
    if (other is BubblePhysicsBody) {
      BubbleCollisionResolver.resolve(this, other, padding: padding);
    }
  }

  // ---------------------------------------------------------------------------
  // State: Error Tinting, Popping, and Laser Heat
  // ---------------------------------------------------------------------------

  double _redness = 0;
  bool _isRed = false;
  static const Color _redColor = Color(0xFFFF1E1E);

  double get _halfW => size.x / 2;
  double get _halfH => size.y / 2;

  final BubbleHeatEffect _heatEffect = BubbleHeatEffect();
  final BubblePopRenderer _popRenderer = BubblePopRenderer();

  bool _isPopping = false;
  bool _hasReportedPop = false;
  double _popProgress = 0.0;
  static const double _returnDelay = 0.5;
  static const int _wrongImpactVibrationDurationMs = 50;
  bool _returnsAfterPop = false;

  bool _isHidden = false;
  double _hiddenTimer = 0;
  double _opacity = 1.0;

  Offset _popOrigin = Offset.zero;
  double _popMaxHole = 1.0;
  final List<PopParticle> _particles = [];

  double get _holeRadius => _popRenderer.calculateHoleRadius(
    popProgress: _popProgress,
    maxHole: _popMaxHole,
  );

  // Reusable rendering objects (zero allocations per frame)
  late final Rect _layerBounds = Rect.fromLTWH(
    -size.x * 0.35,
    -size.y * 0.35,
    size.x * 1.7,
    size.y * 1.7,
  );
  late final Path _ovalPath = Path()
    ..addOval(Rect.fromLTWH(0, 0, size.x, size.y));
  final Paint _plainPaint = Paint();
  final Paint _layerPaint = Paint();
  final Paint _fadePaint = Paint();
  final Paint _clearPaint = Paint()..blendMode = BlendMode.clear;

  final List<double> _tintMatrix = List<double>.filled(20, 0);
  double _lastTintRed = -1;
  double _lastTintOpacity = -1;

  late final TextStyle _labelStyle = () {
    final shortSide = min(size.x, size.y);
    return GoogleFonts.poppins(
      color: textColor,
      fontSize: 33,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Colors.black45,
          offset: Offset(0, shortSide * 0.015),
          blurRadius: shortSide * 0.03,
        ),
      ],
    );
  }();

  /// Updates the displayed label text.
  set text(String value) {
    _text = value;
    if (_isPopping || _isHidden) return;
    _syncLabel();
  }

  /// Current text displayed in the bubble.
  String get text => _text;

  void _syncLabel() {
    final label = _label;
    if (_text.isEmpty) {
      label?.removeFromParent();
      _label = null;
    } else if (label == null) {
      _label = _buildLabel(_text);
      add(_label!);
    } else {
      label.text = _text;
    }
  }

  /// Triggers audio effects and haptic vibration for correct or incorrect impacts.
  void playEffect() {
    if (isTarget) {
      final effects = soundEffects;
      if (effects != null) unawaited(effects.play(Sfx.beamCorrect));
    } else {
      unawaited(
        hapticsService?.vibrate(duration: _wrongImpactVibrationDurationMs) ??
            Future<void>.value(),
      );
      final effects = soundEffects;
      if (effects != null) {
        unawaited(effects.play(Sfx.burst));
        unawaited(effects.play(Sfx.redForming));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Burst and Popping
  // ---------------------------------------------------------------------------

  /// Initiates bubble bursting sequence, particle spray, and callbacks.
  void pop() {
    if (_isPopping || _isHidden) return;

    final targetWasHit = isTarget;
    _returnsAfterPop = !targetWasHit;

    if (!_hasReportedPop) {
      _hasReportedPop = true;
      onPopped?.call(_text, targetWasHit);
    }

    if (targetWasHit) {
      // Freeze the game and countdown immediately upon victory hit
      onTargetImpact?.call(position.clone());
    } else {
      // Penalize time on incorrect answer
      onWrongImpact?.call();
    }

    playEffect();
    _isPopping = true;
    _popProgress = 0;
    _label?.removeFromParent();
    _label = null;

    final rx = size.x / 2;
    final ry = size.y / 2;
    final center = Offset(rx, ry);

    var nx = _heatEffect.hitNormal.dx;
    var ny = _heatEffect.hitNormal.dy;
    final len = math.sqrt(nx * nx + ny * ny);
    if (len > 0.98) {
      nx = nx / len * 0.98;
      ny = ny / len * 0.98;
    }
    _popOrigin = Offset(center.dx + nx * rx, center.dy + ny * ry);
    _popMaxHole = (rx > ry ? rx : ry) * 2.1;

    final dropColor = _isRed ? const Color(0xFFFF3B3B) : config.style.baseColor;
    _particles.clear();
    _particles.addAll(
      _popRenderer.createParticles(
        bubbleSize: Size(size.x, size.y),
        popOrigin: _popOrigin,
        popMaxHole: _popMaxHole,
        dropColor: dropColor,
        random: _random,
      ),
    );
  }

  void _finishPop() {
    if (!_returnsAfterPop) {
      removeFromParent();
      return;
    }
    _isPopping = false;
    _popProgress = 0;
    _particles.clear();
    _isHidden = true;
    _opacity = 0;
    _heatEffect.reset();
    _hiddenTimer = _returnDelay;
  }

  void _comeBack() {
    _isHidden = false;
    _isRed = true;
    _renderer = BubbleRenderer(
      config.style
          .tinted(_redColor)
          .copyWith(
            bodyCenterAlpha: 0.8,
            bodyMidAlpha: 0.3,
            bodyEdgeAlpha: 0.7,
          ),
    );
    _opacity = 1;
    _syncLabel();
  }

  // ---------------------------------------------------------------------------
  // Laser Interactions (LaserTarget Implementation)
  // ---------------------------------------------------------------------------

  @override
  bool get canReceiveLaserHit =>
      !isBurstBubble && !_isPopping && !_isHidden && _opacity >= 0.8;

  @override
  bool containsLaserPoint(Vector2 point) {
    if (isBurstBubble) return false;
    final center = absoluteCenter;
    final dx = (point.x - center.x) / _halfW;
    final dy = (point.y - center.y) / _halfH;
    return dx * dx + dy * dy <= 1;
  }

  @override
  void onLaserHit(Vector2 point, double dt) {
    if (isBurstBubble) return;
    if (_isPopping || _isHidden) return;

    final center = absoluteCenter;
    final hitNormal = Offset(
      (point.x - center.x) / (size.x / 2),
      (point.y - center.y) / (size.y / 2),
    );
    _heatEffect.registerHit(hitNormal);

    pop();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> onLoad() async {
    _renderer = BubbleRenderer(config.style);
    _dir = config.directionVector;
    _perp = Vector2(-_dir.y, _dir.x);
    _centerBase = position.clone();
    _t = _random.nextDouble() * 2 * pi;

    _text = config.text;
    if (_text.isNotEmpty) {
      _label = _buildLabel(_text);
      await add(_label!);
    }

    await add(_BubbleGloss());
  }

  BubbleLabel _buildLabel(String value) {
    return BubbleLabel(
      text: value,
      box: config.style.size,
      textCenter: Offset(size.x / 2, size.y / 2),
      maxLines: config.maxLines,
      autoFit: config.autoFit,
      deform: paintDeformed,
      style: _labelStyle,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    final host = game is KnowledgeBubbleHost
        ? game as KnowledgeBubbleHost
        : null;
    if (host?.isFrozen == true && !isBurstBubble && !_isPopping) {
      return;
    }

    // 1. Active bursting animation
    if (_isPopping) {
      _popProgress += dt / BubblePopRenderer.popDuration;
      if (_popProgress >= 1.0) _finishPop();
      return;
    }

    // 2. Hidden countdown waiting for red respawn
    if (_isHidden) {
      _hiddenTimer -= dt;
      if (_hiddenTimer <= 0) _comeBack();
      return;
    }

    // 3. Regular motion and oscillation
    _t += dt;
    _drift(dt);
    keepWithinBounds();

    _rendererAcc += dt;
    if (_rendererAcc >= 1 / 30) {
      _renderer.update(_rendererAcc);
      _rendererAcc = 0;
    }
    _breathe();

    _heatEffect.update(dt);

    _redness = _isRed
        ? math.min(1.0, _redness + dt * 6.0)
        : math.max(0.0, _redness - dt * 1.5);

    if (isBurstBubble && _isOffScreen()) {
      removeFromParent();
    }
  }

  void _drift(double dt) {
    var speedMultiplier = 1.0;
    final host = game is KnowledgeBubbleHost
        ? game as KnowledgeBubbleHost
        : null;
    if (isBurstBubble && host?.isFrozen == true) {
      final elapsed = host!.elapsedFreezeTime;
      if (elapsed < 0.78) {
        speedMultiplier = 2.0;
      } else if (elapsed < 2) {
        speedMultiplier = 0.5;
      } else {
        speedMultiplier = 2.0;
      }
    }
    _centerBase.add(_dir * (config.speed * dt * speedMultiplier));
    final wave =
        _perp * (sin(_t * config.waveFrequency) * config.waveAmplitude);
    position.setFrom(_centerBase + wave);
  }

  void _breathe() {
    _squash = config.breathAmplitude * sin(_t * config.breathSpeed);
  }

  /// Restricts regular bubbles inside the screen and celebration bubbles above the laser line.
  void keepWithinBounds() {
    if (!isBurstBubble) {
      _bounceWithinBounds();
      return;
    }

    keepAboveRespawnLine();
  }

  /// Keeps celebration bubbles above the laser respawn line.
  void keepAboveRespawnLine() {
    final host = game is KnowledgeBubbleHost
        ? game as KnowledgeBubbleHost
        : null;
    final lineY = host?.bubbleRespawnY ?? game.size.y;
    final maxCenterY = lineY - _halfH;
    final overflow = position.y - maxCenterY;
    if (overflow <= 0) return;

    position.y -= overflow;
    _centerBase.y -= overflow;
    if (_dir.y > 0) {
      _dir.y = -_dir.y;
      _perp.setValues(-_dir.y, _dir.x);
    }
  }

  void _bounceWithinBounds() {
    final host = game is KnowledgeBubbleHost
        ? game as KnowledgeBubbleHost
        : null;
    final minX = game.size.x >= size.x ? _halfW : game.size.x / 2;
    final maxX = game.size.x >= size.x ? game.size.x - _halfW : minX;
    final bottomBoundary = host?.bubbleRespawnY ?? game.size.y;
    final fitsVertically = bottomBoundary >= size.y;
    final minY = fitsVertically ? _halfH : bottomBoundary / 2;
    final maxY = fitsVertically ? bottomBoundary - _halfH : minY;
    var directionChanged = false;

    if (position.x < minX) {
      _centerBase.x += minX - position.x;
      position.x = minX;
      if (_dir.x < 0) {
        _dir.x = -_dir.x;
        directionChanged = true;
      }
    } else if (position.x > maxX) {
      _centerBase.x += maxX - position.x;
      position.x = maxX;
      if (_dir.x > 0) {
        _dir.x = -_dir.x;
        directionChanged = true;
      }
    }

    if (position.y < minY) {
      _centerBase.y += minY - position.y;
      position.y = minY;
      if (_dir.y < 0) {
        _dir.y = -_dir.y;
        directionChanged = true;
      }
    } else if (position.y > maxY) {
      _centerBase.y += maxY - position.y;
      position.y = maxY;
      if (_dir.y > 0) {
        _dir.y = -_dir.y;
        directionChanged = true;
      }
    }

    if (directionChanged) {
      _perp.setValues(-_dir.y, _dir.x);
    }
  }

  bool _isOffScreen() {
    if (_dir.x > 0 && position.x - _halfW > game.size.x) return true;
    if (_dir.x < 0 && position.x + _halfW < 0) return true;
    if (_dir.y > 0 && position.y - _halfH > game.size.y) return true;
    if (_dir.y < 0 && position.y - (_halfH / 2) < 0) return true;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Rendering and Visual Deformation
  // ---------------------------------------------------------------------------

  void _applyDeform(Canvas canvas, void Function(Canvas) draw) {
    final inflation = _heatEffect.inflationScale;
    canvas
      ..save()
      ..translate(_halfW, _halfH)
      ..scale((1 + _squash) * inflation, (1 - _squash) * inflation)
      ..translate(-_halfW, -_halfH);
    draw(canvas);
    canvas.restore();
  }

  /// Applies deformation and opacity layer for child components such as BubbleLabel and BubbleGloss.
  void paintDeformed(Canvas canvas, void Function(Canvas) draw) {
    final fading = _opacity < 0.999;
    if (fading) {
      _fadePaint.color = Colors.white.withValues(alpha: _opacity);
      canvas.saveLayer(_layerBounds, _fadePaint);
    }
    _applyDeform(canvas, draw);
    if (fading) canvas.restore();
  }

  /// Draws content and clears the expanding hole area.
  void paintPopped(Canvas canvas, void Function(Canvas) draw) {
    canvas.saveLayer(_layerBounds, _plainPaint);
    _applyDeform(canvas, draw);
    canvas.drawCircle(_popOrigin, _holeRadius, _clearPaint);
    canvas.restore();
  }

  void _paintBody(Canvas canvas, {bool hole = false}) {
    const tinted = false;
    final fading = _opacity < 0.999;
    final layered = tinted || fading || hole;

    if (layered) {
      if (tinted || fading) {
        if (_redness != _lastTintRed || _opacity != _lastTintOpacity) {
          final k = 0.85 * _redness;
          final i = 1 - k;
          _tintMatrix
            ..[0] = i
            ..[6] = i
            ..[12] = i
            ..[4] = 255 * k
            ..[9] = 30 * k
            ..[14] = 30 * k
            ..[18] = _opacity;
          _layerPaint.colorFilter = ColorFilter.matrix(_tintMatrix);
          _lastTintRed = _redness;
          _lastTintOpacity = _opacity;
        }
      } else {
        _layerPaint.colorFilter = null;
        _lastTintRed = -1;
      }
      canvas.saveLayer(_layerBounds, _layerPaint);
    }

    _applyDeform(canvas, _renderer.paintBody);
    if (hole) canvas.drawCircle(_popOrigin, _holeRadius, _clearPaint);

    if (layered) canvas.restore();
  }

  bool _isVisibleOnScreen() {
    final mx = _halfW * 1.5;
    final my = _halfH * 1.5;
    return position.x + mx > 0 &&
        position.x - mx < game.size.x &&
        position.y + my > 0 &&
        position.y - my < game.size.y;
  }

  @override
  void render(Canvas canvas) {
    if (_isHidden || !_isVisibleOnScreen()) return;
    if (_isPopping) {
      _popRenderer.renderPop(
        canvas: canvas,
        bubbleSize: Size(size.x, size.y),
        popProgress: _popProgress,
        popOrigin: _popOrigin,
        holeRadius: _holeRadius,
        ovalPath: _ovalPath,
        baseColor: config.style.baseColor,
        isRed: _isRed,
        particles: _particles,
        paintBody: (c, {required bool hole}) => _paintBody(c, hole: hole),
      );
      return;
    }

    _paintBody(canvas);

    _heatEffect.render(
      canvas: canvas,
      bubbleSize: Size(size.x, size.y),
      ovalPath: _ovalPath,
    );
  }
}

/// Upper specular gloss layer drawn over the bubble text.
class _BubbleGloss extends PositionComponent with ParentIsA<Bubble> {
  _BubbleGloss() : super(priority: 10);

  @override
  void render(Canvas canvas) {
    if (parent._isHidden || !parent._isVisibleOnScreen()) return;
    if (parent._isPopping) return;
    parent.paintDeformed(canvas, parent._renderer.paintGloss);
  }
}
