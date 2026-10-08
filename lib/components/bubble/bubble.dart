// ignore_for_file: implementation_imports

import 'dart:math';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart'
    show Canvas, FontWeight, Colors, RadialGradient;
import 'package:flutter/src/painting/text_style.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';

import '../../domain/laser_target.dart';
import '../../game/bubble_game.dart';
import 'bubble_config.dart';
import 'bubble_label.dart';
import 'bubble_style.dart';
import 'render/bubble_renderer.dart';

class Bubble extends PositionComponent
    with HasGameReference<BubbleGame>
    implements LaserTarget {
  /// Crée une bulle à la position et avec le style demandés.
  Bubble({
    required Vector2 position,
    this.config = const BubbleConfig(),
    this.textColor = Colors.white,
    this.canPop = _defaultCanPop,
    this.isBurstBubble = false,
    Random? random,
  }) : _random = random ?? Random(),
       super(
         position: position,
         size: Vector2(config.style.size.width, config.style.size.height),
         anchor: Anchor.center,
       );

  final Color textColor;
  final BubbleConfig config;

  /// Règle: reçoit le texte de la bulle, renvoie true si elle est "vraie"
  /// (elle explose et disparaît). Sinon elle explose puis revient en rouge.
  final bool Function(String text) canPop;
  final bool isBurstBubble;

  /// Détermine si le texte désigne une bulle qui disparaît définitivement.
  static bool _defaultCanPop(String t) {
    final s = t.trim().toLowerCase();
    return s == 'vrai' || s == 'vraie';
  }

  final Random _random;

  /// Indique si le texte actuel fait de cette bulle une cible correcte.
  bool get isTarget => canPop(_text);

  // ── Texte (conservé même quand le label est retiré pendant l'explosion) ──
  String _text = '';
  BubbleLabel? _label;
  late BubbleRenderer _renderer;
  late final Vector2 _dir;
  late final Vector2 _perp;
  late final Vector2 _centerBase;
  late double _t;
  double _squash = 0;
  double _rendererAcc = 0;

  // ── Rouge ──
  double _redness = 0; // 0 = normal, 1 = tout rouge
  bool _isRed = false;
  static const Color _redColor = Color(0xFFFF1E1E);

  /// Renvoie la moitié de la largeur de la bulle.
  double get _halfW => size.x / 2;

  /// Renvoie la moitié de la hauteur de la bulle.
  double get _halfH => size.y / 2;

  // ── Laser (chauffe) ──
  Offset _hitNormal = Offset.zero;
  double _heatIntensity = 0;
  double _hitTimeToLive = 0;
  double _inflationScale = 1.0;

  // ── Explosion ──
  bool _isPopping = false;
  double _popProgress = 0.0;
  static const double _popDuration = 0.65;
  static const double _holeDuration = 0.14;
  static const double _holeFrac = _holeDuration / _popDuration;

  /// Délai d'attente après l'explosion avant le retour d'une bulle fausse.
  static const double _returnDelay = 0.5;
  bool _returnsAfterPop = false;

  // ── Invisible en attendant de revenir ──
  bool _isHidden = false;
  double _hiddenTimer = 0;
  double _opacity = 1.0;

  Offset _popOrigin = Offset.zero;
  double _popMaxHole = 1.0;
  final List<_PopParticle> _particles = [];

  /// Calcule le rayon du trou selon l'avancement de l'explosion.
  double get _holeRadius =>
      _popMaxHole * (_popProgress / _holeFrac).clamp(0.0, 1.0);

  // ── Objets de dessin réutilisés (zéro allocation par frame) ──
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

  // ── Effet de chauffe (objets réutilisés) ──
  final Paint _heatGlowPaint = Paint()
    ..blendMode = BlendMode.plus
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  // Shader unitaire (rayon 1, centré en 0,0), créé UNE seule fois.
  // On le déplace/agrandit avec le canvas au lieu de le recréer.
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
  // ───────────────────────── Texte ─────────────────────────

  // ── Style du label (créé une seule fois) ──
  late final TextStyle _labelStyle = () {
    final shortSide = min(size.x, size.y);
    return GoogleFonts.poppins(
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
    );
  }();
  // ── Vibration: vérifiée une seule fois pour toutes les bulles ──
  static bool _canVibrate = false;
  static bool _vibrationChecked = false;

  /// Vérifie une seule fois si l'appareil prend en charge la vibration.
  static Future<void> _checkVibration() async {
    if (_vibrationChecked) return;
    _vibrationChecked = true;
    _canVibrate = await Vibration.hasVibrator();
  }

  /// Texte vide = pas de label.
  set text(String value) {
    _text = value;
    if (_isPopping || _isHidden) return; // sera reconstruit au retour
    _syncLabel();
  }

  /// Renvoie le texte affiché dans la bulle.
  String get text => _text;

  /// Crée, met à jour ou retire le label selon le texte actuel.
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

  /// Joue le son correspondant au résultat et vibre pour une réponse fausse.
  void playEffect() {
    if (isTarget) {
      FlameAudio.play('bouble_pop.mp3');
    } else {
      if (_canVibrate) Vibration.vibrate(duration: 50);
      FlameAudio.play('e-ho.mp3');
    }
  }

  // ───────────────────────── Explosion ─────────────────────────

  /// Lance l'explosion et prépare ses particules.
  void pop() {
    if (_isPopping || _isHidden) return;

    // Décidé AVANT de toucher au label
    _returnsAfterPop = !isTarget;
    if(isTarget)game.onTrueBubblePopped();
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

    if (!_returnsAfterPop) {
      final impactPosition =
          absoluteCenter + Vector2(_popOrigin.dx - rx, _popOrigin.dy - ry);
      _spawnPopBubbles(impactPosition);
    }

    // Moins de particules = beaucoup moins de travail par frame
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

  /// Crée des bulles réelles qui se dispersent depuis le point d'impact.
  void _spawnPopBubbles(Vector2 origin) {
    const count = 5;
    final style = config.style.copyWith(size: const Size(60, 60));
    final List<String> key= [
      "Hello","Mada","Inde","France","Paris"
    ];
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      game.add(
        Bubble(
          position: origin.clone(),
          textColor: textColor, 
          random: _random,
          isBurstBubble: true,
          config: BubbleConfig(
            style: style,
            text: key[i],
            speed: 70 + _random.nextDouble() * 180,
            customDirection: Vector2(cos(angle), sin(angle)),
            waveAmplitude: 0,
            maxLines: config.maxLines,
            autoFit: config.autoFit,
          ),
        ),
      );
    }
  }

  /// Fin de l'animation: vraie = supprimée, fausse = invisible en attendant de revenir.
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

  /// Fait réapparaître une bulle fausse en rouge et complètement opaque.
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

  // ───────────────────────── Laser ─────────────────────────

  /// Indique si la pointe du laser se trouve à l'intérieur de la bulle.
  bool containsLaserPoint(Vector2 point) {
    if (isBurstBubble) return false;
    final center = absoluteCenter;
    final dx = (point.x - center.x) / _halfW;
    final dy = (point.y - center.y) / _halfH;
    return dx * dx + dy * dy <= 1;
  }

  /// Renvoie la distance de la première intersection du rayon avec la bulle.
  @override
  double? rayCast(Vector2 origin, Vector2 direction) {
    if (isBurstBubble) return null;
    if (_isPopping || _isHidden || _opacity < 0.8) return null;

    final center = absoluteCenter;
    final rx = size.x / 2;
    final ry = size.y / 2;

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
    final t1 = (-b - s) / (2 * a);
    final t2 = (-b + s) / (2 * a);
    if (t1 >= 0) return t1;
    if (t2 >= 0) return t2;
    return null;
  }

  /// Enregistre l'impact du laser et déclenche l'explosion.
  @override
  void onLaserHit(Vector2 point, double dt) {
    if (isBurstBubble) return;
    if (_isPopping || _isHidden) return;

    final center = absoluteCenter;
    _hitNormal = Offset(
      (point.x - center.x) / (size.x / 2),
      (point.y - center.y) / (size.y / 2),
    );

    // Vrai ou faux: dans les deux cas ça explose.
    // La différence se fait à la fin de l'animation (_finishPop).
    pop();
  }

  // ───────────────────────── Cycle de vie ─────────────────────────

  /// Charge les sons et initialise l'affichage et le mouvement de la bulle.
  @override
  Future<void> onLoad() async {
    await FlameAudio.audioCache.loadAll(['bouble_pop.mp3', 'e-ho.mp3']);
    _checkVibration(); // pas de await: on ne bloque pas le chargement
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

  /// Construit le label en tenant compte de la forme et du style de la bulle.
  BubbleLabel _buildLabel(String value) {
    final isCube = config.style.shape == BubbleShape.cube;

    return BubbleLabel(
      text: value,
      box: isCube ? config.style.size * 0.7 : config.style.size,
      textCenter: Offset(size.x / 2, size.y / 2),
      maxLines: config.maxLines,
      autoFit: config.autoFit,
      deform: paintDeformed,
      style: _labelStyle,
    );
  }

  /// Met à jour le mouvement, l'explosion, la visibilité et les effets.
  @override
  void update(double dt) {
    super.update(dt);

    // 1) Explosion en cours
    if (_isPopping) {
      _popProgress += dt / _popDuration;
      if (_popProgress >= 1.0) _finishPop();
      return;
    }

    // 2) Invisible, en attente de revenir (bulle fausse)
    if (_isHidden) {
      _hiddenTimer -= dt;
      if (_hiddenTimer <= 0) _comeBack();
      return;
    }

    // 3) Normal
    _t += dt;
    _drift(dt);

    _rendererAcc += dt;
    if (_rendererAcc >= 1 / 30) {
      _renderer.update(_rendererAcc);
      _rendererAcc = 0;
    }
    _breathe();

    if (_hitTimeToLive > 0) {
      _hitTimeToLive -= dt;
    } else {
      _heatIntensity = math.max(0.0, _heatIntensity - dt * 2);
      _inflationScale = math.max(1.0, 1.0 + _heatIntensity * 0.45);
    }

    _redness = _isRed
        ? math.min(1.0, _redness + dt * 6.0)
        : math.max(0.0, _redness - dt * 1.5);

    if (_isOffScreen()) {
      if (isBurstBubble) {
        removeFromParent();
      } else {
        _respawn();
      }
    }
  }

  /// Fait dériver la bulle le long de sa direction avec un mouvement ondulé.
  void _drift(double dt) {
    _centerBase.add(_dir * (config.speed * dt));
    final wave =
        _perp * (sin(_t * config.waveFrequency) * config.waveAmplitude);
    position.setFrom(_centerBase + wave);
  }

  /// Calcule la déformation périodique de respiration de la bulle.
  void _breathe() {
    _squash = config.breathAmplitude * sin(_t * config.breathSpeed);
  }

  /// Indique si la bulle a entièrement quitté les limites de l'écran.
  bool _isOffScreen() {
    if (_dir.x > 0 && position.x - _halfW > game.size.x) return true;
    if (_dir.x < 0 && position.x + _halfW < 0) return true;
    if (_dir.y > 0 && position.y - _halfH > game.size.y) return true;
    if (_dir.y < 0 && position.y + _halfH < 0) return true;
    return false;
  }

  /// Replace la bulle au bord de l'écran pour son prochain passage.
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

  // ───────────────────────── Rendu ─────────────────────────

  /// Déformation (respiration + gonflement) autour du centre. Sans layer.
  void _applyDeform(Canvas canvas, void Function(Canvas) draw) {
    canvas
      ..save()
      ..translate(_halfW, _halfH)
      ..scale((1 + _squash) * _inflationScale, (1 - _squash) * _inflationScale)
      ..translate(-_halfW, -_halfH);
    draw(canvas);
    canvas.restore();
  }

  /// Utilisé par le label et le gloss: déformation + fondu (layer seulement si nécessaire).
  void paintDeformed(Canvas canvas, void Function(Canvas) draw) {
    final fading = _opacity < 0.999;
    if (fading) {
      _fadePaint.color = Colors.white.withValues(alpha: _opacity);
      canvas.saveLayer(_layerBounds, _fadePaint);
    }
    _applyDeform(canvas, draw);
    if (fading) canvas.restore();
  }

  /// Dessine [draw] puis efface le trou de rupture (utilisé par le gloss).
  void paintPopped(Canvas canvas, void Function(Canvas) draw) {
    canvas.saveLayer(_layerBounds, _plainPaint);
    _applyDeform(canvas, draw);
    canvas.drawCircle(_popOrigin, _holeRadius, _clearPaint);
    canvas.restore();
  }

  /// Corps de la bulle: UN SEUL layer pour teinte rouge + fondu + trou.
  /// Dessine le corps en appliquant la teinte, le fondu et le trou éventuels.
  void _paintBody(Canvas canvas, {bool hole = false}) {
    const tinted = false; // le rouge est maintenant dans le renderer
    final fading = _opacity < 0.999;
    final layered = tinted || fading || hole;

    if (layered) {
      if (tinted || fading) {
        // On ne reconstruit le filtre que si les valeurs ont changé.
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
        _lastTintRed = -1; // force la reconstruction au prochain besoin
      }
      canvas.saveLayer(_layerBounds, _layerPaint);
    }

    _applyDeform(canvas, _renderer.paintBody);
    if (hole) canvas.drawCircle(_popOrigin, _holeRadius, _clearPaint);

    if (layered) canvas.restore();
  }

  /// Dessine le film restant et les particules pendant l'explosion.
  void _renderPop(Canvas canvas) {
    final p = _popProgress.clamp(0.0, 1.0);
    final shortSide = math.min(size.x, size.y);
    final tHole = (p / _holeFrac).clamp(0.0, 1.0);

    // 1. Film + liseré: seulement tant que le trou n'a pas tout mangé
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

    // 2. Gouttelettes (un seul Paint réutilisé, flou seulement sur les grosses)
    final tNow = p * _popDuration;
    final g = 1.4 * shortSide;
    for (final d in _particles) {
      final tau = tNow - d.delay;
      if (tau < 0 || tau > d.life) continue;

      final k = tau / d.life;
      final fade = (1 - k) * math.sqrt(1 - k); // = (1-k)^1.5 sans pow()
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

  /// Vrai si la bulle (avec une marge pour la déformation) touche l'écran.
  bool _isVisibleOnScreen() {
    final mx = _halfW * 1.5;
    final my = _halfH * 1.5;
    return position.x + mx > 0 &&
        position.x - mx < game.size.x &&
        position.y + my > 0 &&
        position.y - my < game.size.y;
  }

  /// Dessine la bulle, ses effets de chauffe ou son animation d'explosion.
  @override
  void render(Canvas canvas) {
    if (_isHidden || !_isVisibleOnScreen()) return;
    if (_isPopping) {
      _renderPop(canvas);
      return;
    }

    _paintBody(canvas);

    if (_heatIntensity > 0.01) {
      canvas.save();
      canvas.clipPath(_ovalPath);

      final impactPoint = Offset(
        (_hitNormal.dx + 1) * size.x / 2,
        (_hitNormal.dy + 1) * size.y / 2,
      );
      final radius = math.min(size.x, size.y) * (0.3 + 0.2 * _heatIntensity);

      // Halo flou
      _heatGlowPaint.color = const Color(0xFFFF2A2A)
          .withValues(alpha: 0.7 * _heatIntensity);
      canvas.drawCircle(impactPoint, radius * 1.2, _heatGlowPaint);

      // Cœur: le shader unitaire est placé et agrandi via le canvas
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

/// Gloss layer: high priority child, drawn after text.
class _BubbleGloss extends PositionComponent with ParentIsA<Bubble> {
  /// Crée la couche brillante dessinée au-dessus du texte.
  _BubbleGloss() : super(priority: 10);

  /// Dessine le reflet si la bulle est visible et n'est pas en explosion.
  @override
  void render(Canvas canvas) {
    if (parent._isHidden || !parent._isVisibleOnScreen()) return;
    if (parent._isPopping) return;
    parent.paintDeformed(canvas, parent._renderer.paintGloss);
  }
}

class _PopParticle {
  /// Initialise une particule avec ses paramètres de mouvement et d'apparence.
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
