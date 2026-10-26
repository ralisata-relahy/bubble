/// Minimum game state contract required for the lifecycle of knowledge bubbles.
///
/// This interface prevents bubble components from directly coupling to the
/// concrete implementation of `BubbleGame`.
abstract interface class KnowledgeBubbleHost {
  /// Indicates whether regular answer bubbles are paused during victory transitions.
  bool get isFrozen;

  /// Elapsed time since the start of the current transition in seconds.
  double get elapsedFreezeTime;

  /// Y-coordinate at which answer bubbles respawn after leaving the screen.
  double get bubbleRespawnY;
}
