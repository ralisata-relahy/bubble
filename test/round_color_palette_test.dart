import 'dart:math';

import 'package:bubble/features/game/domain/rules/round_color_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoundColorPalette', () {
    test('selects unique colors within the same round', () {
      final palette = RoundColorPalette(random: Random(42));
      final chosenColors = <Color>{};

      for (var i = 0; i < 4; i++) {
        final color = palette.nextColor();
        expect(chosenColors.contains(color), isFalse);
        chosenColors.add(color);
      }
      expect(chosenColors.length, 4);
    });

    test('avoids previous round colors when possible', () {
      final palette = RoundColorPalette(random: Random(123));
      final round1Colors = <Color>{};

      for (var i = 0; i < 3; i++) {
        round1Colors.add(palette.nextColor());
      }

      palette.startNextRound();

      for (var i = 0; i < 3; i++) {
        final color = palette.nextColor();
        // Since there are 18 Material primary colors, round 2 shouldn't pick round 1 colors
        expect(round1Colors.contains(color), isFalse);
      }
    });

    test('reset clears color history', () {
      final palette = RoundColorPalette(random: Random(7));
      palette.nextColor();
      palette.startNextRound();
      palette.reset();

      // Palette should function normally after reset
      expect(palette.nextColor(), isA<Color>());
    });
  });
}
