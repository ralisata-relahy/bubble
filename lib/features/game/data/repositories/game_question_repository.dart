import '../../domain/models/game_question.dart';
import '../game_questions.dart';

/// Contract for accessing game question catalogs.
abstract class GameQuestionRepository {
  /// Retrieves all questions available for gameplay.
  List<GameQuestion> getAllQuestions();
}

/// Static repository implementation loading the bundled question catalog.
class StaticGameQuestionRepository implements GameQuestionRepository {
  const StaticGameQuestionRepository();

  @override
  List<GameQuestion> getAllQuestions() => GameQuestions.all;
}
