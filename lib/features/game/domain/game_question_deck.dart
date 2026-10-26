import 'dart:math';

import 'models/game_question.dart';

/// Selects game questions while avoiding an immediate repeat.
class GameQuestionDeck {
  GameQuestionDeck({required List<GameQuestion> questions, Random? random})
    : _questions = List.unmodifiable(questions),
      _random = random ?? Random() {
    if (_questions.isEmpty) {
      throw ArgumentError.value(questions, 'questions', 'Must not be empty');
    }
  }

  final List<GameQuestion> _questions;
  final Random _random;
  int? _currentIndex;

  /// Index of the currently selected question.
  int get currentIndex {
    final index = _currentIndex;
    if (index == null) {
      throw StateError('Select a question before reading the current index');
    }
    return index;
  }

  /// Currently selected question.
  GameQuestion get current => _questions[currentIndex];

  /// Selects a random question, excluding [excludingIndex] when possible.
  GameQuestion selectNext({int? excludingIndex}) {
    if (_questions.length == 1) {
      _currentIndex = 0;
      return _questions.single;
    }

    final candidates = [
      for (var index = 0; index < _questions.length; index++)
        if (index != excludingIndex) index,
    ];
    _currentIndex = candidates[_random.nextInt(candidates.length)];
    return current;
  }
}
