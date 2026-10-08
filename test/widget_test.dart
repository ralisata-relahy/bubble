import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bubble/features/bubble/presentation/components/bubble.dart';

void main() {
  group('Bubble laser-point targeting', () {
    test('only points inside the bubble are considered hits', () {
      final bubble = Bubble(position: Vector2(100, 100));

      expect(bubble.containsLaserPoint(Vector2(100, 100)), isTrue);
      expect(bubble.containsLaserPoint(Vector2(160, 100)), isTrue);
      expect(bubble.containsLaserPoint(Vector2(160.1, 100)), isFalse);
    });

    test('burst bubbles cannot be targeted by the laser', () {
      final bubble = Bubble(
        position: Vector2(100, 100),
        isBurstBubble: true,
      );

      expect(bubble.containsLaserPoint(Vector2(100, 100)), isFalse);
      expect(bubble.canReceiveLaserHit, isFalse);
    });
  });
}
