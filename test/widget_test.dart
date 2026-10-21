import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_text_helper.dart';

void main() {
  group('Bubble laser-point targeting', () {
    test('only points inside the bubble are considered hits', () {
      final bubble = Bubble(position: Vector2(100, 100));

      expect(bubble.containsLaserPoint(Vector2(100, 100)), isTrue);
      expect(bubble.containsLaserPoint(Vector2(160, 100)), isTrue);
      expect(bubble.containsLaserPoint(Vector2(160.1, 100)), isFalse);
    });

    test('burst bubbles cannot be targeted by the laser', () {
      final bubble = Bubble(position: Vector2(100, 100), isBurstBubble: true);

      expect(bubble.containsLaserPoint(Vector2(100, 100)), isFalse);
      expect(bubble.canReceiveLaserHit, isFalse);
    });
  });

  group('Bubble label fitting', () {
    test('keeps long words together inside the bubble', () {
      final painter = BubbleTextHelper.createTextPainter(
        text: 'extraordinarilylongword',
        style: const TextStyle(fontSize: 32),
        box: const Size(110, 110),
      );

      expect(painter.didExceedMaxLines, isFalse);
      expect(painter.computeLineMetrics(), hasLength(1));
      expect(painter.width, lessThanOrEqualTo(77));
      expect(painter.height, lessThanOrEqualTo(66));
      painter.dispose();
    });

    test('fits all lines of a long answer without truncating it', () {
      final painter = BubbleTextHelper.createTextPainter(
        text: 'A complete answer with several words',
        style: const TextStyle(fontSize: 32),
        box: const Size(110, 110),
        maxLines: 2,
      );

      expect(painter.didExceedMaxLines, isFalse);
      expect(painter.height, lessThanOrEqualTo(66));
      painter.dispose();
    });
  });
}
