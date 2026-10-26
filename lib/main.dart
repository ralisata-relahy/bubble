import 'package:bubble/core/services/audio/sound_effect.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/game/controllers/game_controller.dart';
import 'features/game/presentation/bubble_game.dart';

/// Main application entry point.
///
/// Initializes Flutter system bindings, pre-computes procedural sound effects,
/// instantiates the GetX game controller and Flame game coordinator, and mounts the root widget.
Future<void> main() async {
  // Ensures Flutter engine bindings are initialized before async startup calls.
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes procedural sound effects via audioplayers.
  final soundEffects = SoundEffects();
  await soundEffects.init();

  // Core game controller manages reactive session state and high-level commands.
  final gameController = GameController();
  final game = BubbleGame(
    soundEffects: soundEffects,
    gameController: gameController,
  );

  // Launches the root Flutter application.
  runApp(BubbleApp(game: game));
}
