import '../models/popped_bubble_record.dart';

/// Keeps the first pop for each Flame bubble in the order it happened.
class BubblePopHistory {
  final List<PoppedBubbleRecord> _records = [];
  final Set<int> _recordedIds = {};

  int get length => _records.length;

  PoppedBubbleRecord operator [](int index) => _records[index];

  bool record({
    required int id,
    required String content,
    required List<String> knowledge,
  }) {
    if (!_recordedIds.add(id)) return false;
    _records.add(
      PoppedBubbleRecord(id: id, content: content, knowledge: knowledge),
    );
    return true;
  }

  void clear() {
    _records.clear();
    _recordedIds.clear();
  }
}
