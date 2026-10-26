import 'dart:math';
import 'dart:ui' show Size;

import 'package:flame/components.dart';

import 'package:bubble/features/bubble/models/bubble_style.dart';

/// Cardinal movement directions supported by a bubble.
enum BubbleDirection { leftToRight, rightToLeft, bottomToTop, topToBottom }

/// Immutable motion, text, and rendering settings for a bubble component.
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

  /// Uses a normalized custom vector when supplied, otherwise maps [direction].
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

  /// Creates varied motion and appearance settings for previews or prototypes.
  factory BubbleConfig.random(Random rng, {BubbleDirection? direction}) {
    final w = 80 + rng.nextDouble() * 80;
    return BubbleConfig(
      style: BubbleStyle(
        shape: BubbleShape.values[rng.nextInt(BubbleShape.values.length)],
        size: Size(w, w * (0.7 + rng.nextDouble() * 0.3)),
      ),
      speed: 10 + rng.nextDouble() * 30,
      direction:
          direction ??
          BubbleDirection.values[rng.nextInt(BubbleDirection.values.length)],
      waveAmplitude: 3 + rng.nextDouble() * 10,
      waveFrequency: 1 + rng.nextDouble(),
      breathSpeed: 0.8 + rng.nextDouble(),
    );
  }

  /// Returns a copy of this configuration with given values updated.
  BubbleConfig copyWith({
    BubbleStyle? style,
    String? text,
    double? speed,
    BubbleDirection? direction,
    Vector2? customDirection,
    double? waveAmplitude,
    double? waveFrequency,
    double? breathAmplitude,
    double? breathSpeed,
    int? maxLines,
    bool? autoFit,
  }) {
    return BubbleConfig(
      style: style ?? this.style,
      text: text ?? this.text,
      speed: speed ?? this.speed,
      direction: direction ?? this.direction,
      customDirection: customDirection ?? this.customDirection,
      waveAmplitude: waveAmplitude ?? this.waveAmplitude,
      waveFrequency: waveFrequency ?? this.waveFrequency,
      breathAmplitude: breathAmplitude ?? this.breathAmplitude,
      breathSpeed: breathSpeed ?? this.breathSpeed,
      maxLines: maxLines ?? this.maxLines,
      autoFit: autoFit ?? this.autoFit,
    );
  }
}
