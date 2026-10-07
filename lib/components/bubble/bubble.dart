import 'dart:math';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Canvas, FontWeight, Colors, RadialGradient;
import 'package:google_fonts/google_fonts.dart';

import '../../domain/laser_target.dart';
import '../../game/bubble_game.dart';
import 'bubble_config.dart';
import 'bubble_label.dart';
import 'bubble_style.dart';
import 'render/bubble_renderer.dart';

class Bubble extends PositionComponent with HasGameReference<BubbleGame> implements LaserTarget {
  Bubble({
    required Vector2 position,
    this.config = const BubbleConfig(),
    this.textColor = Colors.white,
    this.canPop=_defaultCanPop,
    Random? random,
  })  : _random = random ?? Random(),
        super(
          position: position,
          size: Vector2(config.style.size.width, config.style.size.height),
          anchor: Anchor.center,
        );

  final Color textColor;
  final BubbleConfig config;
  /// Règle: reçoit le texte de la bulle, renvoie true si elle est éclatable.
  final bool Function(String text) canPop;

  /// "Vrai" éclate, "Faux" réagit. Pour inverser, remplace par == 'faux'.
  static bool _defaultCanPop(String t) {
    final s = t.trim().toLowerCase();
    return s == 'vrai' || s == 'vraie';
  }

  final Random _random;
  bool get isTarget => canPop(text);
  BubbleLabel? _label;
  late final BubbleRenderer _renderer;
  late final Vector2 _dir;
  late final Vector2 _perp;
  late final Vector2 _centerBase;
  late double _t;
  double _squash = 0; // current deformation (replaces `scale`)
  double _reactCooldown = 0;
  double _redness = 0;   // 0 = couleur normale, 1 = tout roug
  bool _isRed=false;
  double _speedMul = 1.0;
  final Vector2 _flee = Vector2.zero();

  /// Half-dimensions, used for screen exits and respawning.
  double get _halfW => size.x / 2;
  double get _halfH => size.y / 2;

  Offset _hitNormal = Offset.zero; // Impact point in normalized coordinates [-1, 1]
  double _heatIntensity = 0;       // Intensity 0..1
  double _hitTimeToLive = 0;       // Time remaining before cooling down
  double _inflationScale = 1.0;    // Magnification scale when heated by laser

  bool _isPopping = false;
  double _popProgress = 0.0;
  static const double _popDuration = 0.65;  // total (trou + retombée des gouttes)
  static const double _holeDuration = 0.14; // temps pour que le trou traverse la bulle
  static const double _holeFrac = _holeDuration / _popDuration;

  bool _isHidden = false;
  double _hiddenTimer = 0;
  double _opacity = 1.0;
  static const double _hideDuration = 2.0;

  double _popStartScale = 1.0;
  Offset _popOrigin = Offset.zero; // point de rupture (coordonnées locales)
  double _popMaxHole = 1.0;
  final List<_PopParticle> _particles = [];

  double get _holeRadius =>
      _popMaxHole * (_popProgress / _holeFrac).clamp(0.0, 1.0);

  /// Triggers the pop animation before removing the bubble from the game.
  void pop() {
    if (_isPopping) return;
    _isPopping = true;
    _popProgress = 0;
    _popStartScale = _inflationScale;
    _label?.removeFromParent();
    _label = null;

    final rx = size.x / 2;
    final ry = size.y / 2;
    final center = Offset(rx, ry);

    // Point de rupture = point d'impact, ramené sur l'ellipse si besoin
    var nx = _hitNormal.dx, ny = _hitNormal.dy;
    final len = math.sqrt(nx * nx + ny * ny);
    if (len > 0.98) {
      nx = nx / len * 0.98;
      ny = ny / len * 0.98;
    }
    _popOrigin = Offset(center.dx + nx * rx, center.dy + ny * ry);
    _popMaxHole = (rx > ry ? rx : ry) * 2.1;

    // Gouttelettes: surtout du fin brouillard + quelques grosses gouttes
    final count = 55 + _random.nextInt(20);
    for (var i = 0; i < count; i++) {
      final a = _random.nextDouble() * 2 * pi;
      final start = center + Offset(cos(a) * rx, sin(a) * ry);
      final dist = (start - _popOrigin).distance;
      final big = _random.nextDouble() < 0.12;

      // Direction: vers l'extérieur + un peu de bruit tangentiel
      final out = Offset(cos(a) / 1.0, sin(a) / 1.0);
      final jitter = (_random.nextDouble() - 0.5) * 0.9;
      final dir = Offset(
        out.dx * cos(jitter) - out.dy * sin(jitter),
        out.dx * sin(jitter) + out.dy * cos(jitter),
      );

      _particles.add(_PopParticle(
        start: start,
        dir: dir,
        speed: big ? 0.25 + _random.nextDouble() * 0.35 : 0.5 + _random.nextDouble() * 1.1,
        radius: big ? 0.022 + _random.nextDouble() * 0.018 : 0.006 + _random.nextDouble() * 0.010,
        delay: (dist / _popMaxHole).clamp(0.0, 1.0) * _holeDuration,
        life: big ? 0.45 + _random.nextDouble() * 0.15 : 0.22 + _random.nextDouble() * 0.25,
        drag: big ? 2.5 : 4.0 + _random.nextDouble() * 2.0,
        color: _random.nextDouble() < 0.55 ? Colors.white : config.style.baseColor,
        big: big,
      ));
    }
  }

