import 'package:bubble/core/presentation/widgets/hud_button.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'audio_generation/sound_sfx.dart';
import 'core/presentation/widgets/space_background.dart';
import 'features/curio/presentation/widgets/curio_timer.dart';
import 'features/game/presentation/bubble_game.dart';

/// Point d'entree principal de l'application.
/// Initialise les liaisons systeme, les effets audio et lance l'ecran de jeu.
Future<void> main() async {
  // Garantit l'initialisation correcte du moteur Flutter avant tout appel asynchrone.
  WidgetsFlutterBinding.ensureInitialized();

  // Active le mode plein ecran immersif pour masquer la barre de statut et la barre de navigation.
  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Initialise les effets sonores proceduraux geres par SoLoud.
  await SoundEffects.init();

  // Instance unique du jeu coordonnant la boucle Flame, la physique et les entites.
  final game = BubbleGame();

  // Lance l'application avec un fond d'etoiles spatial et le canvas Flame transparent.
  runApp(
    MaterialApp(
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
                  ),
                ),
              ),
            },
          ),
        ),
      ),
    ),
  );
}
