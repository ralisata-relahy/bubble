import 'package:bubble/features/game/application/contracts/game_command_port.dart';
import 'package:bubble/features/game/application/bindings/game_binding.dart';
import 'package:bubble/features/game/application/controllers/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeGameCommands implements GameCommandPort {
  int restartCount = 0;
  int accelerateCount = 0;

  @override
  void restartGame() => restartCount++;

  @override
  void accelerateKnowledge() => accelerateCount++;
}

void main() {
  group('GameController', () {
    test('tracks round and game transitions', () {
      final controller = GameController();

      expect(controller.completeRound(), isTrue);
      expect(controller.isWon, isTrue);
      expect(controller.isGameOver, isFalse);
      expect(controller.completeRound(), isFalse);

      controller.startNextRound();

      expect(controller.isWon, isFalse);
      expect(controller.isGameOver, isFalse);
      expect(controller.completedRounds.value, 1);

      controller.markGameOver();
      expect(controller.isGameOver, isTrue);
      expect(controller.isWon, isFalse);

      controller.finishGame();
      expect(controller.isWon, isTrue);
      expect(controller.isGameOver, isFalse);

      controller.onClose();
    });

    test('reset clears all Flutter-observed game values', () {
      final controller = GameController()
        ..completeRound()
        ..startNextRound()
        ..markGameOver();

      controller.reset();

      expect(controller.won.value, isFalse);
      expect(controller.gameOver.value, isFalse);
      expect(controller.completedRounds.value, 0);
      expect(controller.isCriticalNotifier.value, isFalse);
      expect(controller.isTimerPausedNotifier.value, isFalse);

      controller.onClose();
    });

    test('routes app commands to the attached Flame game only', () {
      final controller = GameController();
      final game = _FakeGameCommands();

      controller.attachGame(game);
      controller.restartGame();
      controller.accelerateKnowledge();
      expect(game.restartCount, 1);
      expect(game.accelerateCount, 1);

      controller.detachGame(game);
      controller.restartGame();
      expect(game.restartCount, 1);

      controller.onClose();
    });

    test('binding registers the session controller', () async {
      final controller = GameController();

      GameBinding(controller).dependencies();

      expect(Get.find<GameController>(), same(controller));
      await Get.delete<GameController>(force: true);
    });
  });
}
