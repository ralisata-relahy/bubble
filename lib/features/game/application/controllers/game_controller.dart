import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../contracts/game_command_port.dart';

/// Observable session state and high-level commands used by Flutter.
class GameController extends GetxController {
  final won = false.obs;
  final gameOver = false.obs;
  final completedRounds = 0.obs;
  final isCriticalNotifier = ValueNotifier<bool>(false);
  final isTimerPausedNotifier = ValueNotifier<bool>(false);

  GameCommandPort? _game;

  bool get isWon => won.value;
  bool get isGameOver => gameOver.value;

  void attachGame(GameCommandPort game) => _game = game;

  void detachGame(GameCommandPort game) {
    if (identical(_game, game)) _game = null;
  }

  void restartGame() => _game?.restartGame();

  void accelerateKnowledge() => _game?.accelerateKnowledge();

  /// Returns false if the current session is already in a terminal state.
  bool completeRound() {
    if (isWon || isGameOver) return false;
    won.value = true;
    return true;
  }

  void startNextRound() {
    completedRounds.value++;
    won.value = false;
    gameOver.value = false;
  }

  void finishGame() {
    won.value = true;
    gameOver.value = false;
  }

  void markGameOver() {
    gameOver.value = true;
    won.value = false;
  }

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
