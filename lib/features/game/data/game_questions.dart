import '../domain/models/game_question.dart';

/// Catalogue local des questions utilisées par les manches du jeu.
///
/// Les règles de progression restent dans `BubbleGame`; ce fichier ne contient
/// que le contenu éditorial.
abstract final class GameQuestions {
  /// Questions parcourues dans l'ordre, puis reprises depuis le début.
  static const List<GameQuestion> all = [
    GameQuestion(
      prompt: "What does 'hello' mean in French?",
      answer: 'Bonjour',
      choices: ['Bonjour', 'Au revoir', 'À très bientôt', 'Oke', 'Beaucoup'],
      knowledge: ['french', 'English', 'Pananme', 'Beaugosse'],
      nameAudio:'bonjour.mp3'
    ),
    GameQuestion(
      prompt: "What does 'goodbye' mean in French?",
      answer: 'Au revoir',
      choices: ['Bonjour', 'Merci', 'Au revoir', 'Bonsoir', 'Beaucoup'],
      knowledge: ['french', 'English', 'Pananme', 'Beaugosse'],
      nameAudio: 'aurevoir.mp3'
    ),
    GameQuestion(
      prompt: "What does 'thank you' mean in French?",
      answer: 'Merci',
      choices: ['Pardon', 'Merci', 'Bonjour', 'Salut', 'Beaucoup'],
      knowledge: ['french', 'English', 'Pananme', 'Beaugosse'],
      nameAudio: 'thank_you_fr.mp3',
    ),
  ];
}
