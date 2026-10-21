import 'dart:math';
import 'dart:ui' show Canvas, Offset, Size;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:bubble_component/bubble_component.dart' as bubble_texture;
import 'package:flutter/material.dart'
    show Color, Colors, Curves, FontWeight, Shadow, TextPainter, TextStyle;

import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_text_helper.dart';
import 'package:bubble/core/contracts/knowledge_bubble_host.dart';

/// Bulle secondaire (« savoir ») qui jaillit de l'éclatement d'une bulle
/// principale. Même signature que `Bubble` pour un remplacement direct.
///
/// - Texture de bulle partagée avec le composant principal
/// - Texte responsive : retour à la ligne + réduction automatique
/// - Apparition avec rebond ; vitesse pilotée par `elapsedFreezeTime`
/// - S'auto-supprime quand elle sort de l'écran
class KnowledgeBubbleComponent extends PositionComponent
    with HasGameReference<FlameGame> {
  KnowledgeBubbleComponent({
    required Vector2 position,
    required this.config,
    this.textColor = Colors.white,
    this.isBurstBubble = true,
    Random? random,
  }) : _random = random ?? Random(),
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

  // ── Rendu et texte ──
  late final double _d; // diamètre
  late final Offset _c; // centre
  late final bubble_texture.BubbleRenderer _renderer;
  late final TextPainter _tp;

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
    _renderer = bubble_texture.BubbleRenderer(
      bubble_texture.BubbleStyle(
        shape: switch (config.style.shape) {
          BubbleShape.sphere => bubble_texture.BubbleShape.sphere,
          BubbleShape.ellipsoid => bubble_texture.BubbleShape.ellipsoid,
          BubbleShape.cube => bubble_texture.BubbleShape.cube,
        },
        size: config.style.size,
        baseColor: config.style.baseColor,
      ),
    );

    // Texte responsive : zone = carré inscrit (~70 % du diamètre)
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

  @override
  void update(double dt) {
    super.update(dt);
    if (_removed) return;

    // Apparition (épanouissement)
    _age += dt;
    _appear = Curves.easeOutBack.transform(
      (_age / _appearDuration).clamp(0.0, 1.0),
    );

    _t += dt;

    // Mêmes paliers de vitesse que Bubble pendant le gel
    var speedMultiplier = 1.0;
    final host = game as KnowledgeBubbleHost;
    if (host.isFrozen) {
      final elapsed = host.elapsedFreezeTime;
      if (elapsed < 0.78) {
        speedMultiplier = 2.0;
      } else if (elapsed < 2) {
        speedMultiplier = 0.5;
      } else {
        speedMultiplier = 2.0;
      }
    }

    _centerBase.add(_dir * (config.speed * dt * speedMultiplier));
    _renderer.update(dt);
    final wave =
        _perp * (sin(_t * config.waveFrequency) * config.waveAmplitude);
    position.setFrom(_centerBase + wave);

    // Rebond sur les bords gauche et droit (zigzag)
    _checkWallBounce();

    if (_isOffScreen()) {
      _removed = true;
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
  void onRemove() {
    if (isLoaded) _tp.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    if (_appear <= 0.001) return;

    canvas
      ..save()
      ..translate(_c.dx, _c.dy)
      ..scale(_appear)
      ..translate(-_c.dx, -_c.dy);

    _renderer.paintBody(canvas);

    // Keep the text above the body and below the glass highlights.
    canvas
      ..save()
      ..translate(_c.dx, _c.dy);
    _tp.paint(canvas, Offset(-_tp.width / 2, -_tp.height / 2));
    canvas.restore();

    _renderer.paintGloss(canvas);
    canvas.restore();
  }
}
