// character_backup_painter.dart
//
// Personnage jaune 2.5D à crête en cœur rouge, animé et piloté par une
// "humeur" (Mood). Tout est dessiné en code (CustomPainter), sans asset.
//
// Animations permanentes :
//   * respiration (squash & stretch) et léger rebond
//   * clignements (avec parfois un double clignement)
//   * regard qui bouge légèrement
//   * oreilles qui frétillent, queue qui remue
//   * cœur qui se balance et bat (lub-dub)
// Changer de Mood fait glisser en douceur tous les paramètres (~450 ms).
//
// Pour ajouter une humeur : ajoutez une valeur à Mood, puis un preset dans
// _presets qui ne liste que les paramètres différents de "happy".

// ignore_for_file: library_private_types_in_public_api

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum Mood { happy, excited, surprised, sad, angry, sleepy, love }

// =============================================================================
// Paramètres d'humeur
// =============================================================================

enum _K {
  // yeux
  lid, // 0 ouvert .. 1 fermé (paupière au repos)
  lidSlant, // + en colère (coins intérieurs bas), - triste
  eyeScale,
  pupil, // multiplicateur de la pupille
  gazeY, // biais vertical du regard (px)
  // sourcils
  browLift, // px, négatif = vers le haut
  browTilt, // degrés, + colère, - tristesse
  // bouche
  mW, // multiplicateur de largeur
  mCorner, // y des coins de la bouche
  mTop, // y du point de contrôle de la lèvre supérieure
  mBottom, // y du bas de l'ouverture
  tongue, // 0..1
  tooth, // 0..1
  blush, // multiplicateur des joues
  // oreilles / cœur
  earDroop, // degrés, + tombantes, - dressées
  heartTilt, // degrés
  heartScale,
  heartPulse, // amplitude du battement
  heartRate, // Hz
  // corps
  breathAmp,
  breathRate, // Hz
  bobAmp, // px
  bobRate, // Hz
  shake, // px (tremblement)
  slump, // 0..~0.05 affaissement
  wagAmp, // degrés de la queue
  wagRate, // Hz
  // effets (alpha 0..1)
  tear,
  zzz,
  hearts,
  anger,
}

class MoodParams {
  MoodParams._(this._v);

  final List<double> _v;

  double operator [](_K k) => _v[k.index];

  factory MoodParams._make(Map<_K, double> overrides) {
    final m = {..._defaults, ...overrides};
    return MoodParams._([for (final k in _K.values) m[k]!]);
  }

  /// Paramètres d'une humeur donnée.
  factory MoodParams.of(Mood mood) => _presets[mood]!;

  static MoodParams lerp(MoodParams a, MoodParams b, double t) {
    return MoodParams._([
      for (var i = 0; i < a._v.length; i++) a._v[i] + (b._v[i] - a._v[i]) * t,
    ]);
  }
}

// "happy" = les valeurs par défaut.
const Map<_K, double> _defaults = {
  _K.lid: 0,
  _K.lidSlant: 0,
  _K.eyeScale: 1,
  _K.pupil: 1,
  _K.gazeY: 0,
  _K.browLift: 0,
  _K.browTilt: 0,
  _K.mW: 1,
  _K.mCorner: 360,
  _K.mTop: 349,
  _K.mBottom: 415,
  _K.tongue: 1,
  _K.tooth: 1,
  _K.blush: 1,
  _K.earDroop: 0,
  _K.heartTilt: -5,
  _K.heartScale: 1,
  _K.heartPulse: 0.03,
  _K.heartRate: 0.9,
  _K.breathAmp: 0.015,
  _K.breathRate: 0.45,
  _K.bobAmp: 0,
  _K.bobRate: 1,
  _K.shake: 0,
  _K.slump: 0,
  _K.wagAmp: 7,
  _K.wagRate: 1.1,
  _K.tear: 0,
  _K.zzz: 0,
  _K.hearts: 0,
  _K.anger: 0,
};