  /// Empty text removes the label.
  set text(String value) {
    final label = _label;
    if (value.isEmpty) {
      label?.removeFromParent();
      _label = null;
    } else if (label == null) {
      _label = _buildLabel(value);
      add(_label!);
    } else {
      label.text = value;
    }
  }

  String get text => _label?.text ?? '';

  @override
  double? rayCast(Vector2 origin, Vector2 direction) {
    if (_isPopping || _isHidden || _opacity < 0.8) return null;

    final center = absoluteCenter;
    final rx = size.x / 2;
    final ry = size.y / 2;

    // Transform ray into unit circle space
    final ox = (origin.x - center.x) / rx;
    final oy = (origin.y - center.y) / ry;
    final dx = direction.x / rx;
    final dy = direction.y / ry;

    final a = dx * dx + dy * dy;
    final b = 2 * (ox * dx + oy * dy);
    final k = ox * ox + oy * oy - 1;
    final discriminant = b * b - 4 * a * k;
    if (discriminant < 0) return null;

    final s = math.sqrt(discriminant);
    final t1 = (-b - s) / (2 * a); // Entry point
    final t2 = (-b + s) / (2 * a); // Exit point
    if (t1 >= 0) return t1;
    if (t2 >= 0) return t2; // Origin is inside the bubble
    return null;
  }

  @override
  void onLaserHit(Vector2 point, double dt) {
    if (_isPopping) return;

    final center = absoluteCenter;
    _hitNormal = Offset(
      (point.x - center.x) / (size.x / 2),
      (point.y - center.y) / (size.y / 2),
    );

    if (isTarget) {
      pop();
    } else if (_reactCooldown <= 0) {
      _isRed=true;
      _reactToWrongHit(center-point);
      _isHidden=true;
      _hiddenTimer=_hideDuration;

    }
  }

  void _reactToWrongHit(Vector2 awayFromLaser) {
    _reactCooldown = 1.0;
    _speedMul = 2.5;
    if (awayFromLaser.length2 > 0) {
      _flee.setFrom(awayFromLaser.normalized() * 260);
    }
  }
  @override
  Future<void> onLoad() async {
    _renderer = BubbleRenderer(config.style);
    _dir = config.directionVector;
    _perp = Vector2(-_dir.y, _dir.x);
    _centerBase = position.clone();
    _t = _random.nextDouble() * 2 * pi;

    if (config.text.isNotEmpty) {
      _label = _buildLabel(config.text);
      await add(_label!);
    }

    // Highlights above text (higher priority)
    await add(_BubbleGloss());
  }

  BubbleLabel _buildLabel(String value) {
    final shortSide = min(size.x, size.y);
    final isCube = config.style.shape == BubbleShape.cube;

    return BubbleLabel(
      text: value,
      box: isCube ? config.style.size * 0.7 : config.style.size,
      textCenter: Offset(size.x / 2, size.y / 2),
      maxLines: config.maxLines,
      autoFit: config.autoFit,
      deform: paintDeformed,
      style: GoogleFonts.poppins(
        color: textColor,
        fontSize: shortSide * 0.3,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black45,
            offset: Offset(0, shortSide * 0.015),
            blurRadius: shortSide * 0.03,
          ),
        ],
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isPopping) {
      _popProgress += dt / _popDuration;
      _t += dt;
      _drift(dt);
      _inflationScale = _popStartScale; // le film ne gonfle pas, il se déchire
      if (_popProgress >= 1.0) removeFromParent();
      return;
    }

