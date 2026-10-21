/// État minimum du jeu nécessaire au cycle de vie des bulles de connaissance.
///
/// Ce contrat évite aux composants de bulle de dépendre de l'implémentation
/// concrète de `BubbleGame`.
abstract interface class KnowledgeBubbleHost {
  /// Indique si les bulles de réponse sont suspendues pendant la transition.
  bool get isFrozen;

  /// Temps écoulé depuis le début de la transition courante.
  double get elapsedFreezeTime;

  /// Hauteur à laquelle les bulles de réponse réapparaissent après être sorties.
  double get bubbleRespawnY;
}
