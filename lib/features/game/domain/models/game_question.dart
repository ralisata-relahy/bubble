/// Represents a question and its displayed choices and knowledge during a round.
///
/// Choices and knowledge lists are immutable so Flame logic does not rely on
/// mutable dynamic collections.
class GameQuestion {
  /// Creates a question with its choices and associated knowledge notions.
  const GameQuestion({
    required this.prompt,
    required this.answer,
    required this.choices,
    required this.knowledge,
    this.nameAudio,
  });

  /// Question prompt displayed by the laser HUD.
  final String prompt;

  /// Winning answer text that completes the round when hit.
  final String answer;

  /// Choices that appear in answer bubbles at the start of the round.
  final List<String> choices;

  /// Knowledge notions dispersed after popping the correct answer.
  final List<String> knowledge;

  /// Optional asset filename for the spoken answer.
  final String? nameAudio;
}
