import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio_generation/sound_sfx.dart';
import 'core/presentation/widgets/space_background.dart';
import 'features/curio/presentation/widgets/curio_timer.dart';
import 'features/game/presentation/bubble_game.dart';
import 'features/game/presentation/overlays/game_result_overlay.dart';

/// Initialise les dépendances Flutter/audio et lance l'écran principal.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await FlameAudio.audioCache.loadAll([
    'bouble_pop.mp3',
    'false_pop.mp3',
    'e-ho.mp3',
  ]);
  await SoundEffects.init();
  // Une instance unique relie le moteur Flame, l'overlay et les contrôles Flutter.
  final game = BubbleGame();

  // Le fond est dessiné par Flutter sous le canvas Flame transparent.
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SpaceBackground(
          groundStars: 50,seed: 1000,density: 5,
          child: GameWidget<BubbleGame>(
            game: game,
            overlayBuilderMap: {
              BubbleGame.curioOverlay: (context, game) =>
                  CurioOverlay(game: game),
              BubbleGame.victoryOverlay: (context, game) =>
                  GameResultOverlay(didWin: true, onRestart: game.restart),
              BubbleGame.gameOverOverlay: (context, game) =>
                  GameResultOverlay(didWin: false, onRestart: game.restart),
            },
          ),
        ),
      ),
    ),
  );
}
