import 'package:bubble/core/presentation/widgets/hud_button.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'core/presentation/widgets/space_background.dart';
import 'features/curio/presentation/widgets/curio_timer.dart';
import 'features/game/presentation/bubble_game.dart';

/// Widget racine de l'application.
/// Construit le MaterialApp, le fond d'etoiles spatial et le canvas Flame
/// avec tous les overlays du jeu (curio, skip, game over, victoire).
class BubbleApp extends StatelessWidget {
  const BubbleApp({super.key, required this.game});

  /// Instance unique du jeu coordonnant la boucle Flame, la physique et les entites.
  final BubbleGame game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
              // Bouton 1 : accelere la dispersion des bulles de savoir.
              BubbleGame.accelerateOverlay: (context, BubbleGame game) => Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 130, left: 18),
                  child: HudButton(
                    label: 'Skip',
                    icon: Icons.skip_next,
                    onPressed: game.accelerateKnowledge,
                    scale: 1.0,
                  ),
                ),
              ),
              BubbleGame.gameOverOverlay: (context, BubbleGame game) =>
                  Container(
                    color: Colors.black.withAlpha(45),
                    width: double.infinity,
                    height: double.infinity,
                    child: Center(
                      child: Container(
                        width: 270,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xB33A8FB7), Color(0xB32A6F96)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: const Color(0xFF4FB3E8),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4FB3E8).withAlpha(90),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Ooops! Curio fainted',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            HudButton(
                              label: 'Try again',
                              icon: Icons.restart_alt,
                              onPressed: () {
                                game.overlays.remove(
                                  BubbleGame.gameOverOverlay,
                                );
                                 game.restartGame();
                               },
                               alignment: Alignment.center,
                               scale: 0.8,
                             ),
                            const SizedBox(height: 12),
                            HudButton(
                              label: 'Skip',
                              icon: Icons.skip_next,
                              onPressed: () {
                                game.overlays.remove(
                                  BubbleGame.gameOverOverlay,
                                );
                                game.restartGame();
                              },
                               alignment: Alignment.center,
                               scale: 0.8,
                               color: const Color(0xFF7F72F2),
                              secondaryColor: const Color(0xFF5E4FD8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              BubbleGame.winingOverlay: (context, game) => Container(
                decoration: BoxDecoration(color: Colors.black.withAlpha(45)),
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: HudButton(
                    label: 'Next level',
                    icon: Icons.navigate_next,
                    onPressed: () {
                      game.overlays.remove(BubbleGame.winingOverlay);
                      game.restartGame();
                    },
                     alignment: Alignment.center,
                     scale: 1.0,
                   ),
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}
