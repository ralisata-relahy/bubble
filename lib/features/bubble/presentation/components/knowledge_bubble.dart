import 'dart:math';
import 'dart:ui'
    show
        BlurStyle,
        Canvas,
        MaskFilter,
        Offset,
        Paint,
        PaintingStyle,
        Rect,
        Size;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show
        Alignment,
        Color,
        Colors,
        Curves,
        FontWeight,
        RadialGradient,
        Shadow,
        TextPainter,
        TextStyle;

import 'package:bubble/core/contracts/knowledge_bubble_host.dart';
import 'package:bubble/core/physics/bubble_collision_resolver.dart';
import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_text_helper.dart';

/// Secondary knowledge bubble that bursts out when a target bubble is popped.
/// Shares the main bubble's collision physics with dedicated rendering.
class KnowledgeBubbleComponent extends PositionComponent
    with HasGameReference<FlameGame>
    implements BubblePhysicsBody {
  /// Creates a knowledge bubble configured for the current round.
  KnowledgeBubbleComponent({
    required Vector2 position,
    required this.config,
    this.textColor = Colors.white,
    this.isBurstBubble = true,
    Random? random,
  }) : _random = random ?? Random(),
       super(
         position: position,
         size: Vector2(
           config.style.size.width * _sizeScale,
           config.style.size.height * _sizeScale,
         ),
         anchor: Anchor.center,
       );

  /// Visual and kinematic configuration of the bubble.
  final BubbleConfig config;
  static const double _sizeScale = 0.8;

  /// Text color displayed at the center.
  final Color textColor;

  /// Flag indicating whether this bubble originates from a target pop.
  final bool isBurstBubble;

  /// Pseudo-random generator for phase and ejection variance.
  final Random _random;

  /// Duration of the appearance animation in seconds.
  static const double _appearDuration = 0.45;

  // Internal kinematic motion variables.
  late Vector2 _dir;
  late Vector2 _perp;
  late final Vector2 _centerBase;
  late double _t;
  double _age = 0;
  bool _removed = false;
  double _appear = 0;

  // Local geometry, rendering, and typography fields.
  late final double _d;
  late final Offset _c;
  late final Rect _bubbleRect;
  late final Paint _bodyPaint;
  late final Paint _shadePaint;
  late final Paint _rimGlowPaint;
  late final Paint _rimPaint;
  late final Paint _highlightGlowPaint;
  late final Paint _highlightPaint;
  late final TextPainter _tp;

  // BubblePhysicsBody contract implementation.
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
  bool get isCollisionActive => _appear >= 0.5 && !_removed;

  /// Returns true once the bubble has fully exited the game viewport.
  bool get hasLeftScreen => _removed;

  @override
  double get collisionRadius => _d / 2;

  /// Delegates collision resolution to the shared physics engine.
  void checkAndResolveCollision(dynamic other, {double padding = 6.0}) {
    if (other is BubblePhysicsBody) {
      BubbleCollisionResolver.resolve(this, other, padding: padding);
    }
  }

  /// Initialises geometry, movement vectors, and the text painter.
  @override
  Future<void> onLoad() async {
    _dir = config.directionVector.clone();
    if (_dir.length < 0.001) {
      _dir = Vector2(1, 1).normalized();
    }

    // Ensures a purely vertical trajectory so the bubble exits only through the top or bottom edge.
    final goUp = _dir.y < 0 || (_dir.y == 0 && _random.nextBool());
    final angleVariation =
        (_random.nextDouble() - 0.5) * 0.4; // Slight angular spread
    _dir = Vector2(
      sin(angleVariation),
      goUp ? -cos(angleVariation) : cos(angleVariation),
    ).normalized();

    _perp = Vector2(-_dir.y, _dir.x);
    _centerBase = position.clone();
    _t = _random.nextDouble() * 2 * pi;

    _d = min(size.x, size.y);
    _c = Offset(size.x / 2, size.y / 2);
    _bubbleRect = Rect.fromLTWH(0, 0, size.x, size.y);
    _bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.25),
        radius: 1,
        colors: [
          const Color(0xFF9B63B4),
          config.style.baseColor,
          const Color(0xFF602B80),
          const Color(0xFF471B62),
        ],
        stops: const [0, 0.55, 0.86, 1],
      ).createShader(_bubbleRect);
    _shadePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.3),
        radius: 1.1,
        colors: [Color(0x00090018), Color(0x40090018)],
        stops: [0.48, 1],
      ).createShader(_bubbleRect);
    _rimGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _d * 0.055
      ..color = const Color(0x66F5DFFF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _d * 0.018);
    _rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _d * 0.016
      ..color = const Color(0xFFF3D9FF);
    _highlightGlowPaint = Paint()
      ..color = const Color(0x77F8E8FF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _d * 0.025);
    _highlightPaint = Paint()..color = const Color(0xD9E7C7F5);

    // Initialise the TextPainter with automatic responsive layout.
    final inner = Size(size.x, size.y);
    _tp = BubbleTextHelper.createTextPainter(
      text: config.text,
      style: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.1,
        shadows: [
          Shadow(
            color: Colors.black54,
            blurRadius: _d * 0.05,
            offset: Offset(0, _d * 0.02),
          ),
        ],
      ),
      box: inner,
      maxLines: 3,
      widthFactor: 1,
      heightFactor: 1,
    );
  }

  /// Updates position, hatching animation, and screen-boundary check.
  @override
  void update(double dt) {
    super.update(dt);
    if (_removed) return;

    // Progresses the appearance scale (soft elastic effect).
    _age += dt;
    _appear = Curves.easeOutBack.transform(
      (_age / _appearDuration).clamp(0.0, 1.0),
    );

    _t += dt;

    // Speed multiplier adjustment during game freeze phases.
    var speedMultiplier = 1.0;
    final host = game as KnowledgeBubbleHost;
    if (host.isFrozen) {
      final elapsed = host.elapsedFreezeTime;
      if (elapsed < 0.78) {
        speedMultiplier = 1.2;
      } else if (elapsed < 2) {
        speedMultiplier = 0.2;
      } else {
        speedMultiplier = 1.4;
      }
    }

    if (isBurstBubble) {
      _centerBase.add(_dir * (config.speed * dt * speedMultiplier));
      final wave =
          _perp * (sin(_t * config.waveFrequency) * config.waveAmplitude);
      position.setFrom(_centerBase + wave);
    }

    // Clean removal once fully exited the game viewport (all 4 sides).
    if (_isOffScreen()) {
      _removed = true;
      removeFromParent();
    }
  }

  /// Returns true if the bubble has fully exited through any of the 4 screen edges.
  /// Knowledge bubbles do not bounce — they exit freely.
  bool _isOffScreen() {
    final r = _d / 2;
    if (position.x - r > game.size.x) return true;
    if (position.x + r < 0) return true;
    if (position.y - r > game.size.y) return true;
    if (position.y + r < 0) return true;
    return false;
  }

  /// Releases rendering resources when the component is destroyed.
  @override
  void onRemove() {
    if (isLoaded) _tp.dispose();
    super.onRemove();
  }

  /// Layered rendering: bubble body, centred text, then specular gloss.
  @override
  void render(Canvas canvas) {
    if (_appear <= 0.001) return;

    canvas
      ..save()
      ..translate(_c.dx, _c.dy)
      ..scale(_appear)
      ..translate(-_c.dx, -_c.dy);

    // Luminous purple body with soft shading for volume.
    canvas
      ..drawOval(_bubbleRect, _bodyPaint)
      ..drawOval(_bubbleRect, _shadePaint);

    // Text centred below the main gloss layer.
    canvas
      ..save()
      ..translate(_c.dx, _c.dy);
    _tp.paint(canvas, Offset(-_tp.width / 2, -_tp.height / 2));
    canvas.restore();

    _paintGloss(canvas);
    canvas.restore();
  }

  void _paintGloss(Canvas canvas) {
    canvas
      ..drawOval(_bubbleRect, _rimGlowPaint)
      ..drawOval(_bubbleRect, _rimPaint)
      ..save()
      ..translate(size.x * 0.3, size.y * 0.22)
      ..rotate(-pi / 4);
    final highlight = Rect.fromCenter(
      center: Offset.zero,
      width: _d * 0.3,
      height: _d * 0.105,
    );
    canvas
      ..drawOval(highlight, _highlightGlowPaint)
      ..drawOval(highlight, _highlightPaint)
      ..restore();
  }
}
