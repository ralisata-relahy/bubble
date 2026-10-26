import 'dart:ui';

import 'package:bubble/features/bubble/models/bubble_style.dart';

import 'sphere_renderer.dart';

/// Abstract rendering contract for a bubble.
/// Instantiates the specialised renderer for the requested shape.
abstract class BubbleRenderer {
  /// Creates an appropriate renderer matching the bubble's style.
  factory BubbleRenderer(BubbleStyle s) => switch (s.shape) {
    BubbleShape.sphere || BubbleShape.ellipsoid => SphereRenderer(s),
  };

  /// Advances internal rendering animations (iridescence, reflections).
  void update(double dt);

  /// Draws the translucent body and bubble background (before the text layer).
  void paintBody(Canvas canvas);

  /// Draws specular gloss, glows, and outlines (after the text layer).
  void paintGloss(Canvas canvas);
}
