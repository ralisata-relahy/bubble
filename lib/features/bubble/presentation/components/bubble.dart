// ignore_for_file: implementation_imports, unused_field

import 'dart:math';
import 'dart:math' as math;
import 'dart:ui';

import 'package:bubble/audio_generation/sound_effect.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show Canvas, FontWeight, Colors, RadialGradient;
import 'package:flutter/src/painting/text_style.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';

import 'package:bubble/core/contracts/knowledge_bubble_host.dart';
import 'package:bubble/core/contracts/laser_target.dart';
import 'package:bubble/core/physics/bubble_collision_resolver.dart';
import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_renderer.dart';

import 'bubble_label.dart';

/// Composant principal representant une bulle flottante dans le moteur de jeu Flame.
/// Coordonne la cinematique ondulatoire, la resolution elastique des collisions,
/// les effets de chauffe et d'explosion laser, ainsi que le rendu graphique.
class Bubble extends PositionComponent
    with HasGameReference<FlameGame>
    implements LaserTarget, BubblePhysicsBody {
  /// Cree une bulle a la position et avec la configuration specifiees.
  Bubble({
    required Vector2 position,
    this.config = const BubbleConfig(),
    this.textColor = Colors.white,
    this.canPop = _defaultCanPop,
    this.isBurstBubble = false,
    this.onTargetImpact,
    this.onWrongImpact,
    Random? random,
  }) : _random = random ?? Random(),
       super(
         position: position,
         size: Vector2(config.style.size.width, config.style.size.height),
         anchor: Anchor.center,
       );

  /// Couleur du texte contenu dans la bulle.
  final Color textColor;

  /// Parametres de style, forme et trajectoire.
  final BubbleConfig config;

  /// Predicat verifiant si le texte de la bulle correspond a la reponse attendue.
  final bool Function(String text) canPop;

  /// Marqueur indiquant si la bulle est issue d'une explosion de savoir.
  final bool isBurstBubble;

  /// Callback declenche lors de l'impact victorieux d'un laser sur la bulle cible.
  final void Function(Vector2 pos)? onTargetImpact;

  /// Callback declenche lorsque le laser touche une bulle qui n'est pas la bonne reponse.
  final void Function()? onWrongImpact;

  /// Predicat par defaut validant les reponses vraies.
  static bool _defaultCanPop(String t) {
    final s = t.trim().toLowerCase();
    return s == 'vrai' || s == 'vraie';
  }

  /// Generateur aleatoire utilise pour la dispersion des particules et la phase.
  final Random _random;

  /// Indique si la bulle est la reponse correcte attendue par la manche.
  bool get isTarget => canPop(_text);

  // ── Proprietes de mouvement et cinematique ──
  late String _text = config.text;
  BubbleLabel? _label;
  late BubbleRenderer _renderer;
  late Vector2 _dir;
  late Vector2 _perp;
  late final Vector2 _centerBase;
  late double _t;
  double _squash = 0;
  double _rendererAcc = 0;

  // ── Implementation du contrat BubblePhysicsBody ──
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

  /// Resout la collision elastique entre deux bulles grace au module physique partage.
  void checkAndResolveCollision(dynamic other, {double padding = 6.0}) {
    if (other is BubblePhysicsBody) {
      BubbleCollisionResolver.resolve(this, other, padding: padding);
    }
  }

  // ── Etat rouge (reponse incorrecte) ──
  double _redness = 0;
  bool _isRed = false;
  static const Color _redColor = Color(0xFFFF1E1E);

  /// Demi-largeur de la bulle.
  double get _halfW => size.x / 2;

  /// Demi-hauteur de la bulle.
  double get _halfH => size.y / 2;

  // ── Etat d'impact laser ──
  Offset _hitNormal = Offset.zero;
  double _heatIntensity = 0;
  double _hitTimeToLive = 0;
  double _inflationScale = 1.0;

  // ── Etat d'animation d'explosion ──
  bool _isPopping = false;
  double _popProgress = 0.0;
  static const double _popDuration = 0.3;
  static const double _holeDuration = 0.1;
  static const double _holeFrac = _holeDuration / _popDuration;

  /// Delai d'attente avant la reapparition d'une mauvaise bulle en rouge.
  static const double _returnDelay = 0.5;
  bool _returnsAfterPop = false;

  // ── Etat de masquage temporaire ──
  bool _isHidden = false;
  double _hiddenTimer = 0;
  double _opacity = 1.0;

  Offset _popOrigin = Offset.zero;
  double _popMaxHole = 1.0;
  final List<_PopParticle> _particles = [];

  /// Calcule le rayon actuel du trou d'eclatement.
  double get _holeRadius =>
      _popMaxHole * (_popProgress / _holeFrac).clamp(0.0, 1.0);

  // ── Objets de dessin reutilises (zero allocation par trame) ──
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
  final Paint _dropPaint = Paint();
  final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _haloPaint = Paint()
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  static const MaskFilter _bigDropBlur = MaskFilter.blur(BlurStyle.normal, 1.0);

  // ── Effet de chauffe thermique ──
  final Paint _heatGlowPaint = Paint()
    ..blendMode = BlendMode.plus
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  late final Shader _heatShader = const RadialGradient(
    colors: [Colors.white, Color(0xB3FF2A2A), Color(0x00FF2A2A)],
    stops: [0, 0.4, 1],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

  late final Paint _heatCorePaint = Paint()
    ..blendMode = BlendMode.plus
    ..shader = _heatShader;
  final List<double> _tintMatrix = List<double>.filled(20, 0);
  double _lastTintRed = -1;
  double _lastTintOpacity = -1;

  // ── Style typographique du label ──
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

  // ── Prise en charge de la vibration haptique ──
  static bool _canVibrate = false;
  static bool _vibrationChecked = false;

  /// Verifie une seule fois la disponibilite du vibreur.
  static Future<void> _checkVibration() async {
    if (_vibrationChecked) return;
    _vibrationChecked = true;
    _canVibrate = await Vibration.hasVibrator();
  }

  /// Met a jour le texte affiche.
  set text(String value) {
    _text = value;
    if (_isPopping || _isHidden) return;
    _syncLabel();
  }

  /// Texte affiche actuellement.
  String get text => _text;

  /// Synchronise l'entite enfant BubbleLabel avec le texte courant.
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

  /// Declenche l'effet sonore approprie et une vibration en cas d'erreur.
  void playEffect() {
    if (isTarget) {
      SoundEffects.play(Sfx.beamCorrect);
    } else {
      if (_canVibrate) Vibration.vibrate(duration: 50);
      SoundEffects.play(Sfx.burst);
      SoundEffects.play(Sfx.redForming);
    }
  }

  // ───────────────────────── Explosion ─────────────────────────

  /// Declenche la sequence d'explosion et prepare les gouttelettes.
  void pop() {
    if (_isPopping || _isHidden) return;

    final targetWasHit = isTarget;
    _returnsAfterPop = !targetWasHit;

    if (targetWasHit) {
      // Fige immediatement le jeu et le timer des le premier contact victorieux
      onTargetImpact?.call(position.clone());
    } else {
      // Penalise le joueur pour une mauvaise reponse
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

    var nx = _hitNormal.dx, ny = _hitNormal.dy;
    final len = math.sqrt(nx * nx + ny * ny);
    if (len > 0.98) {
      nx = nx / len * 0.98;
      ny = ny / len * 0.98;
    }
    _popOrigin = Offset(center.dx + nx * rx, center.dy + ny * ry);
    _popMaxHole = (rx > ry ? rx : ry) * 2.1;

    final dropColor = _isRed ? const Color(0xFFFF3B3B) : config.style.baseColor;

    _particles.clear();
    final count = 22 + _random.nextInt(7);
    for (var i = 0; i < count; i++) {
      final a = _random.nextDouble() * 2 * pi;
      final start = center + Offset(cos(a) * rx, sin(a) * ry);
      final dist = (start - _popOrigin).distance;
      final big = _random.nextDouble() < 0.14;

      final out = Offset(cos(a), sin(a));
      final jitter = (_random.nextDouble() - 0.5) * 0.9;
      final dir = Offset(
        out.dx * cos(jitter) - out.dy * sin(jitter),
        out.dx * sin(jitter) + out.dy * cos(jitter),
      );

      _particles.add(
        _PopParticle(
          start: start,
          dir: dir,
          speed: big
              ? 0.25 + _random.nextDouble() * 0.35
              : 0.5 + _random.nextDouble() * 1.1,
          radius: big
              ? 0.022 + _random.nextDouble() * 0.018
              : 0.008 + _random.nextDouble() * 0.010,
          delay: (dist / _popMaxHole).clamp(0.0, 1.0) * _holeDuration,
          life: big
              ? 0.45 + _random.nextDouble() * 0.15
              : 0.22 + _random.nextDouble() * 0.25,
          drag: big ? 2.5 : 4.0 + _random.nextDouble() * 2.0,
          color: _random.nextDouble() < 0.55 ? Colors.white : dropColor,
          big: big,
        ),
      );
    }
  }

  /// Finalise l'explosion : suppression si cible victorieuse, ou preparation au retour si erreur.
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
    _heatIntensity = 0;
    _hitTimeToLive = 0;
    _inflationScale = 1.0;
    _hiddenTimer = _returnDelay;
  }

  /// Reinitialise la bulle apres l'echec en l'affichant en rouge opaque.
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

  // ───────────────────────── Interactions Laser ─────────────────────────

  /// Verifie si la bulle est apte a recevoir un tir laser.
  @override
  bool get canReceiveLaserHit =>
      !isBurstBubble && !_isPopping && !_isHidden && _opacity >= 0.8;

  /// Determine si un point se situe geometriquement dans l'ellipse de la bulle.
  @override
  bool containsLaserPoint(Vector2 point) {
    if (isBurstBubble) return false;
    final center = absoluteCenter;
    final dx = (point.x - center.x) / _halfW;
    final dy = (point.y - center.y) / _halfH;
    return dx * dx + dy * dy <= 1;
  }

  /// Enregistre l'impact thermique du faisceau laser et declenche l'explosion.
  @override
  void onLaserHit(Vector2 point, double dt) {
    if (isBurstBubble) return;
    if (_isPopping || _isHidden) return;

    final center = absoluteCenter;
    _hitNormal = Offset(
      (point.x - center.x) / (size.x / 2),
      (point.y - center.y) / (size.y / 2),
    );

    pop();
  }

  // ───────────────────────── Cycle de vie ─────────────────────────

  /// Initialise les composants graphiques et la trajectoire lors du chargement.
  @override
  Future<void> onLoad() async {
    _checkVibration();
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

  /// Fabrique le BubbleLabel adapte a la geometrie et au style de la bulle.
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

  /// Met a jour la cinematique, l'explosion, la dissipation thermique et le respawn.
  @override
  void update(double dt) {
    super.update(dt);

    final host = game is KnowledgeBubbleHost
        ? game as KnowledgeBubbleHost
        : null;
    if (host?.isFrozen == true && !isBurstBubble && !_isPopping) {
      return;
    }

    // 1) Animation d'explosion active.
    if (_isPopping) {
      _popProgress += dt / _popDuration;
      if (_popProgress >= 1.0) _finishPop();
      return;
    }

    // 2) Etat invisible temporaire en attente de retour.
    if (_isHidden) {
      _hiddenTimer -= dt;
      if (_hiddenTimer <= 0) _comeBack();
      return;
    }

    // 3) Deplacement regulier.
    _t += dt;
    _drift(dt);
    keepWithinBounds();

    _rendererAcc += dt;
    if (_rendererAcc >= 1 / 30) {
      _renderer.update(_rendererAcc);
      _rendererAcc = 0;
    }
    _breathe();

    // Dissipation thermique apres un contact laser.
    if (_hitTimeToLive > 0) {
      _hitTimeToLive -= dt;
    } else {
      _heatIntensity = math.max(0.0, _heatIntensity - dt * 2);
      _inflationScale = math.max(1.0, 1.0 + _heatIntensity * 0.45);
    }

    _redness = _isRed
        ? math.min(1.0, _redness + dt * 6.0)
        : math.max(0.0, _redness - dt * 1.5);

    // Les bulles d'eclatement disparaissent hors ecran; les bulles simples rebondissent.
    if (isBurstBubble && _isOffScreen()) {
      removeFromParent();
    }
  }

  /// Calcule la derive principale et l'oscillation transversale douce.
  void _drift(double dt) {
    double speedMultiplier = 1.0;
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

  /// Animation de respiration sinusoidale de la bulle.
  void _breathe() {
    _squash = config.breathAmplitude * sin(_t * config.breathSpeed);
  }

  /// Garde les bulles simples dans l'ecran et les bulles d'eclatement au-dessus du laser.
  void keepWithinBounds() {
    if (!isBurstBubble) {
      _bounceWithinBounds();
      return;
    }

    keepAboveRespawnLine();
  }

  /// Maintient la bulle au-dessus de la ligne du laser avec rebond vers le haut.
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

  /// Verifie si la bulle est entierement sortie de la zone d'affichage.
  bool _isOffScreen() {
    if (_dir.x > 0 && position.x - _halfW > game.size.x) return true;
    if (_dir.x < 0 && position.x + _halfW < 0) return true;
    if (_dir.y > 0 && position.y - _halfH > game.size.y) return true;
    if (_dir.y < 0 && position.y - (_halfH / 2) < 0) return true;
    return false;
  }

  // ───────────────────────── Rendu Graphique ─────────────────────────

  /// Applique la deformation d'echelle (respiration + gonflement thermique).
  void _applyDeform(Canvas canvas, void Function(Canvas) draw) {
    canvas
      ..save()
      ..translate(_halfW, _halfH)
      ..scale((1 + _squash) * _inflationScale, (1 - _squash) * _inflationScale)
      ..translate(-_halfW, -_halfH);
    draw(canvas);
    canvas.restore();
  }

  /// Applique la deformation et la transparence pour le label et le gloss.
  void paintDeformed(Canvas canvas, void Function(Canvas) draw) {
    final fading = _opacity < 0.999;
    if (fading) {
      _fadePaint.color = Colors.white.withValues(alpha: _opacity);
      canvas.saveLayer(_layerBounds, _fadePaint);
    }
    _applyDeform(canvas, draw);
    if (fading) canvas.restore();
  }

  /// Dessine le contenu puis soustrait le trou circulaire d'explosion.
  void paintPopped(Canvas canvas, void Function(Canvas) draw) {
    canvas.saveLayer(_layerBounds, _plainPaint);
    _applyDeform(canvas, draw);
    canvas.drawCircle(_popOrigin, _holeRadius, _clearPaint);
    canvas.restore();
  }

  /// Rendu du corps translucide de la bulle avec gestion de teinte et du trou.
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

  /// Rendu de la phase d'explosion (film retractile et projection de gouttelettes).
  void _renderPop(Canvas canvas) {
    final p = _popProgress.clamp(0.0, 1.0);
    final shortSide = math.min(size.x, size.y);
    final tHole = (p / _holeFrac).clamp(0.0, 1.0);

    // 1. Film d'eclatement.
    if (tHole < 1.0) {
      _paintBody(canvas, hole: true);

      if (_holeRadius > 0) {
        final a = 1 - tHole * tHole;
        canvas.save();
        canvas.clipPath(_ovalPath);
        _rimPaint
          ..strokeWidth = shortSide * 0.03 * (1 - 0.5 * tHole)
          ..color = Colors.white.withValues(alpha: 0.6 * a);
        canvas.drawCircle(_popOrigin, _holeRadius, _rimPaint);
        _haloPaint
          ..strokeWidth = shortSide * 0.02
          ..color = (_isRed ? _redColor : config.style.baseColor).withValues(
            alpha: 0.35 * a,
          );
        canvas.drawCircle(
          _popOrigin,
          _holeRadius + shortSide * 0.02,
          _haloPaint,
        );
        canvas.restore();
      }
    }

    // 2. Gouttelettes projetees.
    final tNow = p * _popDuration;
    final g = 1.4 * shortSide;
    for (final d in _particles) {
      final tau = tNow - d.delay;
      if (tau < 0 || tau > d.life) continue;

      final k = tau / d.life;
      final fade = (1 - k) * math.sqrt(1 - k);
      final disp = d.speed * shortSide * (1 - math.exp(-d.drag * tau)) / d.drag;
      final pos = d.start + d.dir * disp + Offset(0, 0.5 * g * tau * tau);
      final r = shortSide * d.radius * (1 - 0.5 * k);
      if (r <= 0) continue;

      _dropPaint
        ..maskFilter = d.big ? _bigDropBlur : null
        ..color = d.color.withValues(alpha: (d.big ? 0.55 : 0.45) * fade);
      canvas.drawCircle(pos, r, _dropPaint);

      if (d.big) {
        _dropPaint
          ..maskFilter = null
          ..color = Colors.white.withValues(alpha: 0.8 * fade);
        canvas.drawCircle(
          pos + Offset(-r * 0.3, -r * 0.3),
          r * 0.3,
          _dropPaint,
        );
      }
    }
  }

  /// Verifie la visibilite sur l'ecran pour eviter les operations de rendu inutiles.
  bool _isVisibleOnScreen() {
    final mx = _halfW * 1.5;
    final my = _halfH * 1.5;
    return position.x + mx > 0 &&
        position.x - mx < game.size.x &&
        position.y + my > 0 &&
        position.y - my < game.size.y;
  }

  /// Dessine la bulle dans son etat courant.
  @override
  void render(Canvas canvas) {
    if (_isHidden || !_isVisibleOnScreen()) return;
    if (_isPopping) {
      _renderPop(canvas);
      return;
    }

    _paintBody(canvas);

    // Dessine l'effet de surchauffe lors d'un effleurement laser.
    if (_heatIntensity > 0.01) {
      canvas.save();
      canvas.clipPath(_ovalPath);

      final impactPoint = Offset(
        (_hitNormal.dx + 1) * size.x / 2,
        (_hitNormal.dy + 1) * size.y / 2,
      );
      final radius = math.min(size.x, size.y) * (0.3 + 0.2 * _heatIntensity);

      _heatGlowPaint.color = const Color(0xFFFF2A2A)
          .withValues(alpha: 0.7 * _heatIntensity);
      canvas.drawCircle(impactPoint, radius * 1.2, _heatGlowPaint);

      _heatCorePaint.color = Colors.white.withValues(alpha: _heatIntensity);
      canvas
        ..save()
        ..translate(impactPoint.dx, impactPoint.dy)
        ..scale(radius)
        ..drawCircle(Offset.zero, 1, _heatCorePaint)
        ..restore();

      canvas.restore();
    }
  }
}

/// Couche de reflet brillant superieure rendue apres le texte.
class _BubbleGloss extends PositionComponent with ParentIsA<Bubble> {
  _BubbleGloss() : super(priority: 10);

  @override
  void render(Canvas canvas) {
    if (parent._isHidden || !parent._isVisibleOnScreen()) return;
    if (parent._isPopping) return;
    parent.paintDeformed(canvas, parent._renderer.paintGloss);
  }
}

/// Description d'une particule generee lors de la rupture de la bulle.
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

