import 'package:bubble/core/physics/bubble_collision_resolver.dart';

/// Gameplay tuning values shared by the game coordinator and its components.
abstract final class GameConfiguration {
  static const winCelebrationDuration = 2.5;
  static const accelerateButtonDelay = 2.0;
  static const accelerationFactor = 5;
  static const gameOverFreezeDuration = 2.0;
  static const roundsPerGame = 2;
  static const collisionPadding = BubbleCollisionResolver.defaultPadding;
  static const bubbleSpeed = 15.0;
  static const bubbleSize = 90.0;
  static const bubbleSpawnHeightFraction = 0.76;
  static const laserTargetHeightFraction = 0.58;
  static const confettiDuration = 3.0;
  static const confettiParticleCount = 90;
  static const wrongAnswerTimePenalty = -0.05;
  static const correctAnswerTimeBonus = 0.1;
  static const criticalTimeThreshold = 0.3;
  static const Duration gameDuration=Duration(seconds: 5);
}
