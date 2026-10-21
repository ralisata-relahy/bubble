/// Représente une question et les éléments affichés pendant une manche.
///
/// Les listes sont définies comme des constantes dans le catalogue de données
/// du jeu afin que la logique Flame ne dépende pas de cartes dynamiques.
class GameQuestion {
  /// Crée une question avec ses réponses possibles et ses notions associées.
  const GameQuestion({
    required this.prompt,
    required this.answer,
    required this.choices,
    required this.knowledge,
  });

  /// Texte de la question affichée par le laser.
  final String prompt;

  /// Texte de la bulle qui valide la manche.
  final String answer;

  /// Réponses qui apparaissent dans les bulles au début de la manche.
  final List<String> choices;

  /// Notions libérées après une bonne réponse.
  final List<String> knowledge;
}
