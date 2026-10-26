import 'package:flame/components.dart';

import 'package:bubble/core/physics/bubble_collision_resolver.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/bubble/presentation/components/knowledge_bubble.dart';
import 'package:bubble/features/game/configuration/game_configuration.dart';

/// Applies game collision rules after each Flame simulation step.
class BubbleCollisionSystem {
  /// Resolves active bubble pairs, then clamps regular bubbles to the play area.
  void update(Iterable<Component> components, {required bool isFrozen}) {
    final activeBodies = components
        .whereType<BubblePhysicsBody>()
        .where((body) => body.isCollisionActive)
        .toList();

    // Resolve each pair once so a frame cannot apply the same impulse twice.
    for (var i = 0; i < activeBodies.length; i++) {
      for (var j = i + 1; j < activeBodies.length; j++) {
        final bodyA = activeBodies[i];
        final bodyB = activeBodies[j];

        if (isFrozen && _isKnowledgeVsRegular(bodyA, bodyB)) {
          // Dispersing knowledge should gently clear regular bubbles without
          // sending them flying during the victory pause.
          _nudgeRegularBubble(bodyA, bodyB);
        } else {
          BubbleCollisionResolver.resolve(
            bodyA,
            bodyB,
            padding: GameConfiguration.collisionPadding,
          );
        }
      }
    }

    // Collision separation can push regular bubbles beyond the play area.
    for (final bubble in components.whereType<Bubble>()) {
      bubble.keepWithinBounds();
    }
  }

  bool _isKnowledgeVsRegular(BubblePhysicsBody a, BubblePhysicsBody b) =>
      (a is KnowledgeBubbleComponent && b is Bubble) ||
      (a is Bubble && b is KnowledgeBubbleComponent);

  void _nudgeRegularBubble(BubblePhysicsBody a, BubblePhysicsBody b) {
    final regularBubble = (a is Bubble ? a : b) as Bubble;
    final knowledgeBubble =
        (a is KnowledgeBubbleComponent ? a : b) as KnowledgeBubbleComponent;

    final delta = regularBubble.position - knowledgeBubble.position;
    final distance = delta.length;
    final minDistance =
        regularBubble.collisionRadius +
        knowledgeBubble.collisionRadius +
        GameConfiguration.collisionPadding;

    // Skip coincident centers because a separation direction cannot be normalized.
    if (distance < minDistance && distance > 0.001) {
      final overlap = minDistance - distance;
      // Apply only part of the correction to make the visual contact gentle.
      final nudge = (delta / distance) * (overlap * 0.4);
      regularBubble.position.add(nudge);
      regularBubble.centerBase.add(nudge);
    }
  }
}
