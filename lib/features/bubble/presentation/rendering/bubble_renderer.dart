import 'dart:ui';

import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'sphere_renderer.dart';

/// Contrat abstrait de rendu d'une bulle.
/// Instancie le moteur de rendu specialise selon la forme demandee.
abstract class BubbleRenderer {
  /// Fabrique un moteur de rendu approprie au style de la bulle.
  factory BubbleRenderer(BubbleStyle s) => switch (s.shape) {
        BubbleShape.sphere || BubbleShape.ellipsoid => SphereRenderer(s),
      };

  /// Fait progresser les animations internes de rendu (iridescence, reflets).
  void update(double dt);

  /// Dessine le corps translucide et l'arriere-plan de la bulle (avant le texte).
  void paintBody(Canvas canvas);

  /// Dessine les reflets brillants, lueurs et contours (apres le texte).
  void paintGloss(Canvas canvas);
}