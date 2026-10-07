import 'dart:math';
import 'dart:ui' show Size;

import 'package:flame/components.dart';

import 'bubble_style.dart';

enum BubbleDirection { leftToRight, rightToLeft, bottomToTop, topToBottom }

class BubbleConfig {
  const BubbleConfig({
    this.style = const BubbleStyle(),
    this.text = '',
    this.speed = 15,
    this.direction = BubbleDirection.leftToRight,
    this.customDirection,
    this.waveAmplitude = 5,
    this.waveFrequency = 1.5,
    this.breathAmplitude = 0.04,
    this.breathSpeed = 1.2,
    this.maxLines = 3,
    this.autoFit = true,
  });

  final BubbleStyle style;
  final String text;
  final double speed;
  final BubbleDirection direction;
  final Vector2? customDirection;
  final double waveAmplitude;
  final double waveFrequency;
  final double breathAmplitude;
  final double breathSpeed;
  final int maxLines;
  final bool autoFit;

  Vector2 get directionVector {
    final custom = customDirection;
    if (custom != null && custom.length2 > 0) return custom.normalized();
    return switch (direction) {
      BubbleDirection.leftToRight => Vector2(1, 0),
      BubbleDirection.rightToLeft => Vector2(-1, 0),
      BubbleDirection.bottomToTop => Vector2(0, -1),
      BubbleDirection.topToBottom => Vector2(0, 1),
    };
  }

  factory BubbleConfig.random(Random rng, {BubbleDirection? direction}) {
    final w = 80 + rng.nextDouble() * 80;
    return BubbleConfig(
      style: BubbleStyle(
        shape: BubbleShape.values[rng.nextInt(BubbleShape.values.length)],
        size: Size(w, w * (0.7 + rng.nextDouble() * 0.3)),
      ),
      speed: 10 + rng.nextDouble() * 30,
      direction: direction ??
          BubbleDirection.values[rng.nextInt(BubbleDirection.values.length)],
      waveAmplitude: 3 + rng.nextDouble() * 10,
      waveFrequency: 1 + rng.nextDouble(),
      breathSpeed: 0.8 + rng.nextDouble(),
    );
  }
}