    _t += dt;
    _renderer.update(dt);
    _drift(dt);
    _breathe();

    if (_hitTimeToLive > 0) {
      _hitTimeToLive -= dt;
    } else {
      _heatIntensity = math.max(0.0, _heatIntensity - dt * 2);
      _inflationScale = math.max(1.0, 1.0 + _heatIntensity * 0.45);
    }

    _reactCooldown = math.max(0, _reactCooldown - dt);
    _speedMul += (1.0 - _speedMul) * math.min(1.0, dt * 2.0);
    _flee.scale(math.max(0.0, 1 - dt * 3.0));
    if (_isRed){
      _redness=math.min(1.0, _redness+dt*6.0);
    }else{
      _redness=math.max(0.0,_redness-dt*1.5);
    }
    if (_isHidden) {
      _hiddenTimer -= dt;
      _popProgress += dt / _popDuration;
      _t += dt;
      _drift(dt);
      _inflationScale = _popStartScale; // le film ne gonfle pas, il se déchire
      if (_hiddenTimer <= 0) {
        _isHidden = false;
      }
    } else {
      _opacity = math.min(1.0, _opacity + dt * 2.0); // réapparition en ~0,5 s
    }
    if (_isOffScreen()) _respawn();
  }


  void _drift(double dt) {
    _centerBase
      ..add(_dir * (config.speed * _speedMul * dt))
      ..add(_flee * dt);
    final wave =
        _perp * (sin(_t * config.waveFrequency) * config.waveAmplitude);
    position.setFrom(_centerBase + wave);
  }

  void _breathe() {
    _squash = config.breathAmplitude * sin(_t * config.breathSpeed);
  }

  bool _isOffScreen() {
    if (_dir.x > 0 && position.x - _halfW > game.size.x) return true;
    if (_dir.x < 0 && position.x + _halfW < 0) return true;
    if (_dir.y > 0 && position.y - _halfH > game.size.y) return true;
    if (_dir.y < 0 && position.y + _halfH < 0) return true;
    return false;
  }

  void _respawn() {
    double x = position.x;
    double y = position.y;

    if (_dir.x > 0) {
      x = -_halfW;
      y = _halfH + _random.nextDouble() * (game.size.y - size.y);
    } else if (_dir.x < 0) {
      x = game.size.x + _halfW;
      y = _halfH + _random.nextDouble() * (game.size.y - size.y);
    }

    if (_dir.y > 0) {
      y = -_halfH;
      x = _halfW + _random.nextDouble() * (game.size.x - size.x);
    } else if (_dir.y < 0) {
      y = game.size.y + _halfH;
      x = _halfW + _random.nextDouble() * (game.size.x - size.x);
    }

    _centerBase.setValues(x, y);
    position.setFrom(_centerBase);
  }

  /// Applies deformation and laser magnification around the center, only on what is drawn.
  void paintDeformed(Canvas canvas, void Function(Canvas) draw) {
    final fading = _opacity < 0.999;
    if (fading) {
      canvas.saveLayer(
        Rect.fromLTWH(-size.x, -size.y, size.x * 3, size.y * 3),
        Paint()..color = Colors.white.withValues(alpha: _opacity),
      );
    }
    canvas
      ..save()
      ..translate(_halfW, _halfH)
      ..scale((1 + _squash) * _inflationScale, (1 - _squash) * _inflationScale)
      ..translate(-_halfW, -_halfH);
    draw(canvas);
    canvas.restore();
    if (fading) canvas.restore();
  }
  /// Dessine [draw] puis efface le trou de rupture (utilisé par le corps et le gloss).
  void paintPopped(Canvas canvas, void Function(Canvas) draw) {
    canvas.saveLayer(
      Rect.fromLTWH(-size.x, -size.y, size.x * 3, size.y * 3),
      Paint(),
    );
    paintDeformed(canvas, draw);
    canvas.drawCircle(
      _popOrigin,
      _holeRadius,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  void _renderPop(Canvas canvas) {
    final p = _popProgress.clamp(0.0, 1.0);
    final shortSide = math.min(size.x, size.y);
    final tHole = (p / _holeFrac).clamp(0.0, 1.0);

    // 1. Film restant, avec le trou qui s'agrandit
    paintPopped(canvas, _renderer.paintBody);

    // 2. Liseré brillant sur le bord du trou (film qui se rétracte)
    if (tHole < 1.0 && _holeRadius > 0) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, size.x, size.y)));
      final a = 1 - tHole * tHole;
      canvas.drawCircle(
        _popOrigin,
        _holeRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = shortSide * 0.03 * (1 - 0.5 * tHole)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
          ..color = Colors.white.withValues(alpha: 0.6 * a),
      );
      canvas.drawCircle(
        _popOrigin,
        _holeRadius + shortSide * 0.02,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = shortSide * 0.02
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..color = config.style.baseColor.withValues(alpha: 0.35 * a),
      );
      canvas.restore();
    }

    // 3. Gouttelettes fines: traînée (drag) + gravité, fondu progressif
    final tNow = p * _popDuration;
    final g = 1.4 * shortSide;
    for (final d in _particles) {
      final tau = tNow - d.delay;
      if (tau < 0 || tau > d.life) continue;

      final k = tau / d.life;
      final fade = math.pow(1 - k, 1.5).toDouble();
      final disp = d.speed * shortSide * (1 - math.exp(-d.drag * tau)) / d.drag;
      final pos = d.start + d.dir * disp + Offset(0, 0.5 * g * tau * tau);
      final r = shortSide * d.radius * (1 - 0.5 * k);
      if (r <= 0) continue;

      // Goutte semi-transparente (pas de blend additif: plus "matière")
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35)
          ..color = d.color.withValues(alpha: (d.big ? 0.55 : 0.45) * fade),
      );
      // Petit reflet sur les grosses gouttes
      if (d.big) {
        canvas.drawCircle(
          pos + Offset(-r * 0.3, -r * 0.3),
          r * 0.3,
          Paint()..color = Colors.white.withValues(alpha: 0.8 * fade),
        );
      }
    }
  }

  /// Bottom layer (text is drawn afterwards as a child).
  @override
  void render(Canvas canvas) {
    if (_isPopping) {
      _renderPop(canvas);
      return;
    }
    final bounds = Rect.fromLTWH(-size.x, -size.y, size.x * 3, size.y * 3);
    paintDeformed(canvas, (c) {
      if (_redness > 0.01) {
        // Teinte uniquement sur les pixels de la bulle (sphère, cube, ellipsoïde...)
        c.saveLayer(bounds, Paint());
        _renderer.paintBody(c);
        c.drawRect(
          bounds,
          Paint()
            ..blendMode = BlendMode.srcATop
            ..color = const Color(0xFFFF1E1E).withValues(alpha: 0.85 * _redness),
        );
        c.restore();
      } else {
        _renderer.paintBody(c);
      }
    });
    if (_heatIntensity > 0.01) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, size.x, size.y)));

      final impactPoint = Offset(
        (_hitNormal.dx + 1) * size.x / 2,
        (_hitNormal.dy + 1) * size.y / 2,
      );
      final radius = math.min(size.x, size.y) * (0.3 + 0.2 * _heatIntensity);

      // Intense glowing laser hit mark
      canvas.drawCircle(
        impactPoint,
        radius * 1.2,
        Paint()
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..color = const Color(0xFFFF2A2A).withValues(alpha: 0.7 * _heatIntensity),
      );

      canvas.drawCircle(
        impactPoint,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: _heatIntensity),
              const Color(0xFFFF2A2A).withValues(alpha: 0.7 * _heatIntensity),
              const Color(0x00FF2A2A),
            ],
            stops: const [0, 0.4, 1],
          ).createShader(Rect.fromCircle(center: impactPoint, radius: radius)),
      );
      canvas.restore();
    }
  }
}

/// Gloss layer: high priority child, drawn after text.
class _BubbleGloss extends PositionComponent with ParentIsA<Bubble> {
  _BubbleGloss() : super(priority: 10);

  @override
  void render(Canvas canvas) {
    if (parent._isPopping) {
      // Le gloss disparaît avec le trou, pas d'un coup
      if (parent._holeRadius < parent._popMaxHole) {
        parent.paintPopped(canvas, parent._renderer.paintGloss);
      }
      return;
    }
    parent.paintDeformed(canvas, parent._renderer.paintGloss);
  }
}

class _PopParticle {
  _PopParticle({
    required this.start,
    required this.dir,
    required this.speed,
    required this.radius,
    required this.delay,
    required this.life,
    required this.drag,
    required this.color,
    required this.big,
  });

  final Offset start;
  final Offset dir;
  final double speed;
  final double radius;
  final double delay;
  final double life;
  final double drag;
  final Color color;
  final bool big;
}