final Map<Mood, MoodParams> _presets = {
  Mood.happy: MoodParams._make({}),
  Mood.excited: MoodParams._make({
    _K.eyeScale: 1.06,
    _K.pupil: 1.1,
    _K.browLift: -8,
    _K.mW: 1.15,
    _K.mCorner: 356,
    _K.mTop: 342,
    _K.mBottom: 424,
    _K.blush: 1.3,
    _K.earDroop: -4,
    _K.heartScale: 1.05,
    _K.heartPulse: 0.08,
    _K.heartRate: 2.2,
    _K.breathAmp: 0.02,
    _K.breathRate: 1.2,
    _K.bobAmp: 16,
    _K.bobRate: 1.5,
    _K.wagAmp: 16,
    _K.wagRate: 3.2,
  }),
  Mood.surprised: MoodParams._make({
    _K.eyeScale: 1.14,
    _K.pupil: 0.6,
    _K.browLift: -16,
    _K.mW: 0.6,
    _K.mCorner: 374,
    _K.mTop: 336,
    _K.mBottom: 432,
    _K.tongue: 0,
    _K.tooth: 0,
    _K.blush: 0.6,
    _K.earDroop: -7,
    _K.heartTilt: 0,
    _K.heartScale: 1.12,
    _K.heartPulse: 0.05,
    _K.heartRate: 2.0,
    _K.breathAmp: 0.01,
    _K.breathRate: 0.3,
    _K.shake: 0,
    _K.wagAmp: 3,
    _K.wagRate: 0.6,
  }),
  Mood.sad: MoodParams._make({
    _K.lid: 0.28,
    _K.lidSlant: -0.7,
    _K.eyeScale: 0.98,
    _K.pupil: 1.15,
    _K.gazeY: 5,
    _K.browLift: 4,
    _K.browTilt: -20,
    _K.mW: 0.8,
    _K.mCorner: 384,
    _K.mTop: 346,
    _K.mBottom: 390,
    _K.tongue: 0,
    _K.tooth: 0,
    _K.blush: 0.5,
    _K.earDroop: 20,
    _K.heartTilt: -22,
    _K.heartScale: 0.92,
    _K.heartPulse: 0.015,
    _K.heartRate: 0.6,
    _K.breathAmp: 0.012,
    _K.breathRate: 0.3,
    _K.slump: 0.035,
    _K.wagAmp: 2,
    _K.wagRate: 0.4,
    _K.tear: 1,
  }),
  Mood.angry: MoodParams._make({
    _K.lid: 0.22,
    _K.lidSlant: 0.95,
    _K.pupil: 0.8,
    _K.browLift: 8,
    _K.browTilt: 24,
    _K.mW: 1.1,
    _K.mCorner: 374,
    _K.mTop: 352,
    _K.mBottom: 402,
    _K.tongue: 0,
    _K.blush: 0.3,
    _K.earDroop: -5,
    _K.heartPulse: 0.07,
    _K.heartRate: 2.8,
    _K.breathAmp: 0.022,
    _K.breathRate: 1.0,
    _K.shake: 0,
    _K.wagAmp: 12,
    _K.wagRate: 5.5,
    _K.anger: 1,
  }),
  Mood.sleepy: MoodParams._make({
    _K.lid: 0.88,
    _K.mW: 0.55,
    _K.mCorner: 372,
    _K.mTop: 366,
    _K.mBottom: 392,
    _K.tongue: 0,
    _K.tooth: 0,
    _K.blush: 0.8,
    _K.earDroop: 10,
    _K.heartTilt: -16,
    _K.heartScale: 0.94,
    _K.heartPulse: 0.02,
    _K.heartRate: 0.35,
    _K.breathAmp: 0.028,
    _K.breathRate: 0.25,
    _K.slump: 0.02,
    _K.wagAmp: 1.5,
    _K.wagRate: 0.3,
    _K.zzz: 1,
  }),
  Mood.love: MoodParams._make({
    _K.lid: 0.1,
    _K.eyeScale: 1.06,
    _K.pupil: 1.25,
    _K.browLift: -4,
    _K.browTilt: -6,
    _K.mW: 0.9,
    _K.mCorner: 358,
    _K.mTop: 352,
    _K.mBottom: 406,
    _K.tongue: 0.6,
    _K.tooth: 0,
    _K.blush: 2.3,
    _K.earDroop: -2,
    _K.heartScale: 1.1,
    _K.heartPulse: 0.14,
    _K.heartRate: 1.5,
    _K.breathAmp: 0.02,
    _K.breathRate: 0.7,
    _K.bobAmp: 6,
    _K.bobRate: 0.75,
    _K.wagAmp: 12,
    _K.wagRate: 2.2,
    _K.hearts: 1,
  }),
};

// =============================================================================
// Outils de dessin
// =============================================================================

typedef _P = Paint Function(Rect box);

Color _c(int rgb, [double opacity = 1.0]) => Color.fromRGBO(
      (rgb >> 16) & 0xFF,
      (rgb >> 8) & 0xFF,
      rgb & 0xFF,
      opacity.clamp(0.0, 1.0).toDouble(),
    );

_P _solid(Color color) => (box) => Paint()..color = color;

