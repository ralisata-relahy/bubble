import 'dart:ui';

import 'package:bubble/features/bubble/models/bubble_style.dart';

import 'cube_renderer.dart';
import 'sphere_renderer.dart';

abstract class BubbleRenderer {
  factory BubbleRenderer(BubbleStyle s) => switch (s.shape) {
    BubbleShape.sphere || BubbleShape.ellipsoid => SphereRenderer(s),
    BubbleShape.cube => CubeRenderer(s),
  };

  void update(double dt);
  void paintBody(Canvas canvas);  // bottom (before text)
  void paintGloss(Canvas canvas); // top (after text)
}