import 'package:flutter/material.dart';

import '../../../../../core/presentation/widgets/hud_button.dart';
import '../../../controllers/game_controller.dart';

/// Flutter overlay shown when Curio faints and the round is lost.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.controller, super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withAlpha(45),
    width: double.infinity,
    height: double.infinity,
    child: Center(
      child: Container(
        width: 270,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xB33A8FB7), Color(0xB32A6F96)],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF4FB3E8), width: 3),
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
            const SizedBox(height: 8),
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
              onPressed: controller.restartGame,
              alignment: Alignment.center,
              scale: 0.8,
            ),
            const SizedBox(height: 12),
            HudButton(
              label: 'Skip',
              icon: Icons.skip_next,
              onPressed: controller.restartGame,
              alignment: Alignment.center,
              scale: 0.8,
              color: const Color(0xFF7F72F2),
              secondaryColor: const Color(0xFF5E4FD8),
            ),
          ],
        ),
      ),
    ),
  );
}
