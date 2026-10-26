import 'package:flutter/material.dart';

import '../../application/controllers/game_controller.dart';
import '../../../../core/presentation/widgets/hud_button.dart';

/// Flutter overlay showing the skip button during the knowledge dispersal phase.
class AccelerateOverlay extends StatelessWidget {
  const AccelerateOverlay({required this.controller, super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 130, left: 18),
      child: HudButton(
        label: 'Skip',
        icon: Icons.skip_next,
        onPressed: controller.accelerateKnowledge,
        scale: 1,
      ),
    ),
  );
}
