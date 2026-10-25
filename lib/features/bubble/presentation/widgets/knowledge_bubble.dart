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

/// Bulle secondaire de savoir qui jaillit lors de l'eclatement d'une bulle cible.
/// Partage la physique de collision de la bulle principale avec un rendu dedie.
class KnowledgeBubbleComponent extends PositionComponent
    with HasGameReference<FlameGame>
    implements BubblePhysicsBody {
  /// Cree une bulle de savoir configuree pour une manche donnee.
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

  /// Configuration esthetique et cinematique de la bulle.
  final BubbleConfig config;
  static const double _sizeScale = 0.8;

  /// Couleur du texte affiche au centre.
  final Color textColor;

  /// Marqueur indiquant si la bulle provient d'un eclatement de cible.
  final bool isBurstBubble;

  /// Generateur pseudo-aleatoire pour les variations de phase et d'ejection.
  final Random _random;

  /// Duree de la transition d'apparition en secondes.
  static const double _appearDuration = 0.45;

  // Variables internes de mouvement cinematique.
  late Vector2 _dir;
  late Vector2 _perp;
  late final Vector2 _centerBase;
  late double _t;
  double _age = 0;
  bool _removed = false;
  double _appear = 0;

  // Geometrie locale, rendu et typographie.
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

  // Implementation du contrat physique BubblePhysicsBody.
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

  /// Indique que la bulle a entierement quitte la fenetre de jeu.
  bool get hasLeftScreen => _removed;

  @override
  double get collisionRadius => _d / 2;

  /// Delegue la resolution de collision au moteur physique commun.
  void checkAndResolveCollision(dynamic other, {double padding = 6.0}) {
    if (other is BubblePhysicsBody) {
      BubbleCollisionResolver.resolve(this, other, padding: padding);
    }
  }

  /// Initialise la geometrie, les vecteurs de deplacement et le peintre de texte.
  @override
  Future<void> onLoad() async {
    _dir = config.directionVector.clone();
    if (_dir.length < 0.001) {
      _dir = Vector2(1, 1).normalized();
    }

    // Assure une trajectoire purement verticale vers le haut ou vers le bas
    // pour sortir uniquement par le haut ou le bas de l'ecran.
    final goUp = _dir.y < 0 || (_dir.y == 0 && _random.nextBool());
    final angleVariation = (_random.nextDouble() - 0.5) * 0.4; // Legere dispersion angulaire
    _dir = Vector2(sin(angleVariation), goUp ? -cos(angleVariation) : cos(angleVariation)).normalized();

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

    // Initialisation du TextPainter avec mise en page automatique responsive.
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

  /// Met a jour la position, l'animation d'eclosion et verifie les limites de l'ecran.
  @override
  void update(double dt) {
    super.update(dt);
    if (_removed) return;

    // Progression de l'echelle d'apparition (effet elastique doux).
    _age += dt;
    _appear = Curves.easeOutBack.transform(
      (_age / _appearDuration).clamp(0.0, 1.0),
    );

    _t += dt;

    // Ajustement de la vitesse pendant les phases de freeze du jeu.
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

    _centerBase.add(_dir * (config.speed * dt * speedMultiplier));
    final wave =
        _perp * (sin(_t * config.waveFrequency) * config.waveAmplitude);
    position.setFrom(_centerBase + wave);

    // Suppression propre une fois completement sortie de la fenetre de jeu (4 cotes).
    if (_isOffScreen()) {
      _removed = true;
      removeFromParent();
    }
  }

  /// Verifie si la bulle a integralement quitte l'ecran par l'un des 4 bords.
  /// Les bulles de savoir ne rebondissent pas : elles sortent librement.
  bool _isOffScreen() {
    final r = _d / 2;
    if (position.x - r > game.size.x) return true;
    if (position.x + r < 0) return true;
    if (position.y - r > game.size.y) return true;
    if (position.y + r < 0) return true;
    return false;
  }

  /// Libere les ressources graphiques lors de la destruction du composant.
  @override
  void onRemove() {
    if (isLoaded) _tp.dispose();
    super.onRemove();
  }

  /// Rendu superpose : fond de la bulle, texte centre puis reflets brillants.
  @override
  void render(Canvas canvas) {
    if (_appear <= 0.001) return;

    canvas
      ..save()
      ..translate(_c.dx, _c.dy)
      ..scale(_appear)
      ..translate(-_c.dx, -_c.dy);

    // Corps violet lumineux et ombrage doux pour donner du volume.
    canvas
      ..drawOval(_bubbleRect, _bodyPaint)
      ..drawOval(_bubbleRect, _shadePaint);

    // Texte au centre sous le reflet principal.
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
