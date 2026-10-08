// ignore_for_file: unused_field

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' show Alignment, RadialGradient, SweepGradient;

import '../bubble_style.dart';
import 'bubble_renderer.dart';

/// Animated glass sphere / ellipsoid (2.5D).
/// Drawn in a circle then stretched to `size`.
class SphereRenderer implements BubbleRenderer {
  SphereRenderer(BubbleStyle s)
      : _w = s.size.width,
        _h = s.size.height,
        _r = max(s.size.width, s.size.height) / 2,
        _base = s.baseColor,
        _phase = Random().nextDouble() * 2 * pi {
    final r = _r;
    final c = Offset(r, r);
    _c = c;
    _rect = Rect.fromCircle(center: c, radius: r);
    final base = _base;
    final edge = s.bodyEdgeAlpha;
    final k = s.iridescence;

    // Fresnel: transparent at center, reflective towards edge
    _body = Paint()
      ..shader = RadialGradient(
        colors: [
          base.withValues(alpha: s.bodyCenterAlpha * 0.4),
          base.withValues(alpha: s.bodyMidAlpha + 0.02),
          base.withValues(alpha: edge * 0.7),
          base.withValues(alpha: min(1.0, edge * 1.6)),
        ],
        stops: const [0.0, 0.72, 0.93, 1.0],
      ).createShader(_rect);

    // Volume: side opposite to light darkens
    _shade = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 1.15,
        colors: [Color(0x00000000), Color(0x380A1A33)],
        stops: [0.45, 1.0],
      ).createShader(_rect);

    // Caustic: shader recreated each frame (drifts), cf. update()
    _caustic = Paint();
    _updateCaustic();

    // Main iridescent reflection (rotates slowly)
    _iris = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..shader = SweepGradient(colors: [
        const Color(0xFFFF7BD5).withValues(alpha: 0.5 * k),
        const Color(0xFF6CF0FF).withValues(alpha: 0.5 * k),
        const Color(0xFFFFF27A).withValues(alpha: 0.4 * k),
        const Color(0xFFB07BFF).withValues(alpha: 0.5 * k),
        const Color(0xFFFF7BD5).withValues(alpha: 0.5 * k),
      ]).createShader(_rect);

    // Second iridescent film, thinner, counter-rotating => "oil / soap" effect
    _iris2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..shader = SweepGradient(colors: [
        const Color(0xFF6CF0FF).withValues(alpha: 0.35 * k),
        const Color(0xFFB07BFF).withValues(alpha: 0.35 * k),
        const Color(0xFFFF7BD5).withValues(alpha: 0.3 * k),
        const Color(0xFFFFF27A).withValues(alpha: 0.35 * k),
        const Color(0xFF6CF0FF).withValues(alpha: 0.35 * k),
      ]).createShader(_rect);

    _rimColor = s.rimColor ?? base;
    _rimAlpha = s.rimAlpha;
    _rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.012
      ..color = _rimColor.withValues(alpha: _rimAlpha);