/// Dégradé radial dans l'espace unitaire (0..1) de la boîte (comme en SVG).
_P _radial(
  List<Color> colors,
  List<double> stops, {
  required double cx,
  required double cy,
  required double r,
  double? fx,
  double? fy,
}) {
  return (box) {
    final m = Matrix4(
      box.width, 0, 0, 0, //
      0, box.height, 0, 0,
      0, 0, 1, 0,
      box.left, box.top, 0, 1,
    );
    return Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        r,
        colors,
        stops,
        TileMode.clamp,
        m.storage,
        (fx != null && fy != null) ? Offset(fx, fy) : null,
        0.0,
      );
  };
}

_P _vertical(List<Color> colors) => (box) => Paint()
  ..shader = ui.Gradient.linear(
    Offset(box.left, box.top),
    Offset(box.left, box.bottom),
    colors,
  );

final _P _gBody = _radial(
  [_c(0xFFF38C), _c(0xFFDA2E), _c(0xFFBF00), _c(0xEE9A00)],
  [0, .4, .78, 1],
  cx: .45, cy: .35, r: .75, fx: .36, fy: .24,
);
final _P _gCream = _radial(
  [_c(0xFFFEEE), _c(0xFFF2B8), _c(0xFFE680, 0)],
  [0, .72, 1],
  cx: .5, cy: .4, r: .7,
);
final _P _gEarInner = _radial(
  [_c(0xFFB9AF), _c(0xF98780), _c(0xE4605D)],
  [0, .7, 1],
  cx: .6, cy: .62, r: .7,
);
final _P _gHeart = _radial(
  [_c(0xFF9A8C), _c(0xFF4B4B), _c(0xD81F2D), _c(0x97101F)],
  [0, .3, .72, 1],
  cx: .38, cy: .3, r: .85, fx: .32, fy: .22,
);
final _P _gBrown = _radial(
  [_c(0x9A6641), _c(0x4E2D1A)],
  [0, 1],
  cx: .4, cy: .3, r: .8,
);
final _P _gSclera = _radial(
  [_c(0xFFFFFF), _c(0xFFFFFF), _c(0xE3D6C6)],
  [0, .55, 1],
  cx: .45, cy: .35, r: .75,
);
final _P _gIris = _radial(
  [_c(0xFFB547), _c(0xFFB547), _c(0xE07A14), _c(0x7E3C0E)],
  [0, .45, .8, 1],
  cx: .5, cy: .5, r: .5,
);
final _P _gPupil = _radial(
  [_c(0x3A241A), _c(0x050302)],
  [0, 1],
  cx: .4, cy: .35, r: .7,
);
final _P _gMouth = _radial(
  [_c(0xC93C4D), _c(0x8E1E2D), _c(0x52101C)],
  [0, .6, 1],
  cx: .5, cy: .3, r: .85,
);
final _P _gTongue = _radial(
  [_c(0xFFB8C6), _c(0xF4758D), _c(0xD2566F)],
  [0, .7, 1],
  cx: .5, cy: .3, r: .75,
);
final _P _gTooth = _vertical([_c(0xFFFFFF), _c(0xEBDDBE)]);

double _rad(double deg) => deg * math.pi / 180;

void _oval(
  Canvas c,
  double cx,
  double cy,
  double rx,
  double ry,
  _P paint, {
  double deg = 0,
}) {
  c.save();
  c.translate(cx, cy);
  if (deg != 0) c.rotate(_rad(deg));
  final box = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
  c.drawOval(box, paint(box));
  c.restore();
}

void _ovalStroke(
  Canvas c,
  double cx,
  double cy,
  double rx,
  double ry,
  Paint stroke, {
  double deg = 0,
}) {
  c.save();
  c.translate(cx, cy);
  if (deg != 0) c.rotate(_rad(deg));
  c.drawOval(
    Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
    stroke,
  );
  c.restore();
}

Path _ovalPath(double cx, double cy, double rx, double ry, [double deg = 0]) {
  final path = Path()
    ..addOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
    );
  if (deg == 0) return path;

  final a = _rad(deg);
  final cs = math.cos(a), sn = math.sin(a);
  final tx = cx - cs * cx + sn * cy;
  final ty = cy - sn * cx - cs * cy;
  final m = Matrix4(
    cs, sn, 0, 0, //
    -sn, cs, 0, 0,
    0, 0, 1, 0,
    tx, ty, 0, 1,
  );
  return path.transform(m.storage);
}

void _fillPath(Canvas c, Path path, _P paint) {
  c.drawPath(path, paint(path.getBounds()));
}

