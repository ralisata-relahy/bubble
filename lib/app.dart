import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/presentation/widgets/space_background.dart';
import 'features/curio/presentation/widgets/curio_timer.dart';
import 'features/game/application/bindings/game_binding.dart';
import 'features/game/presentation/bubble_game.dart';
import 'features/game/presentation/overlays/accelerate_overlay.dart';
import 'features/game/presentation/overlays/game_over_overlay.dart';
import 'features/game/presentation/overlays/winning_overlay.dart';

/// Widget racine de l'application.
/// Construit le MaterialApp, le fond d'etoiles spatial et le canvas Flame
/// avec tous les overlays du jeu (curio, skip, game over, victoire).
class BubbleApp extends StatelessWidget {
  const BubbleApp({super.key, required this.game});

  /// Instance unique du jeu coordonnant la boucle Flame, la physique et les entites.
  final BubbleGame game;

  @override
  Widget build(BuildContext context) {
    final gameController = game.gameController;

    return GetMaterialApp(
      initialBinding: GameBinding(gameController),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
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
            },
          ),
        ),
      ),
    );
  }
}
