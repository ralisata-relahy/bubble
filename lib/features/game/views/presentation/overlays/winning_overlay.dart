import 'package:flutter/material.dart';

import '../../../../../core/presentation/widgets/hud_button.dart';
import '../../../controllers/game_controller.dart';

/// Flutter overlay shown when the player wins a round.
class WinningOverlay extends StatelessWidget {
  const WinningOverlay({required this.controller, super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.black.withAlpha(45)),
    width: double.infinity,
    height: double.infinity,
    child: Stack(
      children: [
        Center(
          child: HudButton(
            label: 'Next level',
            icon: Icons.navigate_next,
            onPressed: controller.restartGame,
            alignment: Alignment.center,
            scale: 1,
          ),
        ),
      ],
    ),
  );
}
