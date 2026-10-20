import 'dart:math';
import 'dart:ui'
    show Canvas, Offset, Paint, PaintingStyle, Rect, MaskFilter, BlurStyle;

import 'package:flame/components.dart';
import 'package:flutter/material.dart'
    show
    Alignment,
    Color,
    Colors,
    Curves,
    FontWeight,
    HSLColor,
    RadialGradient,
    Shadow,
    TextAlign,
    TextDirection,
    TextPainter,
    TextSpan,
    TextStyle;

import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/game/presentation/bubble_game.dart';

/// Bulle secondaire (« savoir ») qui jaillit de l'éclatement d'une bulle
/// principale. Même signature que `Bubble` pour un remplacement direct.
///
/// - Rendu simple : dégradé, lueur, reflet, bordure (aucun renderer)
/// - Texte responsive : retour à la ligne + réduction automatique
/// - Apparition avec rebond ; vitesse pilotée par `elapsedFreezeTime`
/// - Prévient le jeu (`onKnowledgeBubbleRemoved`) quand elle sort de l'écran
class KnowledgeBubbleComponent extends PositionComponent
    with HasGameReference<BubbleGame> {
  KnowledgeBubbleComponent({
    required Vector2 position,
    required this.config,
    this.textColor = Colors.white,
    this.isBurstBubble = true,
    Random? random,
  })  : _random = random ?? Random(),
        super(
        position: position,
        size: Vector2(config.style.size.width, config.style.size.height),
        anchor: Anchor.center,
      );

  final BubbleConfig config;
  final Color textColor;
  final bool isBurstBubble;
  final Random _random;

  static const double _appearDuration = 0.45;

  // ── Mouvement ──
  late Vector2 _dir;
  late Vector2 _perp;
  late final Vector2 _centerBase;
  late double _t;
  double _age = 0;
  bool _removed = false;
  double _appear = 0; // 0 → 1 (avec rebond)

  // ── Dessin (créé une seule fois) ──
  late final double _d; // diamètre
  late final Offset _c; // centre
  late final Paint _bodyPaint;
  late final Paint _glowPaint;
  late final Paint _borderPaint;
  late final Paint _glossPaint;
  late final TextPainter _tp;
  late final double _textScale;

  Vector2 get moveDir => _dir;
  Vector2 get centerBase => _centerBase;
  Vector2 get movePerp => _perp;

  // ── Collisions (même logique que Bubble) ──
  bool get isCollisionActive => _appear >= 0.5;
  double get collisionRadius => _d / 2;

  void checkAndResolveCollision(dynamic other, {double padding = 6.0}) {
    if (!isCollisionActive || other == null) return;

    double otherRadius = 0;
    Vector2? otherPos;
    Vector2? otherDir;
    Vector2? otherCenterBase;
    Vector2? otherPerp;

    if (other is Bubble) {
      if (!other.isCollisionActive) return;
      otherRadius = other.collisionRadius;
      otherPos = other.position;
      otherDir = other.moveDir;
      otherCenterBase = other.centerBase;
      otherPerp = other.movePerp;
    } else if (other is KnowledgeBubbleComponent) {
      if (!other.isCollisionActive) return;
      otherRadius = other.collisionRadius;
      otherPos = other.position;
      otherDir = other.moveDir;
      otherCenterBase = other.centerBase;
      otherPerp = other.movePerp;
    } else {
      return;
    }

    final delta = otherPos - position;
    var distance = delta.length;
    final minDistance = collisionRadius + otherRadius + padding;
    if (distance >= minDistance) return;

    Vector2 normal;
    if (distance < 0.001) {
      final dirDiff = _dir - otherDir;
      normal = dirDiff.length > 0.001 ? dirDiff.normalized() : Vector2(1, 0);
      distance = 0.001;
    } else {
      normal = delta / distance;
    }

    final overlap = minDistance - distance;
    final separation = normal * (overlap / 2);
    position.sub(separation);
    _centerBase.sub(separation);
    otherPos.add(separation);
    otherCenterBase.add(separation);

    final va = _dir.dot(normal);
    final vb = otherDir.dot(normal);
    if (va - vb > 0) {
      _dir.add(normal * (vb - va));
      otherDir.add(normal * (va - vb));
      if (_dir.length > 0.001) _dir.normalize();
      if (otherDir.length > 0.001) otherDir.normalize();
      _perp.setValues(-_dir.y, _dir.x);
      otherPerp.setValues(-otherDir.y, otherDir.x);
    }
  }

  @override
  Future<void> onLoad() async {
    _dir = config.directionVector.clone();
    if (_dir.length < 0.001) {
      _dir = Vector2(1, 1).normalized();
    }
    // S'assure que la bulle a une composante verticale minimale pour sortir par le haut ou le bas
    if (_dir.y.abs() < 0.3) {
      _dir.y = _dir.y >= 0 ? 0.6 : -0.6;
      _dir.normalize();
    }
    _perp = Vector2(-_dir.y, _dir.x);
    _centerBase = position.clone();
    _t = _random.nextDouble() * 2 * pi;

    _d = min(size.x, size.y);
    _c = Offset(size.x / 2, size.y / 2);
    final rect = Rect.fromCircle(center: _c, radius: _d / 2);

    // Couleurs dérivées de la couleur de base
    final base = config.style.baseColor;
    final hsl = HSLColor.fromColor(base);
    final light =
    hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
    final dark =
    hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();

    // Transparence du remplissage : 0 = invisible, 1 = opaque (valeur d'origine)
    const k = 0.5;

    _bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.95,
        colors: [
          light.withValues(alpha: 0.30 * k),
          base.withValues(alpha: 0.45 * k),
          dark.withValues(alpha: 1.0 * k),   // bord plus dense = effet verre
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect);

    _glowPaint = Paint()
      ..color = base.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _d * 0.12);

    _borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, _d * 0.025)
      ..color = Colors.white.withValues(alpha: 0.75);

    _glossPaint = Paint()..color = Colors.white.withValues(alpha: 0.65);


    // Texte responsive : zone = carré inscrit (~70 % du diamètre)
    final inner = _d * 0.7;
    _tp = TextPainter(
      text: TextSpan(
        text: config.text,
        style: TextStyle(
          color: textColor,
          fontSize: _d * 0.22, // taille max, réduite si trop long
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
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: inner);

    _textScale = min(1.0, min(inner / _tp.height, inner / _tp.width));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_removed) return;

    // Apparition (épanouissement)
    _age += dt;
    _appear = Curves.easeOutBack
        .transform((_age / _appearDuration).clamp(0.0, 1.0));

    _t += dt;

    // Mêmes paliers de vitesse que Bubble pendant le gel
    var speedMultiplier = 1.0;
    if (game.isFrozen) {
      final elapsed = game.elapsedFreezeTime;
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

    // Rebond sur les bords gauche et droit (zigzag)
    _checkWallBounce();

    if (_isOffScreen()) {
      _removed = true;
      game.onKnowledgeBubbleRemoved();
      removeFromParent();
    }
  }

  void _checkWallBounce() {
    final r = _d / 2;

    // Rebond sur le bord gauche
    if (position.x - r < 0 && _dir.x < 0) {
      _dir.x = -_dir.x;
      _perp.setValues(-_dir.y, _dir.x);
      final overflow = r - position.x;
      position.x = r;
      _centerBase.x += overflow;
    }
    // Rebond sur le bord droit
    else if (position.x + r > game.size.x && _dir.x > 0) {
      _dir.x = -_dir.x;
      _perp.setValues(-_dir.y, _dir.x);
      final overflow = position.x + r - game.size.x;
      position.x = game.size.x - r;
      _centerBase.x -= overflow;
    }
  }

  bool _isOffScreen() {
    final r = _d / 2;
    // Ressort UNIQUEMENT par le haut ou par le bas
    if (_dir.y > 0 && position.y - r > game.size.y) return true;
    if (_dir.y < 0 && position.y + r < 0) return true;
    return false;
  }

  @override
  void render(Canvas canvas) {
    if (_appear <= 0.001) return;

    canvas
      ..save()
      ..translate(_c.dx, _c.dy)
      ..scale(_appear)
      ..translate(-_c.dx, -_c.dy);

    final r = _d / 2;
    canvas.drawCircle(_c, r, _glowPaint); // lueur
    canvas.drawCircle(_c, r, _bodyPaint); // corps

    // Reflet (derrière le texte pour garder une bonne lisibilité)
    canvas
      ..save()
      ..translate(_c.dx - _d * 0.2, _c.dy - _d * 0.27)
      ..rotate(-0.6)
      ..drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: _d * 0.3, height: _d * 0.14),
        _glossPaint,
      )
      ..restore();

    canvas.drawCircle(_c, r * 0.985, _borderPaint); // bordure

    // Texte centré, réduit si nécessaire
    canvas
      ..save()
      ..translate(_c.dx, _c.dy)
      ..scale(_textScale);
    _tp.paint(canvas, Offset(-_tp.width / 2, -_tp.height / 2));
    canvas.restore();

    canvas.restore();
  }
}