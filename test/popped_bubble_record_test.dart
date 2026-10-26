import 'package:flutter_test/flutter_test.dart';

import 'package:bubble/features/game/domain/models/popped_bubble_record.dart';

void main() {
  test('keeps an immutable snapshot of bubble knowledge', () {
    final sourceKnowledge = ['First fact'];
    final record = PoppedBubbleRecord(
      id: 12,
      content: 'Answer',
      knowledge: sourceKnowledge,
    );

    sourceKnowledge.add('Later fact');

    expect(record.id, 12);
    expect(record.content, 'Answer');
    expect(record.knowledge, ['First fact']);
    expect(() => record.knowledge.add('Changed fact'), throwsUnsupportedError);
  });
}
