import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'features/game/bindings/game_binding.dart';
import 'features/game/presentation/bubble_game.dart';
import 'features/game/views/game_view.dart';

/// Root application widget.
///
/// Sets up the GetMaterialApp container, initializes GetX dependency bindings,
/// and presents the primary [GameView].
class BubbleApp extends StatelessWidget {
  const BubbleApp({super.key, required this.game});

  /// The active Flame game instance coordinating real-time simulation.
  final BubbleGame game;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialBinding: GameBinding(game.gameController),
      debugShowCheckedModeBanner: false,
      home: GameView(game: game),
    );
  }
}
