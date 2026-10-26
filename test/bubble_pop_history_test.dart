import 'package:bubble/features/game/domain/services/bubble_pop_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BubblePopHistory', () {
    test('preserves pop order and associates knowledge with the target', () {
      final history = BubblePopHistory();

      history.record(id: 1, content: 'Wrong', knowledge: const []);
      history.record(
        id: 2,
        content: 'Correct',
        knowledge: const ['first fact'],
      );

      expect(history.length, 2);
      expect(history[0].content, 'Wrong');
      expect(history[0].knowledge, isEmpty);
      expect(history[1].content, 'Correct');
      expect(history[1].knowledge, ['first fact']);
    });

    test('records each Flame bubble only once', () {
      final history = BubblePopHistory();

      expect(
        history.record(id: 4, content: 'Answer', knowledge: const []),
        isTrue,
      );
      expect(
        history.record(
          id: 4,
          content: 'Answer again',
          knowledge: const ['duplicate'],
        ),
        isFalse,
      );
      expect(history.length, 1);
      expect(history[0].content, 'Answer');
    });

    test('clears records and allows ids to be reused in a new session', () {
      final history = BubblePopHistory()
        ..record(id: 1, content: 'Old', knowledge: const []);

      history.clear();

      expect(history.length, 0);
      expect(
        history.record(id: 1, content: 'New', knowledge: const []),
        isTrue,
      );
    });
  });
}
