import 'package:flutter/material.dart';

import 'character_time_gauge.dart';
import '../../../game/presentation/bubble_game.dart';

/// Place Curio et sa jauge dans l'overlay Flutter au-dessus du canvas Flame.
class CurioOverlay extends StatelessWidget {
  /// L'instance du jeu fournit la clé de jauge et le comportement à expiration.
  const CurioOverlay({required this.game, super.key});

  /// Jeu dont l'état est contrôlé par cette jauge.
  final BubbleGame game;

 @override
Widget build(BuildContext context) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  final safeArea = MediaQuery.paddingOf(context);
  final availableHeight = screenHeight - safeArea.top - safeArea.bottom;

  return SafeArea(
    child: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100, top: 8),
        child: CharacterTimeGauge(
          key: game.gaugeKey,
          duration: const Duration(seconds: 30),
          barHeight: availableHeight - 230, // personnage (94) + marge haute (8)
          barWidth: 15,
          characterSize: const Size(90, 94),
          onFinished: game.onTimeUp,
        ),
      ),
    ),
  );
}
}
