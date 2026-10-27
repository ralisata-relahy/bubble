import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../contracts/game_command_port.dart';

/// Application GetX controller managing observable session state and high-level commands.
///
/// Serves as the single source of truth for round progress, victory/defeat status,
/// and reactive UI indicators. Communicates with Flame via [GameCommandPort].
class GameController extends GetxController {
  /// True when the current round or entire game has been won.
  final won = false.obs;

  /// True when game over has occurred due to time expiration.
  final gameOver = false.obs;

  /// Number of completed rounds in the current session.
  final completedRounds = 0.obs;

  /// Notifier driving the flashing warning border when time is running low.
  final isCriticalNotifier = ValueNotifier<bool>(false);

  /// Notifier signalling whether the game timer is currently paused.
  final isTimerPausedNotifier = ValueNotifier<bool>(false);

  GameCommandPort? _game;

  // cage control
  static const initialBarCount = 5;
  final isCaged=false.obs;
  final barreCount=initialBarCount.obs;

  /// Whether the session is currently in a won state.
  bool get isWon => won.value;

  /// Whether the session is currently in a game over state.
  bool get isGameOver => gameOver.value;

  /// Attaches the active Flame game command port.
  void attachGame(GameCommandPort game) => _game = game;

  /// Detaches the Flame game command port when game is removed or torn down.
  void detachGame(GameCommandPort game) {
    if (identical(_game, game)) _game = null;
  }

  /// Sends a high-level command to restart the game world.
  void restartGame() => _game?.restartGame();

  /// Sends a command to accelerate knowledge dispersal animation.
  void accelerateKnowledge() => _game?.accelerateKnowledge();

   /// Demande au jeu d'afficher l'écran du mot à prononcer.
  void speakWordScreen() => _game?.speakWordScreen();

  /// Demande au jeu de terminer l'écran du mot et d'afficher la victoire.
  void finishSpeakingWord() => _game?.finishSpeakingWord();

  /// Marks the current round as complete.
  ///
  /// Returns false if the game is already in a terminal state (won or over).
  bool completeRound() {
    if (isWon || isGameOver) return false;
    won.value = true;
    return true;
  }

  /// Advances session state to the next round.
  void startNextRound() {
    completedRounds.value++;
    won.value = false;
    gameOver.value = false;
  }
  
  void decrementeBarCount(){
    if (barreCount.value<=0)return;
    barreCount.value--;
  }
  /// Marks the entire multi-round session as completed and won.
  void finishGame() {
    won.value = true;
    gameOver.value = false;
  }

  /// Marks the session as lost due to timeout.
  void markGameOver() {
    gameOver.value = true;
    won.value = false;
  }

  /// Resets all observable session values for a new game run.
  void reset() {
    won.value = false;
    gameOver.value = false;
    completedRounds.value = 0;
    isCriticalNotifier.value = false;
    isTimerPausedNotifier.value = false;
  }

  @override
  void onClose() {
    _game = null;
    isCriticalNotifier.dispose();
    isTimerPausedNotifier.dispose();
    super.onClose();
  }
}
