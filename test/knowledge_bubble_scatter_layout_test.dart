import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bubble/features/game/views/presentation/components/knowledge_bubble_scatter.dart';

void main() {
  group('KnowledgeBubbleScatterLayout', () {
    for (final gameSize in [
      Vector2(800, 600),
      Vector2(320, 500),
      Vector2(240, 320),
    ]) {
      for (final bubbleCount in [1, 4, 5, 12, 21]) {
        test('keeps $bubbleCount bubbles separated and inside $gameSize', () {
          final layout = KnowledgeBubbleScatterLayout.calculate(
            gameSize: gameSize,
            bubbleCount: bubbleCount,
          );

          expect(layout.centers, hasLength(bubbleCount));
          for (var i = 0; i < layout.centers.length; i++) {
            final center = layout.centers[i];
            expect(center.x - layout.diameter / 2, greaterThanOrEqualTo(0));
            expect(
              center.x + layout.diameter / 2,
              lessThanOrEqualTo(gameSize.x),
            );
            expect(center.y - layout.diameter / 2, greaterThanOrEqualTo(0));
            expect(
              center.y + layout.diameter / 2,
              lessThanOrEqualTo(gameSize.y),
            );

            for (var j = i + 1; j < layout.centers.length; j++) {
              expect(
                (center - layout.centers[j]).length,
                greaterThanOrEqualTo(layout.diameter),
              );
            }
          }
        });
      }
    }

    test('returns an empty layout for no bubbles', () {
      final layout = KnowledgeBubbleScatterLayout.calculate(
        gameSize: Vector2(800, 600),
        bubbleCount: 0,
      );

      expect(layout.centers, isEmpty);
      expect(layout.diameter, 0);
    });

    test('rejects a negative bubble count', () {
      expect(
        () => KnowledgeBubbleScatterLayout.calculate(
          gameSize: Vector2(800, 600),
          bubbleCount: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}
