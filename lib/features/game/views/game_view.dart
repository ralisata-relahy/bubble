import 'package:bubble/features/game/views/presentation/overlays/speaking_word_overlay.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../core/presentation/widgets/space_background.dart';
import '../../curio/presentation/widgets/curio_timer.dart';
import 'presentation/bubble_game.dart';
import 'presentation/overlays/accelerate_overlay.dart';
import 'presentation/overlays/game_over_overlay.dart';
import 'presentation/overlays/winning_overlay.dart';

/// Primary Flutter View for the Bubble game screen.
///
/// Composes the deep space background canvas, the Flame real-time game world,
/// and reactive Flutter HUD overlays for character status, timers, and game-end screens.
class GameView extends StatelessWidget {
  const GameView({super.key, required this.game});

  /// The active Flame game coordinator instance.
  final BubbleGame game;

  @override
  Widget build(BuildContext context) {
    final gameController = game.gameController;

    return Scaffold(
      body: SpaceBackground(
        groundStars: 50,
        seed: 1000,
        density: 5,
        child: GameWidget<BubbleGame>(
          game: game,
          overlayBuilderMap: {
            BubbleGame.curioOverlay: (context, game) =>
                CurioOverlay(game: game),
            BubbleGame.accelerateOverlay: (_, _) =>
                AccelerateOverlay(controller: gameController),
            BubbleGame.gameOverOverlay: (_, _) =>
                GameOverOverlay(controller: gameController),
            BubbleGame.winingOverlay: (_, _) =>
                WinningOverlay(controller: gameController),
            BubbleGame.speakingWordOverlay: (_, game) => SpeakingWordOverlay(controller: gameController, game: game)
          },
        ),
      ),
    );
  }
}
