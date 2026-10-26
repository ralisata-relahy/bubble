import 'dart:math';

import 'package:flutter/material.dart';

/// Manages round color selection for game answer bubbles.
///
/// Ensures vibrant, non-repeated primary colors within the same round,
/// while avoiding colors used in the immediately preceding round when possible.
class RoundColorPalette {
  /// Creates a round color palette with an optional [Random] source.
  RoundColorPalette({Random? random}) : _random = random ?? Random();

  final Random _random;
  Set<Color> _previousRoundColors = {};
  final Set<Color> _roundColors = {};

  /// Prepares the palette for a new round, archiving the colors of the finished round.
  void startNextRound() {
    _previousRoundColors = Set<Color>.of(_roundColors);
    _roundColors.clear();
  }

  /// Resets all palette history for a fresh game session.
  void reset() {
    _previousRoundColors.clear();
    _roundColors.clear();
  }

  /// Selects a distinct primary color not yet used in the current round.
  Color nextColor() {
    var availableColors = Colors.primaries
        .where(
          (color) =>
              !_previousRoundColors.contains(color) &&
              !_roundColors.contains(color),
        )
        .toList();

    // Fall back to any color not yet used in this round if all primaries were exhausted.
    if (availableColors.isEmpty) {
      availableColors = Colors.primaries
          .where((color) => !_roundColors.contains(color))
          .toList();
    }

    // Safety fallback if round choices exceed the number of primary colors.
    if (availableColors.isEmpty) {
      availableColors = Colors.primaries.toList();
    }

    final color = availableColors[_random.nextInt(availableColors.length)];
    _roundColors.add(color);
    return color;
  }
}
