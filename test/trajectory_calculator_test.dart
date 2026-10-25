import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:bubble/features/game/presentation/components/trajectory_calculator.dart';

void main() {
  group('TrajectoryCalculator', () {
    test('Calcule un tir en ligne droite sans obstacle', () {
      final origin = Vector2(200, 500);
      final dir = Vector2(0, -1); // Vers le haut

      final result = TrajectoryCalculator.calculate(
        origin: origin,
        initialDirection: dir,
        gameWidth: 400,
        gameHeight: 600,
        potentialTargets: const [],
        maxBounces: 2,
        maxLength: 1000,
      );

      // Le tir part de (200, 500) et s'arrete au plafond (200, 0)
      expect(result.points.length, 2);
      expect(result.points[0], Vector2(200, 500));
      expect(result.points[1].x, closeTo(200, 0.01));
      expect(result.points[1].y, closeTo(0, 0.01));
      expect(result.totalLength, closeTo(500, 0.01));
    });

    test('Effectue un ricochet sur le mur gauche', () {
      final origin = Vector2(100, 500);
      // Direction a 45 degres vers le haut-gauche (-1, -1)
      final dir = Vector2(-1, -1).normalized();

      final result = TrajectoryCalculator.calculate(
        origin: origin,
        initialDirection: dir,
        gameWidth: 400,
        gameHeight: 600,
        potentialTargets: const [],
        maxBounces: 2,
        maxLength: 1000,
      );

      // Rebondit sur x=0 a y=400, puis repart vers x > 0 (haut-droite) jusqu'au plafond y=0
      expect(result.points.length, 3);
      expect(result.points[0], Vector2(100, 500));
      // Point de ricochet sur le mur gauche
      expect(result.points[1].x, closeTo(0, 0.01));
      expect(result.points[1].y, closeTo(400, 0.01));
      // Fin au plafond y=0 (x = 0 + 400 = 400)
      expect(result.points[2].x, closeTo(400, 0.01));
      expect(result.points[2].y, closeTo(0, 0.01));
    });

    test('Effectue un double ricochet gauche puis droite', () {
      final origin = Vector2(50, 600);
      // Tir tres incline vers la gauche
      final dir = Vector2(-1, -0.5).normalized();

      final result = TrajectoryCalculator.calculate(
        origin: origin,
        initialDirection: dir,
        gameWidth: 200,
        gameHeight: 800,
        potentialTargets: const [],
        maxBounces: 2,
        maxLength: 2000,
      );

      // Doit comporter au moins 3 segments (depart -> mur gauche -> mur droit -> fin)
      expect(result.points.length, greaterThanOrEqualTo(3));
      expect(result.points[1].x, closeTo(0, 0.01)); // Mur gauche
      expect(result.points[2].x, closeTo(200, 0.01)); // Mur droit
    });
  });
}