    // Highlights
    _arcTL = _stroke(r * 0.05, base.withValues(alpha: 0.85));
    _arcBR = _stroke(r * 0.05, const Color(0xFFDCEBFF).withValues(alpha: 0.6));
    _specGlow = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5);
    _spec = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95);

    // Direction: top-left, centered on crescent _arcTL (3.3 → 4.6 rad).
    // Drawn in circle coordinates, follows the edge even when bubble
    // is stretched into an oval.
    const theta = 3.95;
    _specTheta = theta;

    // Compensated thickness for ovals (stretching thins reflection)
    final sx = _w / (2 * r), sy = _h / (2 * r);
    final radialScale = sqrt(pow(cos(theta) * sx, 2) + pow(sin(theta) * sy, 2));
    final thick = (1 / radialScale).clamp(1.0, 1.8).toDouble();

    const span = 0.85;              // angular span (~49°)
    final mid = r * 0.74;           // arc radius, inside _arcTL (0.9)
    final half = r * 0.055 * thick; // maximum half-thickness

    double hw(double u) => half * pow(sin(pi * pow(u, 0.85)), 0.9).toDouble();
    Offset pt(double u, double rad) {
      final a = (u - 0.5) * span;
      return Offset(cos(a) * rad, sin(a) * rad);
    }

    // Tapered crescent at both ends, around origin (angle 0 = +x)
    const n = 28;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final q = pt(i / n, mid + hw(i / n));
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    for (var i = n; i >= 0; i--) {
      final q = pt(i / n, mid - hw(i / n));
      path.lineTo(q.dx, q.dy);
    }
    path.close();
    _specPath = path;

    _specHot = pt(0.3, mid);  // hot spot in the bulge
    _specDot = pt(1.22, mid); // small dot right after tip
    update(0);
  }

  final double _w, _h, _r;
  final Color _base;
  final double _phase; // offsets bubbles from each other so they are not synchronous
  late final Offset _c;
  late final Rect _rect;
  late final Color _rimColor;
  late final double _rimAlpha;

  double _t = 0;
  double _causticAcc = 0;
  bool _causticReady = false;
  double _sx = 1, _sy = 1; // "breathing" deformation
  double _poke = 0, _pokeT = 99; // impulse (damped spring)

  /// Margin so deformation does not exceed drawing area.
  static const double _margin = 0.94;

  late final Paint _body, _shade, _caustic, _iris, _iris2, _rim;
  late final Paint _arcTL, _arcBR, _spec, _specGlow;
  late final Path _specPath;
  late final Offset _specHot, _specDot;
  late final double _specTheta;

  static Paint _stroke(double w, Color color, {double blur = 0}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = color
    ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

  Rect _arcRect(double f) => Rect.fromCircle(center: _c, radius: _r * f);

  /// Called on touch / collision: bubble "bounces" like jelly.
  void poke([double strength = 1]) {
    _poke = strength.clamp(0.0, 1.5);
    _pokeT = 0;
  }

    void _updateCaustic() {
    // Shader créé une seule fois (le mouvement est fait par le canvas)
    if (_causticReady) return;
    _causticReady = true;
    _caustic.shader = RadialGradient(
      center: const Alignment(0.45, 0.55),
      radius: 0.55,
      colors: [
        _base.withValues(alpha: 0.30),
        _base.withValues(alpha: 0.0),
      ],
    ).createShader(_rect);
  }

  /// Draws in a circle of radius `_r`, stretched to desired size,
  /// with breathing deformation.
  void _fit(Canvas c, void Function() draw) {
    c
      ..save()
      ..translate(_w / 2, _h / 2)
      ..scale(_sx * _margin, _sy * _margin)
      ..scale(_w / (2 * _r), _h / (2 * _r))
      ..translate(-_r, -_r);
    draw();
    c.restore();
  }

  @override
  void update(double dt) {
    _t += dt;
    final p = _t + _phase;

    // Breathing: constant volume squash & stretch (sx * sy ≈ 1)
    var a = 0.022 * sin(p * 2.0) + 0.008 * sin(p * 3.4 + 1.7);
    if (_pokeT < 6) {
      _pokeT += dt;
      a += (_poke * exp(-3.2 * _pokeT) * sin(18 * _pokeT) * 0.12).clamp(-0.12, 0.12);
    }
    _sx = 1 + a;
    _sy = 1 / _sx;

    // Iridescent film pulses
    // _iris.strokeWidth = _r * (0.09 + 0.02 * sin(p * 1.6));
    // _iris2.strokeWidth = _r * (0.05 + 0.012 * sin(p * 2.1 + 1));

    // Edge glimmers slightly
    _rim.color = _rimColor.withValues(alpha: (_rimAlpha * (0.85 + 0.15 * sin(p * 1.8))).clamp(0.0, 1.0));

    _causticAcc += dt;
    if (_causticAcc >= 0.05) {
      _causticAcc = 0;
      _updateCaustic();
    }
  }

  @override
  void paintBody(Canvas c) => _fit(c, () {
    final p = _t + _phase;
    c.drawCircle(_c, _r, _body);
    c.drawCircle(_c, _r, _shade);
        c
      ..save()
      ..translate(_r * 0.05 * sin(p * 0.7), _r * 0.05 * cos(p * 0.9))
      ..drawCircle(_c, _r * 0.97, _caustic)
      ..restore();

    // Iridescent film 1 (clockwise)
    c
      ..save()
      ..translate(_c.dx, _c.dy)
      ..rotate(p * 0.4)
      ..translate(-_c.dx, -_c.dy)
      ..drawCircle(_c, _r * 0.9, _iris)
      ..restore();

    // Iridescent film 2 (counter-clockwise, smaller, different speed)
    c
      ..save()
      ..translate(_c.dx, _c.dy)
      ..rotate(-p * 0.27)
      ..translate(-_c.dx, -_c.dy)
      ..drawCircle(_c, _r * 0.8, _iris2)
      ..restore();

    c.drawCircle(_c, _r * 0.985, _rim);
  });

  @override
  void paintGloss(Canvas c) => _fit(c, () {
    final r = _r;
    final p = _t + _phase;

    // Floating light crescents
    c.drawArc(_arcRect(0.9), 3.3 + 0.08 * sin(p * 0.9), 1.3 + 0.12 * sin(p * 1.4), false, _arcTL);
    c.drawArc(_arcRect(0.92), 0.25 - 0.06 * sin(p * 1.1), 0.95 + 0.1 * sin(p * 1.7), false, _arcBR);

    // Specular reflection: shimmering concentric crescent
    final tw = 0.85 + 0.15 * sin(p * 2.6 + 1);
    const white = Color(0xFFFFFFFF);
    c
      ..save()
      ..translate(_c.dx, _c.dy)
      ..rotate(_specTheta + 0.05 * sin(p * 1.2));

    _spec.color = white.withValues(alpha: 0.95 * tw);
    c.drawPath(_specPath, _spec);             // core
    c.drawCircle(_specHot, r * 0.038, _spec); // hot spot

    _spec.color = white.withValues(alpha: 0.6 * tw);
    c.drawCircle(_specDot, r * 0.022, _spec); // helper point
    c.restore();
  });
}
