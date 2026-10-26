import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Manages laser heat glow, thermal dissipation, and bubble inflation.
class BubbleHeatEffect {
  BubbleHeatEffect();

  Offset _hitNormal = Offset.zero;
  double _heatIntensity = 0.0;
  double _hitTimeToLive = 0.0;
  double _inflationScale = 1.0;

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

  /// Current scale multiplier due to thermal inflation.
  double get inflationScale => _inflationScale;

  /// Normalized offset of the laser impact point.
  Offset get hitNormal => _hitNormal;

  /// Resets the heat effect state.
  void reset() {
    _hitNormal = Offset.zero;
    _heatIntensity = 0.0;
    _hitTimeToLive = 0.0;
    _inflationScale = 1.0;
  }

  /// Registers a laser contact point and normal.
  void registerHit(Offset normal) {
    _hitNormal = normal;
  }

  /// Updates heat dissipation over time.
  void update(double dt) {
    if (_hitTimeToLive > 0) {
      _hitTimeToLive -= dt;
    } else {
      _heatIntensity = math.max(0.0, _heatIntensity - dt * 2);
      _inflationScale = math.max(1.0, 1.0 + _heatIntensity * 0.45);
    }
  }

  /// Renders the thermal glow and heated center when heat is present.
  void render({
    required Canvas canvas,
    required Size bubbleSize,
    required Path ovalPath,
  }) {
    if (_heatIntensity <= 0.01) return;

    canvas.save();
    canvas.clipPath(ovalPath);

    final impactPoint = Offset(
      (_hitNormal.dx + 1) * bubbleSize.width / 2,
      (_hitNormal.dy + 1) * bubbleSize.height / 2,
    );
    final radius =
        math.min(bubbleSize.width, bubbleSize.height) *
        (0.3 + 0.2 * _heatIntensity);

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
