/// Immutable snapshot of one answer bubble's first laser impact.
class PoppedBubbleRecord {
  /// Creates a record preserving the bubble's order and related knowledge.
  PoppedBubbleRecord({
    required this.id,
    required this.content,
    required List<String> knowledge,
  }) : knowledge = List.unmodifiable(knowledge);

  /// Unique identifier of the source bubble within the game session.
  final int id;

  /// Text shown by the answer bubble.
  final String content;

  /// Knowledge attached to the question solved by this bubble.
  final List<String> knowledge;
}