Paint _stroke(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

Path _heartPath() => Path()
  ..moveTo(0, 32)
  ..cubicTo(-42, 6, -40, -30, -17, -33)
  ..cubicTo(-7, -34, 0, -27, 0, -20)
  ..cubicTo(0, -27, 7, -34, 17, -33)
  ..cubicTo(40, -30, 42, 6, 0, 32)
  ..close();

// =============================================================================
// Peintre animé
// =============================================================================

class CharacterBackupPainter extends CustomPainter {
  CharacterBackupPainter({
    required this.time,
    required this.hop,
    required this.params,
    required this.isMoodTransitioning,
    required Listenable repaint,
    this.backgroundColor,
  }) : super(repaint: repaint);

  /// Temps écoulé en secondes (alimenté par un Ticker).
  final ValueListenable<double> time;

  /// Progression du saut (0..1), déclenché au tap.
  final Animation<double> hop;

  /// Paramètres d'humeur courants (déjà interpolés).
  final MoodParams Function() params;

  /// Indique si le personnage passe d'une humeur à une autre.
  final bool Function() isMoodTransitioning;

  /// Indique si l'humeur sélectionnée est amoureuse.

  final Color? backgroundColor;

  static const double _w = 680;
  static const double _h = 640;

  final Path _heart = _heartPath();

  @override
  bool shouldRepaint(covariant CharacterBackupPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final p = params();
    final hopH = math.sin(math.pi * hop.value);

    if (backgroundColor != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor!);
    }

    // Mise à l'échelle proportionnelle + centrage
    final scale = math.min(size.width / _w, size.height / _h);
    canvas.save();
    canvas.translate(
      (size.width - _w * scale) / 2,
      (size.height - _h * scale) / 2,
    );
    canvas.scale(scale);

    // ---- mouvement du corps : respiration, rebond, tremblement, saut ----
    final breath = math.sin(t * 2 * math.pi * p[_K.breathRate]);
    var sy = 1 + p[_K.breathAmp] * breath - p[_K.slump];
    var sx = 1 - p[_K.breathAmp] * 0.6 * breath + p[_K.slump] * 0.5;
    final bob =
        -p[_K.bobAmp] * (0.5 - 0.5 * math.cos(2 * math.pi * p[_K.bobRate] * t));
    const dx = 0.0;
    final dy = bob - 46 * hopH;
    sy *= 1 + 0.06 * hopH;
    sx *= 1 - 0.04 * hopH;

    _groundShadow(canvas, (-dy / 260).clamp(0.0, 0.5).toDouble());

    canvas.save();
    canvas.translate(360 + dx, 585 + dy);
    canvas.scale(sx, sy);
    canvas.translate(-360, -585);

    _tail(canvas, p, t);
    _ears(canvas, p, t);
    _feet(canvas);
    _hairOrHeart(canvas, p, t);
    _bodyAndFace(canvas, p);
    _eyes(canvas, p, t);
    _cheeksAndNose(canvas, p);
    _mouth(canvas, p, t);
    _paws(canvas);
    _finalHighlights(canvas);
    _effects(canvas, p, t);

    canvas.restore();
    canvas.restore();
  }

  // ---------------------------------------------------------------------------

  void _groundShadow(Canvas c, double lift) {
    c.save();
    c.translate(362, 590);
    c.scale(1 - lift, 1 - lift * 0.6);
    c.translate(-362, -590);
    _oval(c, 362, 590, 200, 20, _solid(Colors.black.withValues(alpha: 0.10)));
    _oval(c, 362, 590, 160, 14, _solid(Colors.black.withValues(alpha: 0.14)));
    _oval(c, 362, 589, 110, 9, _solid(Colors.black.withValues(alpha: 0.20)));
    c.restore();
  }

  void _tail(Canvas c, MoodParams p, double t) {
    final wag = p[_K.wagAmp] * math.sin(t * 2 * math.pi * p[_K.wagRate]);

    c.save();
    // la queue pivote autour du point où elle rejoint le corps
    c.translate(232, 440);
    c.rotate(_rad(wag));
    c.translate(-232, -440);

    c.translate(172, 455);
    c.rotate(_rad(38));
    c.translate(-172, -455);

    _oval(c, 172, 455, 74, 45, _gBody);

    c.save();
    c.clipPath(_ovalPath(172, 455, 74, 45));
    for (final r in const [
      Rect.fromLTWH(96, 400, 26, 110),
      Rect.fromLTWH(144, 400, 22, 110),
      Rect.fromLTWH(190, 400, 22, 110),
      Rect.fromLTWH(232, 400, 30, 110),
    ]) {
      c.drawRect(r, _gBrown(r));
    }
    c.restore();

    // reflet de la queue, coupé à sa forme
    c.save();
    c.clipPath(_ovalPath(172, 455, 74, 45));
    _oval(c, 160, 436, 44, 9, _solid(_c(0xFFFFFF, .25)));
    c.restore();
    c.restore();
  }

  void _ears(Canvas c, MoodParams p, double t) {
    final droop = p[_K.earDroop];
    final wigL = 2.2 * math.sin(t * 2 * math.pi * 0.55);
    final wigR = 2.2 * math.sin(t * 2 * math.pi * 0.55 + 1.3);

    // ---- oreille gauche ----
    c.save();
    c.translate(195, 335);
    c.rotate(_rad(-(droop + wigL)));
    c.translate(-195, -335);

    c.save();
    c.translate(140, 305);
    c.rotate(_rad(-10));
    c.translate(-140, -305);
    _oval(c, 140, 305, 66, 84, _gBody);
    _oval(c, 116, 258, 16, 7, _solid(_c(0xFFFFFF, .6)), deg: -40);
    c.restore();

    _oval(c, 148, 310, 42, 58, _gEarInner, deg: -10);
    c.save();
    c.translate(-3, -3);
    c.clipPath(_ovalPath(148, 310, 42, 58, -10));
    _ovalStroke(c, 148, 310, 42, 58, _stroke(_c(0xC4443F, .35), 14), deg: -10);
    c.restore();
    _oval(c, 170, 345, 14, 22, _solid(_c(0xFFD0C8, .20)), deg: -10);
    c.restore();

    // ---- oreille droite ----
    c.save();
    c.translate(478, 262);
    c.rotate(_rad(droop + wigR));
    c.translate(-478, -262);

    c.save();
    c.translate(520, 222);
    c.rotate(_rad(25));
    c.translate(-520, -222);
    _oval(c, 520, 222, 70, 84, _gBody);
    _oval(c, 495, 170, 18, 7, _solid(_c(0xFFFFFF, .6)), deg: -30);
    c.restore();

    _oval(c, 514, 226, 44, 58, _gEarInner, deg: 25);
    c.save();
    c.translate(-3, -3);
    c.clipPath(_ovalPath(514, 226, 44, 58, 25));
    _ovalStroke(c, 514, 226, 44, 58, _stroke(_c(0xC4443F, .35), 14), deg: 25);
    c.restore();
    _oval(c, 528, 262, 14, 22, _solid(_c(0xFFD0C8, .20)), deg: 25);
    c.restore();
  }

  void _feet(Canvas c) {
    _oval(c, 292, 550, 46, 32, _gBody);
    _oval(c, 420, 557, 44, 30, _gBody);

    final toe = _stroke(_c(0xC98700), 2.5);
    c.drawLine(const Offset(282, 565), const Offset(284, 574), toe);
    c.drawLine(const Offset(298, 566), const Offset(299, 575), toe);
    c.drawLine(const Offset(410, 571), const Offset(412, 580), toe);
    c.drawLine(const Offset(427, 571), const Offset(428, 580), toe);
  }

  /// Dessinée AVANT la tête : la tête en cache la pointe.
  void _hairOrHeart(Canvas c, MoodParams p, double t) {
    final sway = 3.5 * math.sin(t * 2 * math.pi * 0.45);

    // battement "lub-dub"
    final ph = (t * p[_K.heartRate]) % 1.0;
    final beat = math.exp(-math.pow((ph - .08) / .05, 2)) +
        .6 * math.exp(-math.pow((ph - .28) / .06, 2));
    final pulse = 1 + p[_K.heartPulse] * beat;

    c.save();
    c.translate(358, 152); // base de la crête sur la tête
    c.rotate(_rad(p[_K.heartTilt] + sway));
    c.scale(p[_K.heartScale] * pulse);
    c.translate(0, -40);
    c.scale(1.75);

    _fillPath(c, _heart, _gHeart);
    c.drawPath(_heart, _stroke(_c(0xFF8478, .7), 1.2));
    c.drawLine(
      const Offset(0, -20),
      const Offset(0, -11),
      _stroke(_c(0x7E0B18, .45), 2),
    );
    final rim = Path()
      ..moveTo(-6, 26)
      ..cubicTo(16, 12, 30, -2, 33, -14);
    c.drawPath(rim, _stroke(_c(0xFF8478, .5), 2.5));
    _oval(c, -21, -18, 9, 4.5, _solid(_c(0xFFFFFF, .75)), deg: -35);
    c.drawCircle(const Offset(-30, -6), 2, Paint()..color = _c(0xFFFFFF, .8));
    c.restore();
  }

  void _bodyAndFace(Canvas c, MoodParams p) {
    _oval(c, 360, 355, 186, 202, _gBody);
    _oval(c, 365, 300, 158, 126, _gCream);
    // Reflets du ventre et du haut de la tête : coupés à la forme du corps.
    c.save();
    c.clipPath(_ovalPath(360, 355, 186, 202));
    _oval(c, 360, 520, 130, 28, _solid(_c(0xFFE04A, .5)));
    _oval(c, 358, 162, 42, 9, _solid(_c(0xE0453A, .22)));
    c.restore();

    final lift = p[_K.browLift];
    final tilt = p[_K.browTilt];
    _oval(c, 266, 229 + lift, 21, 10, _gBrown, deg: -22 + tilt);
    _oval(c, 432, 186 + lift, 23, 10, _gBrown, deg: 12 - tilt);
  }

  // ---- yeux -----------------------------------------------------------------

  /// 0 = ouvert, 1 = fermé. Clignement toutes les ~3,9 s et double
  /// clignement toutes les ~11,7 s.
  double _blink(double t) {
    double one(double period, double offset) {
      final ph = (t + offset) % period;
      const d = 0.18;
      if (ph >= d) return 0;
      final x = ph / d;
      return 1 - (2 * x - 1).abs();
    }

    return math.max(one(3.9, 0), math.max(one(11.7, 0), one(11.7, -0.3)));
  }

  void _eyes(Canvas c, MoodParams p, double t) {
    final blink = _blink(t);
    final calm = 1 - p[_K.lid] * 0.8;
    final gx = (2.5 * math.sin(t * .7) + 1.5 * math.sin(t * 1.9)) * calm;
    final gy = (1.8 * math.sin(t * .9 + 1)) * calm + p[_K.gazeY];
    _eye(c, p, blink, gx, gy, left: true);
    _eye(c, p, blink, gx, gy, left: false);
  }

  void _eye(
    Canvas c,
    MoodParams p,
    double blink,
    double gx,
    double gy, {
    required bool left,
  }) {
    final patch = left ? [279.0, 324.0, 68.0, 76.0] : [467.0, 279.0, 62.0, 73.0];
    final sc = left ? [284.0, 326.0, 56.0, 63.0] : [463.0, 281.0, 50.0, 62.0];
    final iris = left ? [306.0, 332.0, 44.0] : [447.0, 286.0, 44.0];
    final pupil = left ? [308.0, 334.0, 29.0] : [445.0, 288.0, 29.0];
    final shine1 = left ? [321.0, 316.0, 9.0] : [460.0, 270.0, 9.0];
    final shine2 = left ? [293.0, 345.0, 4.5] : [432.0, 299.0, 4.5];

    final lidAmt = 1 - (1 - p[_K.lid]) * (1 - blink);

    c.save();
    c.translate(sc[0], sc[1]);
    c.scale(p[_K.eyeScale]);
    c.translate(-sc[0], -sc[1]);

    _oval(c, patch[0], patch[1], patch[2], patch[3], _gBrown, deg: -12);
    _oval(c, sc[0], sc[1], sc[2], sc[3], _gSclera, deg: -12);

    c.save();
    c.clipPath(_ovalPath(sc[0], sc[1], sc[2], sc[3], -12));

    _oval(c, iris[0] + gx, iris[1] + gy, iris[2], iris[2], _gIris);
    final pr = pupil[2] * p[_K.pupil];
    _oval(c, pupil[0] + gx, pupil[1] + gy, pr, pr, _gPupil);
    // Ombre douce de la paupière supérieure : un dégradé qui s'efface,
    // sans bord net (sinon on dirait une deuxième paupière).
    c.save();
    c.translate(sc[0], sc[1]);
    c.rotate(_rad(-12));
    final shadeRect = Rect.fromLTWH(-sc[2], -sc[3], sc[2] * 2, sc[3] * 0.65);
    c.drawRect(
      shadeRect,
      Paint()
        ..shader = ui.Gradient.linear(
          shadeRect.topCenter,
          shadeRect.bottomCenter,
          [_c(0x8A6A55, .30), _c(0x8A6A55, 0)],
        ),
    );
    c.restore();

    c.drawCircle(
      Offset(shine1[0], shine1[1]),
      shine1[2],
      Paint()..color = _c(0xFFFFFF),
    );
    c.drawCircle(
      Offset(shine2[0], shine2[1]),
      shine2[2],
      Paint()..color = _c(0xFFFFFF, .9),
    );

    // paupière (dans le repère incliné de l'oeil)
    c.save();
    c.translate(sc[0], sc[1]);
    c.rotate(_rad(-12));
    _lid(c, sc[2], sc[3], lidAmt, p[_K.lidSlant], left ? 1.0 : -1.0);
    c.restore();

    c.restore(); // clip
    c.restore(); // échelle de l'oeil
  }

  void _lid(Canvas c, double rx, double ry, double amt, double slant, double dir) {
    if (amt < 0.01) return;
    final edge = -ry - 6 + amt * (2 * ry + 18);
    final slantEff = slant * (amt.clamp(0.0, 0.35) / 0.35);
    double yAt(double x) => edge + slantEff * ry * 0.7 * dir * (x / rx);

    final xl = -rx - 6, xr = rx + 6;
    final yl = yAt(xl), yr = yAt(xr);
    final ctrlY = edge + 10;

    final fill = Path()
      ..moveTo(xl, -ry - 24)
      ..lineTo(xr, -ry - 24)
      ..lineTo(xr, yr)
      ..quadraticBezierTo(0, ctrlY, xl, yl)
      ..close();
    c.drawPath(fill, Paint()..color = _c(0x7B4C2D));

    if (amt > 0.03) {
      final line = Path()
        ..moveTo(xl, yl)
        ..quadraticBezierTo(0, ctrlY, xr, yr);
      c.drawPath(line, _stroke(_c(0x4E2D1A), 2.5));
    }
  }

  void _cheeksAndNose(Canvas c, MoodParams p) {
    final a = 0.32 * p[_K.blush];
    _oval(c, 228, 398, 30, 18, _solid(_c(0xFF9F8F, a)));
    _oval(c, 505, 366, 28, 17, _solid(_c(0xFF9F8F, a)));
    _oval(c, 386, 325, 15, 10.5, _gBrown);
    _oval(c, 381, 321, 5, 2.5, _solid(_c(0xFFFFFF, .55)));
  }

  // ---- bouche (paramétrique pour pouvoir passer d'une humeur à l'autre) -----

  void _mouth(Canvas c, MoodParams p, double t) {
  final w = p[_K.mW];
  const cx = 386.0;
  final cornerY = p[_K.mCorner];
  final topCtrl = p[_K.mTop];
  // bouche "qui respire" quand il dort
  final bottomY =
      p[_K.mBottom] + p[_K.zzz] * 2.5 * math.sin(t * 2 * math.pi * 0.25);
  final d = bottomY - cornerY;

  final xl = cx - 34 * w;
  final xr = cx + 34 * w;
  final yl = cornerY;
  final yr = cornerY - 2;

  // Pointe centrale de la lèvre (même hauteur que le sommet de l'ancienne
  // arche, donc les humeurs gardent leur forme).
  final cuspY = 0.25 * yl + 0.5 * topCtrl + 0.25 * yr;

  // Profondeur des deux arcs (creux) de la lèvre supérieure.
  final dip = 7.0 * math.max(0.6, math.min(w, 1.2));

  // Chaque arc est une quadratique dont le point de contrôle est sous la
  // corde : la courbe passe donc `dip` plus bas que la ligne droite.
  final ctrlL = Offset((xl + cx) / 2, (yl + cuspY) / 2 + 2 * dip);
  final ctrlR = Offset((cx + xr) / 2, (cuspY + yr) / 2 + 2 * dip);

  // Le haut de la bouche suit directement les deux arcs :
  // remplissage et contour sont donc identiques.
  final mouth = Path()
    ..moveTo(xl, yl)
    ..quadraticBezierTo(ctrlL.dx, ctrlL.dy, cx, cuspY)
    ..quadraticBezierTo(ctrlR.dx, ctrlR.dy, xr, yr)
    ..cubicTo(
      xr + 5 * w, cornerY + .56 * d,
      cx + 23 * w, cornerY + .93 * d,
      cx + 2, bottomY,
    )
    ..cubicTo(
      cx - 20 * w, cornerY + .89 * d,
      xl - 2 * w, cornerY + .53 * d,
      xl, yl,
    )
    ..close();

  _fillPath(c, mouth, _gMouth);

  c.save();
  c.clipPath(mouth);

  // ombre sous la lèvre supérieure
  _oval(c, cx + 2, cuspY + 9, 40 * w, 12, _solid(_c(0x3E0A14, .55)));

  // langue : elle sort de plus en plus avec la valeur "tongue"
  final vis = p[_K.tongue];
  if (vis > 0.01) {
    final ty = bottomY + 18 - 29 * vis;
    final trx = (24 * math.min(w, 1.05)).toDouble();
    _oval(c, cx + 3, ty, trx, 17, _gTongue);
    c.drawLine(
      Offset(cx + 3, ty - 12),
      Offset(cx + 3, ty + 6),
      _stroke(_c(0xC0455E, .7), 2),
    );
    _oval(c, cx - 5, ty - 7, 8, 4, _solid(_c(0xFFFFFF, .55)), deg: -25);
  }

  // dent accrochée à la pointe de la lèvre (coupée par les arcs)
  final tooth = p[_K.tooth];
  if (tooth > 0.02) {
    c.save();
    c.translate(cx, cuspY + 1.5);
    c.scale(1, tooth);
    final tp = Path()
      ..moveTo(-9, 0)
      ..lineTo(5, 0)
      ..lineTo(5, 12)
      ..quadraticBezierTo(-2, 17.5, -9, 12)
      ..close();
    _fillPath(c, tp, _gTooth);
    c.restore();
  }
  c.restore();

  // Contour avec jointure en pointe : la pointe centrale reste nette
  // comme sur votre croquis (avec une jointure ronde elle s'arrondirait).
  c.drawPath(
    mouth,
    _stroke(_c(0x7A1826), 2.5)..strokeJoin = StrokeJoin.miter,
  );
}

  void _paws(Canvas c) {
    _oval(c, 274, 478, 44, 44, _gBody);
    _oval(c, 258, 458, 14, 8, _solid(_c(0xFFFFFF, .65)), deg: -35);
    _oval(c, 502, 446, 42, 42, _gBody);
    _oval(c, 488, 427, 13, 8, _solid(_c(0xFFFFFF, .65)), deg: -35);
  }

  void _finalHighlights(Canvas c) {
    // Un seul reflet, coupé à la forme de la tête pour ne jamais déborder.
    c.save();
    c.clipPath(_ovalPath(360, 355, 186, 202));
    _oval(c, 292, 205, 36, 13, _solid(_c(0xFFFFFF, .30)), deg: -38);
    c.restore();
  }

  // ---- effets : larmes, Zzz, petits coeurs, marque de colère ----------------

  void _effects(Canvas c, MoodParams p, double t) {
    if (p[_K.tear] > 0.02) _tears(c, p[_K.tear], t);
    if (p[_K.anger] > 0.02) _anger(c, p[_K.anger], t);
    if (p[_K.zzz] > 0.02) _zzz(c, p[_K.zzz], t);
    if (p[_K.hearts] > 0.02) _floatingHearts(c, p[_K.hearts], t);
  }

  void _tears(Canvas c, double amount, double t) {
    final drop = Path()
      ..moveTo(0, -11)
      ..cubicTo(5, -3, 8, 2, 8, 5)
      ..cubicTo(8, 9, 4, 11, 0, 11)
      ..cubicTo(-4, 11, -8, 9, -8, 5)
      ..cubicTo(-8, 2, -5, -3, 0, -11)
      ..close();

    void tear(Offset from, Offset to, double offset) {
      final life = (t * 0.6 + offset) % 1.0;
      final a = math.sin(math.pi * life) * amount;
      final pos = Offset.lerp(from, to, life)!;
      c.save();
      c.translate(pos.dx, pos.dy);
      c.scale(0.8 + 0.4 * life);
      c.drawPath(drop, Paint()..color = _c(0x8FD3FF, 0.85 * a));
      c.drawPath(drop, _stroke(_c(0x4BA8E0, 0.6 * a), 1.5));
      _oval(c, -2.5, -1, 2.2, 3.4, _solid(_c(0xFFFFFF, 0.8 * a)), deg: 20);
      c.restore();
    }

    tear(const Offset(262, 386), const Offset(238, 446), 0.0);
    tear(const Offset(478, 340), const Offset(502, 402), 0.45);
  }

  void _anger(Canvas c, double amount, double t) {
    c.save();
    c.translate(505, 150);
    c.scale((1 + 0.1 * math.sin(t * 14)) * amount);
    final paint = _stroke(_c(0xE53935, amount), 5);
    final arc = Path()
      ..moveTo(6, -6)
      ..quadraticBezierTo(18, -6, 18, -20);
    for (var k = 0; k < 4; k++) {
      c.save();
      c.rotate(k * math.pi / 2);
      c.drawPath(arc, paint);
      c.restore();
    }
    c.restore();
  }

  void _zzz(Canvas c, double amount, double t) {
    for (var i = 0; i < 3; i++) {
      final life = (t * 0.35 + i / 3) % 1.0;
      final a = math.sin(math.pi * life) * amount;
      final size = 20.0 + i * 7 + life * 10;
      final tp = TextPainter(
        text: TextSpan(
          text: 'Z',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: _c(0x7C93D6, a),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(470 + life * 50 + i * 8, 150 - life * 100));
    }
  }

  void _floatingHearts(Canvas c, double amount, double t) {
    for (var i = 0; i < 3; i++) {
      final life = (t * 0.45 + i / 3) % 1.0;
      final a = math.sin(math.pi * life) * amount;
      final x = 358 + (i - 1) * 62 + 12 * math.sin(life * 6 + i);
      final y = 105 - life * 115;
      c.save();
      c.translate(x, y);
      c.scale(0.3 + 0.18 * life);
      c.saveLayer(null, Paint()..color = _c(0x000000, a));
      _fillPath(c, _heart, _gHeart);
      c.restore();
      c.restore();
    }
  }
}