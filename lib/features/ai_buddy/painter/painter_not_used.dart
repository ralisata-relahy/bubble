/*import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ai_buddy/ai_buddy/models/character_pose.dart';
import 'package:ai_buddy/ai_buddy/models/saucePalette.dart';
import 'package:flutter/material.dart';

// PAINTER
Color _a(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());
double _deg(double d) => d * math.pi / 180;

class EdutainerPainter extends CustomPainter {
  EdutainerPainter(
    this.pose, {
    this.showShadow = false,
    this.laserColor = const Color(0xFF4DF0FF),
    this.bodyColor, 
    this.saucerColor, 
  });

  final EdutainerPose pose;
  final bool showShadow;
  final Color laserColor;
  final Color? bodyColor;
  final Color? saucerColor;

  static const Size designSize = Size(400, 520);
  static const Offset _pivot = Offset(200, 436);
  static const Offset _orb = Offset(200, 92);
  static const Offset _eyeC = Offset(205, 272);

  static const List<List<String>> symbolSets = [
    ['1 2 3', '# π §'],
    ['E=mc²', '∑ ∫ √'],
    ['ħ Δ Ω', 'F=ma'],
    ['∞ ≈ ≠', 'λ φ θ'],
    ['H₂O', '∂ ∇ ±'],
  ];

  late final RadialGradient _redGrad = _buildBodyGradient(bodyColor);
  late final SaucerPalette _sp = SaucerPalette.from(saucerColor);

  static RadialGradient _buildBodyGradient(Color? base) {
    if (base == null) {
      return const RadialGradient(
        center: Alignment(-0.35, -0.5),
        radius: 1.0,
        colors: [Color(0xFFFF6A5C), Color(0xFFE41E1E), Color(0xFFA30D16)],
        stops: [0, 0.55, 1],
      );
    }
    final hsl = HSLColor.fromColor(base);
    Color shade(double d) =>
        hsl.withLightness((hsl.lightness + d).clamp(0.0, 1.0)).toColor();
    return RadialGradient(
      center: const Alignment(-0.35, -0.5),
      radius: 1.0,
      colors: [shade(0.17), base, shade(-0.16)],
      stops: const [0, 0.55, 1],
    );
  }

  double get _dy => -pose.bob * 10;
  double get _sx => 1 + pose.squash * 0.05;
  double get _sy => 1 - pose.squash * 0.06;

  Offset _groupPoint(Offset p) {
    var q = p - _pivot;
    q = Offset(q.dx * _sx, q.dy * _sy);
    final c = math.cos(pose.tilt), s = math.sin(pose.tilt);
    q = Offset(q.dx * c - q.dy * s, q.dx * s + q.dy * c);
    return q + _pivot + Offset(0, _dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(
      size.width / designSize.width,
      size.height / designSize.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - designSize.width * s) / 2,
      (size.height - designSize.height * s) / 2,
    );
    canvas.scale(s);

    if (showShadow) _shadow(canvas);
    _foot(canvas, 148, pose.stepLeft, -1);
    _foot(canvas, 252, pose.stepRight, 1);

    canvas.save();
    canvas.translate(_pivot.dx, _pivot.dy + _dy);
    canvas.rotate(pose.tilt);
    canvas.scale(_sx, _sy);
    canvas.translate(-_pivot.dx, -_pivot.dy);
    _saucer(canvas);
    _body(canvas);
    _eye(canvas);
    _angerMark(canvas);
    _mouth(canvas);
    _arms(canvas);
    canvas.restore();

    _lasers(canvas);
    canvas.restore();
  }

  // shadow & feet
  void _shadow(Canvas canvas) {
    final r = Rect.fromCenter(
      center: const Offset(200, 486),
      width: 250 - pose.bob * 30,
      height: 30,
    );
    canvas.drawOval(
      r,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _foot(Canvas canvas, double cx, double lift, double side) {
    final cy = 452 - lift * 28;
    canvas.save();
    canvas.translate(cx + side * lift * 10, cy);
    canvas.rotate(side * lift * 0.28);
    final rect = Rect.fromCenter(center: Offset.zero, width: 86, height: 66);
    final oval = Path()..addOval(rect);
    canvas.drawPath(oval, Paint()..shader = _redGrad.createShader(rect));
    canvas.save();
    canvas.clipPath(oval);
    final seam = Path()
      ..moveTo(-45, 6)
      ..quadraticBezierTo(0, 24, 45, 6);
    final sole = Path.from(seam)
      ..lineTo(45, 40)
      ..lineTo(-45, 40)
      ..close();
    canvas.drawPath(
      sole,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFC9DDF2)],
        ).createShader(rect),
    );
    canvas.drawPath(
      seam,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0x55A30D16),
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-14, -16), width: 26, height: 10),
      Paint()..color = const Color(0x77FFFFFF),
    );
    canvas.restore();

    // motion ticks next to a lifted foot
    _burst(
      canvas,
      Offset(cx + side * (50 + lift * 10), cy - 4),
      side < 0 ? math.pi : 0,
      0.5,
      lift * 0.9,
      n: 2,
      inner: 6,
      outer: 20,
    );
  }

  Path _heartPath(Offset c, double s) {
    return Path()
      ..moveTo(c.dx, c.dy + s * 0.5)
      ..cubicTo(
        c.dx - s * 0.9,
        c.dy + s * 0.05,
        c.dx - s * 0.5,
        c.dy - s * 0.6,
        c.dx,
        c.dy - s * 0.2,
      )
      ..cubicTo(
        c.dx + s * 0.5,
        c.dy - s * 0.6,
        c.dx + s * 0.9,
        c.dy + s * 0.05,
        c.dx,
        c.dy + s * 0.5,
      )
      ..close();
  }

  // saucer
  void _saucer(Canvas canvas) {
    final t = pose.time;
    final amber = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: _sp.stem,
    );
    // stem
    final stem = Path()
      ..moveTo(185, 176)
      ..lineTo(189, 130)
      ..lineTo(211, 130)
      ..lineTo(215, 176)
      ..close();
    canvas.drawPath(
      stem,
      Paint()
        ..shader = amber.createShader(const Rect.fromLTWH(185, 130, 30, 46)),
    );

    canvas.save();
    canvas.translate(200, 165);
    canvas.rotate(math.sin(t * 3) * 0.04);
    canvas.translate(-200, -165);

    // disc
    final disc = Rect.fromCenter(
      center: const Offset(200, 122),
      width: 132,
      height: 34,
    );
    canvas.drawOval(
      disc.shift(const Offset(0, 7)),
      Paint()..color = _sp.discEdge,
    );
    canvas.drawOval(
      disc,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_sp.discTop, _sp.discMid, _sp.discBottom],
        ).createShader(disc),
    );
    final ring = Rect.fromCenter(
      center: const Offset(200, 121),
      width: 108,
      height: 20,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = _sp.ringGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawArc(
      ring,
      t * 4,
      1.0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // orbit (shared geometry, drawn in two halves for depth)
    final orbit = Rect.fromCenter(
      center: const Offset(200, 122),
      width: 164,
      height: 46,
    );
    final op = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = _sp.orbitArc;

    void orbitArcs() {
      canvas.drawArc(orbit, t * 5, 0.9, false, op);
      canvas.drawArc(orbit, t * 5 + math.pi, 0.9, false, op);
    }

    // BACK half of the orbit
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 400, 122));
    orbitArcs();
    canvas.restore();

    // neck + orb
    canvas.drawRRect(
      RRect.fromLTRBR(192, 104, 208, 124, const Radius.circular(4)),
      Paint()
        ..shader = amber.createShader(const Rect.fromLTWH(192, 104, 16, 20)),
    );
    final glow = 0.45 + 0.35 * pose.laser * (0.5 + 0.5 * math.sin(t * 10));
    canvas.drawCircle(
      _orb,
      40,
      Paint()
        ..color = _a(_sp.orbGlow, glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    final orbRect = Rect.fromCircle(center: _orb, radius: 24);
    canvas.drawCircle(
      _orb,
      24,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [_sp.orbLight, _sp.orbMid, _sp.orbDark],
          stops: const [0, 0.55, 1],
        ).createShader(orbRect),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(191, 82), width: 14, height: 8),
      Paint()..color = const Color(0xCCFFFFFF),
    );
    canvas.drawCircle(
      const Offset(207, 99),
      2.5,
      Paint()..color = const Color(0x99FFFFFF),
    );

    // FRONT half of the orbit
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 122, 400, 600));
    orbitArcs();
    canvas.restore();

    canvas.restore();

    _burst(
      canvas,
      _orb,
      -math.pi / 4,
      0.38,
      pose.laser * (0.5 + 0.5 * math.sin(t * 10)),
      n: 3,
      inner: 38,
      outer: 58,
    );
  }

    // anger mark (cross-pulse on the forehead), only while angry
  void _angerMark(Canvas canvas) {
    if (pose.mischief <= 0.01) return;
    final s = pose.mischief * (1 + 0.1 * math.sin(pose.time * 9));
    canvas.save();
    canvas.translate(262, 214);
    canvas.scale(s);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9E0A15);
    const r = 17.0;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(sx * r * 0.28, sy * r)
            ..quadraticBezierTo(
              sx * r * 0.28,
              sy * r * 0.28,
              sx * r,
              sy * r * 0.28,
            ),
          p,
        );
      }
    }
    canvas.restore();
  }

  // body
  static final Path _bodyPath = Path()
    ..moveTo(200, 165)
    ..cubicTo(270, 165, 318, 250, 318, 330)
    ..cubicTo(318, 400, 265, 436, 200, 436)
    ..cubicTo(135, 436, 82, 400, 82, 330)
    ..cubicTo(82, 250, 130, 165, 200, 165)
    ..close();

  void _body(Canvas canvas) {
    final b = _bodyPath.getBounds();
    canvas.drawPath(_bodyPath, Paint()..shader = _redGrad.createShader(b));
    canvas.save();
    canvas.clipPath(_bodyPath);
    // bounce light from below
    final bl = Rect.fromCenter(
      center: const Offset(200, 442),
      width: 260,
      height: 80,
    );
    canvas.drawOval(
      bl,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x77FF9AA0), Color(0x00FF9AA0)],
        ).createShader(bl),
    );
    // rim light
    canvas.drawPath(
      _bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0x33FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // specular highlights
    canvas.save();
    canvas.translate(124, 238);
    canvas.rotate(-0.9);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 78, height: 15),
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
    canvas.drawCircle(
      const Offset(112, 276),
      5,
      Paint()..color = const Color(0x77FFFFFF),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(228, 186), width: 50, height: 10),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
  }

  // eye
  void _eye(Canvas canvas) {
    const rx = 64.0, ry = 60.0;
    final open = math.max(1 - pose.blink, 0.04);
    final m = pose.mischief.clamp(0.0, 1.0);
    final hr = pose.heart.clamp(0.0, 1.0); 

    // eye shadow
    canvas.drawOval(
      Rect.fromCenter(center: _eyeC, width: rx * 2 + 14, height: ry * 2 + 14),
      Paint()
        ..color = const Color(0x66A30D16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.save();
    canvas.translate(_eyeC.dx, _eyeC.dy);
    canvas.scale(1, open);
    final er = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2,
      height: ry * 2,
    );

    // sclera
    canvas.drawOval(
      er,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [Colors.white, Color(0xFFF4F7FB), Color(0xFFC9D6E6)],
          stops: [0, 0.7, 1],
        ).createShader(er),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(er));

    var lk = pose.look;
    if (lk.distance > 1) lk = lk / lk.distance;
    final ic = Offset(lk.dx * 16, lk.dy * 8);

    if (hr > 0.01) {
      // heart iris
      final pulse = 1 + 0.08 * math.sin(pose.time * 6);
      final size = 80 * hr * pulse;
      final heart = _heartPath(ic, size);
      canvas.drawPath(
        heart,
        Paint()
          ..color = const Color(0x55FF2D6F)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        heart,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFFF8FB1), Color(0xFFFF2D6F), Color(0xFFB0124A)],
            stops: [0, 0.55, 1],
          ).createShader(heart.getBounds()),
      );
      canvas.drawCircle(
        ic + Offset(-size * 0.28, -size * 0.12),
        size * 0.12,
        Paint()..color = Colors.white,
      );
    } else {
      // normal iris / pupil
      final ir = Rect.fromCircle(center: ic, radius: 38);
      canvas.drawCircle(
        ic,
        38,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF6CC8FF), Color(0xFF1E6FE0), Color(0xFF0B2E9A)],
            stops: [0, 0.6, 1],
          ).createShader(ir),
      );
      canvas.drawCircle(
        ic,
        38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF08226F),
      );
      canvas.drawCircle(
        ic,
        21 - 5 * m, // pupil contracts when angry
        Paint()..color = const Color(0xFF05060F),
      );
      canvas.drawCircle(
        ic + const Offset(16, -16),
        10,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        ic + const Offset(25, 6),
        4.5,
        Paint()..color = Colors.white,
      );
    }

    // angry lid: V-shaped, high at the outer corners, low in the middle
    if (m > 0.01) {
      final outerY = -ry * (1 - 0.3 * m);
      final centerY = -ry * (1 - 0.5 * m);
      const ext = rx + 6;
      final lid = Path()
        ..moveTo(-ext, -ry - 6)
        ..lineTo(ext, -ry - 6)
        ..lineTo(ext, outerY)
        ..lineTo(0, centerY)
        ..lineTo(-ext, outerY)
        ..close();
      canvas.drawPath(lid, Paint()..shader = _redGrad.createShader(er));
    }

    // upper lid shadow
    canvas.drawRect(
      er,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0x44000000), Color(0x00000000)],
        ).createShader(er),
    );
    canvas.restore();
    canvas.drawOval(
      er,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0x33000000),
    );
    canvas.restore();
  }

  // mouth & tongue
  void _mouth(Canvas canvas) {
    final mh = 14 + 26 * pose.mouthOpen;
    const top = 352.0;
    final mouth = Path()
      ..moveTo(146, top)
      ..quadraticBezierTo(200, top - 5, 254, top)
      ..cubicTo(225, top + mh * 1.6, 175, top + mh * 1.6, 146, top)
      ..close();
    final mb = mouth.getBounds();
    canvas.drawPath(
      mouth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0407), Color(0xFF8B1018)],
        ).createShader(mb),
    );
    // cheek dimples
    /*=final dp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x88A30D16);
    canvas.drawArc(Rect.fromCenter(center: const Offset(140, 348), width: 12, height: 16), -1.2, 2.4, false, dp);
    canvas.drawArc(Rect.fromCenter(center: const Offset(260, 348), width: 12, height: 16), math.pi - 1.2, 2.4, false, dp);*/

    // tongue
    final tLen = 38 + 26 * pose.tongueOut;
    final tTop = top + 6;
    final tr = Rect.fromLTWH(168, tTop, 64, tLen);
    final tongue = RRect.fromRectAndCorners(
      tr,
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
      bottomLeft: const Radius.circular(32),
      bottomRight: const Radius.circular(32),
    );
    canvas.drawRRect(
      tongue,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8FA3), Color(0xFFE8405F)],
        ).createShader(tr),
    );
    canvas.drawOval(
      Rect.fromLTWH(176, tTop + 3, 18, 7),
      Paint()..color = const Color(0x66FFFFFF),
    );

    final rows = symbolSets[pose.symbolSet.abs() % symbolSets.length];
    for (var i = 0; i < rows.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: rows[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1,
            shadows: [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final sc = math.min(1.0, 54 / tp.width);
      canvas.save();
      canvas.translate(tr.center.dx, tr.top + tLen * 0.2 + i * tLen * 0.33 + 7);
      canvas.scale(sc);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  // arms
  void _arms(Canvas canvas) {
    // raised arm
    var a = _deg(-150) + pose.waveArm * 0.3;
    final tipUp = _arm(canvas, const Offset(100, 318), a, 92, 15, 27);
    _burst(
      canvas,
      tipUp,
      a - 0.4,
      0.55,
      pose.waveArm.abs(),
      n: 3,
      inner: 36,
      outer: 54,
    );
    // lowered arm
    a = _deg(24) + pose.downArm * 0.25;
    _arm(canvas, const Offset(298, 335), a, 68, 17, 32);
  }

  /// Draws a tapered "balloon" limb as the hull of two circles; returns tip.
  Offset _arm(
    Canvas canvas,
    Offset c1,
    double ang,
    double len,
    double r1,
    double r2,
  ) {
    final c2 = c1 + Offset(math.cos(ang), math.sin(ang)) * len;
    final phi = math.acos((r1 - r2) / len);
    Offset pt(Offset c, double r, double a) =>
        c + Offset(math.cos(a), math.sin(a)) * r;
    final p1a = pt(c1, r1, ang + phi), p2a = pt(c2, r2, ang + phi);
    final p1b = pt(c1, r1, ang - phi);
    final path = Path()
      ..moveTo(p1a.dx, p1a.dy)
      ..lineTo(p2a.dx, p2a.dy)
      ..arcTo(
        Rect.fromCircle(center: c2, radius: r2),
        ang + phi,
        -2 * phi,
        false,
      )
      ..lineTo(p1b.dx, p1b.dy)
      ..arcTo(
        Rect.fromCircle(center: c1, radius: r1),
        ang - phi,
        -(2 * math.pi - 2 * phi),
        false,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..shader = _redGrad.createShader(path.getBounds()),
    );
    // shoulder seam
    canvas.drawArc(
      Rect.fromCircle(center: c1, radius: r1 + 1),
      ang + math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x44A30D16),
    );
    // gloss on the hand
    canvas.save();
    canvas.translate(c2.dx - r2 * 0.3, c2.dy - r2 * 0.45);
    canvas.rotate(-0.7);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r2 * 0.9, height: r2 * 0.32),
      Paint()..color = const Color(0x88FFFFFF),
    );
    canvas.restore();
    return c2;
  }

  // action lines
  void _burst(
    Canvas c,
    Offset o,
    double a0,
    double spread,
    double alpha, {
    int n = 3,
    double inner = 14,
    double outer = 30,
  }) {
    if (alpha <= 0.03) return;
    final p = Paint()
      ..color = _a(const Color(0xFFFFD21F), alpha)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final a = a0 + (i - (n - 1) / 2) * spread;
      final d = Offset(math.cos(a), math.sin(a));
      c.drawLine(o + d * inner, o + d * outer, p);
    }
  }

  // lasers
  void _lasers(Canvas canvas) {
    if (pose.laser <= 0 || pose.targets.isEmpty) return;
    final src = _groupPoint(_orb);
    for (var i = 0; i < pose.targets.length; i++) {
      final dst = pose.targets[i];
      final flick = 0.8 + 0.2 * math.sin(pose.time * 22 + i * 1.7);
      final k = pose.laser * flick;
      final dir = dst - src;
      final len = dir.distance;
      if (len < 1) continue;
      final n = Offset(-dir.dy, dir.dx) / len;

      Path beam(double w0, double w1) => Path()
        ..moveTo(src.dx + n.dx * w0, src.dy + n.dy * w0)
        ..lineTo(dst.dx + n.dx * w1, dst.dy + n.dy * w1)
        ..lineTo(dst.dx - n.dx * w1, dst.dy - n.dy * w1)
        ..lineTo(src.dx - n.dx * w0, src.dy - n.dy * w0)
        ..close();

      canvas.drawPath(
        beam(9, 5),
        Paint()
          ..color = _a(laserColor, 0.45 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        beam(2.4, 1.2),
        Paint()
          ..shader = ui.Gradient.linear(src, dst, [
            _a(Colors.white, k),
            _a(laserColor, 0.9 * k),
          ]),
      );
      for (var j = 0; j < 3; j++) {
        final u = (pose.time * 1.4 + j / 3 + i * 0.19) % 1.0;
        canvas.drawCircle(
          Offset.lerp(src, dst, u)!,
          3.2 * (1 - u * 0.4),
          Paint()..color = _a(Colors.white, 0.9 * k),
        );
      }
      _impact(canvas, dst, k, i);

      if (i < pose.labels.length && pose.labels[i].isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: pose.labels[i],
            style: const TextStyle(
              color: Color(0xFF0B1F3A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final c = dst + dir / len * 30;
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c,
            width: tp.width + 14,
            height: tp.height + 8,
          ),
          const Radius.circular(10),
        );
        canvas.drawRRect(
          r,
          Paint()..color = _a(Colors.white, 0.92 * pose.laser),
        );
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _impact(Canvas canvas, Offset p, double k, int i) {
    final t = pose.time;
    canvas.drawCircle(
      p,
      20,
      Paint()
        ..color = _a(laserColor, 0.5 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final ring = (t * 1.2 + i * 0.31) % 1.0;
    canvas.drawCircle(
      p,
      8 + ring * 24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _a(laserColor, (1 - ring) * 0.8 * k),
    );
    final r = 13 + 3 * math.sin(t * 9 + i);
    final star = Path();
    for (var j = 0; j < 8; j++) {
      final rad = j.isEven ? r : r * 0.28;
      final a = t * 2 + j * math.pi / 4;
      final pt = p + Offset(math.cos(a), math.sin(a)) * rad;
      if (j == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = _a(Colors.white, 0.95 * k));
  }

  @override
  bool shouldRepaint(covariant EdutainerPainter old) => true;
}*/
