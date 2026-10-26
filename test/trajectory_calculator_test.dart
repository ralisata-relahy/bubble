import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:bubble/features/game/presentation/components/trajectory_calculator.dart';

void main() {
  group('TrajectoryCalculator', () {
    test('calculates straight shot without obstacles', () {
      final origin = Vector2(200, 500);
      final dir = Vector2(0, -1); // Upward

      final result = TrajectoryCalculator.calculate(
        origin: origin,
        initialDirection: dir,
        gameWidth: 400,
        gameHeight: 600,
        potentialTargets: const [],
        maxBounces: 2,
        maxLength: 1000,
      );

      // Shot starts at (200, 500) and ends at ceiling (200, 0)
      expect(result.points.length, 2);
      expect(result.points[0], Vector2(200, 500));
      expect(result.points[1].x, closeTo(200, 0.01));
      expect(result.points[1].y, closeTo(0, 0.01));
      expect(result.totalLength, closeTo(500, 0.01));
    });

    test('bounces off left wall', () {
      final origin = Vector2(100, 500);
      // Direction 45 degrees toward top-left (-1, -1)
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

      // Bounces on x=0 at y=400, then continues toward x > 0 up to ceiling y=0
      expect(result.points.length, 3);
      expect(result.points[0], Vector2(100, 500));
      // Bounce point on left wall
      expect(result.points[1].x, closeTo(0, 0.01));
      expect(result.points[1].y, closeTo(400, 0.01));
      // Terminus at ceiling y=0 (x = 0 + 400 = 400)
      expect(result.points[2].x, closeTo(400, 0.01));
      expect(result.points[2].y, closeTo(0, 0.01));
    });

    test('performs double bounce off left then right wall', () {
      final origin = Vector2(50, 600);
      // Highly inclined shot to the left
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

      // Must comprise at least 3 segments (origin -> left wall -> right wall -> end)
      expect(result.points.length, greaterThanOrEqualTo(3));
      expect(result.points[1].x, closeTo(0, 0.01)); // Left wall
      expect(result.points[2].x, closeTo(200, 0.01)); // Right wall
    });
  });
}
