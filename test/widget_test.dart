import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_text_helper.dart';
import 'package:bubble/features/curio/character_backup_widget.dart';
import 'package:bubble/features/curio/presentation/widgets/character_time_gauge.dart';

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

    test('declenche onTargetImpact lors dune bonne reponse', () {
      var targetImpactCalled = false;
      var wrongImpactCalled = false;

      final bubble = Bubble(
        position: Vector2(100, 100),
        config: const BubbleConfig(text: 'Bonne'),
        canPop: (text) => text == 'Bonne',
        onTargetImpact: (_) => targetImpactCalled = true,
        onWrongImpact: () => wrongImpactCalled = true,
      );

      bubble.pop();

      expect(targetImpactCalled, isTrue);
      expect(wrongImpactCalled, isFalse);
    });

    test('declenche onWrongImpact lors dune mauvaise reponse', () {
      var targetImpactCalled = false;
      var wrongImpactCalled = false;

      final bubble = Bubble(
        position: Vector2(100, 100),
        config: const BubbleConfig(text: 'Mauvaise'),
        canPop: (text) => text == 'Bonne',
        onTargetImpact: (_) => targetImpactCalled = true,
        onWrongImpact: () => wrongImpactCalled = true,
      );

      bubble.pop();

      expect(targetImpactCalled, isFalse);
      expect(wrongImpactCalled, isTrue);
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

  group('Character time gauge mood', () {
    testWidgets('shows a disappointed mood between 11% and 33% remaining', (
      tester,
    ) async {
      final gaugeKey = GlobalKey<CharacterTimeGaugeState>();

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterTimeGauge(
            key: gaugeKey,
            duration: const Duration(seconds: 30),
            autoStart: false,
          ),
        ),
      );

      gaugeKey.currentState!.addTime(-0.8);
      await tester.pump();

      final character = tester.widget<CharacterBackupWidget>(
        find.byType(CharacterBackupWidget),
      );
      expect(character.mood, Mood.disapointed);
    });

    testWidgets('shows a sad mood at 11% or less remaining', (tester) async {
      final gaugeKey = GlobalKey<CharacterTimeGaugeState>();

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterTimeGauge(
            key: gaugeKey,
            duration: const Duration(seconds: 30),
            autoStart: false,
          ),
        ),
      );

      gaugeKey.currentState!.addTime(-0.9);
      await tester.pump();

      final character = tester.widget<CharacterBackupWidget>(
        find.byType(CharacterBackupWidget),
      );
      expect(character.mood, Mood.sad);
    });
  });
}
