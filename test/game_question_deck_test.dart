import 'dart:math';

import 'package:bubble/features/game/domain/game_question_deck.dart';
import 'package:bubble/features/game/domain/models/game_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const questions = [
    GameQuestion(
      prompt: 'First?',
      answer: 'First',
      choices: ['First'],
      knowledge: ['first'],
    ),
    GameQuestion(
      prompt: 'Second?',
      answer: 'Second',
      choices: ['Second'],
      knowledge: ['second'],
    ),
  ];

  group('GameQuestionDeck', () {
    test('selects a question and avoids an immediate repeat', () {
      final deck = GameQuestionDeck(questions: questions, random: Random(1));

      final first = deck.selectNext();
      final firstIndex = deck.currentIndex;
      final second = deck.selectNext(excludingIndex: firstIndex);

      expect(deck.current, same(second));
      expect(second, isNot(same(first)));
      expect(deck.currentIndex, isNot(firstIndex));
    });

    test('selects the only question even when it is excluded', () {
      final deck = GameQuestionDeck(questions: [questions.first]);

      expect(deck.selectNext(excludingIndex: 0), same(questions.first));
      expect(deck.current, same(questions.first));
      expect(deck.currentIndex, 0);
    });

    test('rejects an empty question list', () {
      expect(() => GameQuestionDeck(questions: const []), throwsArgumentError);
    });
  });
}
