import 'dart:math' as math;
import 'package:flame/components.dart';

/// Contrat physique pour toute entite de type bulle participant aux collisions.
abstract class BubblePhysicsBody {
  /// Position actuelle dans l'espace du jeu.
  Vector2 get position;

  /// Rayon de collision circulaire.
  double get collisionRadius;

  /// Indique si la bulle peut entrer en collision dans son etat actuel.
  bool get isCollisionActive;

  /// Vecteur unitaire de direction de translation.
  Vector2 get moveDir;

  /// Vecteur unitaire perpendiculaire a la direction pour l'oscillation.
  Vector2 get movePerp;

  /// Position centrale de base (hors deplacement oscillatoire).
  Vector2 get centerBase;

  /// Vitesse de deplacement en pixels par seconde.
  double get speed;

  /// Amplitude de l'oscillation sinusoidale en pixels.
  double get waveAmplitude;

  /// Frequence de l'oscillation sinusoidale en radians par seconde.
  double get waveFrequency;

  /// Temps accumule de l'onde sinusoidale.
  double get waveTime;
  set waveTime(double value);
}

/// Moteur de resolution des collisions et de rebond physique entre bulles.
/// Garantit la continuite spatiale sans teleportation visuelle et un rebond elastique.
class BubbleCollisionResolver {
  BubbleCollisionResolver._();

  /// Coefficient de restitution elastique pour un rebond ferme et naturel.
  static const double _restitution = 1.0;

  /// Distance minimale en dessous de laquelle une direction par defaut est appliquee.
  static const double _epsilon = 0.001;

  /// Verifie et resout la collision elastique entre deux corps de bulle.
  static void resolve(
    BubblePhysicsBody bodyA,
    BubblePhysicsBody bodyB, {
    double padding = 6.0,
  }) {
    // Verifie l'etat actif des deux bulles.
    if (!bodyA.isCollisionActive || !bodyB.isCollisionActive) return;

    final delta = bodyB.position - bodyA.position;
    var distance = delta.length;
    final minDistance = bodyA.collisionRadius + bodyB.collisionRadius + padding;

    // Pas de chevauchement detecte.
    if (distance >= minDistance) return;

    // 1) Calcul du vecteur normal unitaire entre les deux centres.
    Vector2 normal;
    if (distance < _epsilon) {
      final dirDiff = bodyA.moveDir - bodyB.moveDir;
      normal = dirDiff.length > _epsilon ? dirDiff.normalized() : Vector2(1, 0);
      distance = _epsilon;
    } else {
      normal = delta / distance;
    }

    // 2) Separation proportionnelle aux masses (proportionnelles au carre du rayon).
    final overlap = minDistance - distance;
    final massA = bodyA.collisionRadius * bodyA.collisionRadius;
    final massB = bodyB.collisionRadius * bodyB.collisionRadius;
    final totalMass = massA + massB;

    final weightA = massB / totalMass;
    final weightB = massA / totalMass;

    final separationA = normal * (overlap * weightA);
    final separationB = normal * (overlap * weightB);

    bodyA.position.sub(separationA);
    bodyA.centerBase.sub(separationA);

    bodyB.position.add(separationB);
    bodyB.centerBase.add(separationB);

    // 3) Echange des vitesses et impulsion elastique le long de la normale.
    final velocityA = bodyA.moveDir * bodyA.speed;
    final velocityB = bodyB.moveDir * bodyB.speed;

    final vaNormal = velocityA.dot(normal);
    final vbNormal = velocityB.dot(normal);
    final relativeVelocity = vaNormal - vbNormal;

    // Les bulles se rapprochent : on applique l'impulsion de rebond.
    if (relativeVelocity > 0) {
      final impulse =
          (1.0 + _restitution) * relativeVelocity / (1.0 / massA + 1.0 / massB);

      velocityA.sub(normal * (impulse / massA));
      velocityB.add(normal * (impulse / massB));

      // Mise a jour de la bulle A.
      if (velocityA.length > _epsilon) {
        final oldPerpA = bodyA.movePerp.clone();
        bodyA.moveDir.setFrom(velocityA.normalized());
        bodyA.movePerp.setValues(-bodyA.moveDir.y, bodyA.moveDir.x);
        _preserveWaveContinuity(bodyA, oldPerpA);
      }

      // Mise a jour de la bulle B.
      if (velocityB.length > _epsilon) {
        final oldPerpB = bodyB.movePerp.clone();
        bodyB.moveDir.setFrom(velocityB.normalized());
        bodyB.movePerp.setValues(-bodyB.moveDir.y, bodyB.moveDir.x);
        _preserveWaveContinuity(bodyB, oldPerpB);
      }
    }
  }

  /// Recalcule la phase de l'onde pour eliminer toute discontinuite spatiale.
  /// Empeche le saut instantane de position lors du basculement du vecteur orthogonal.
  static void _preserveWaveContinuity(
    BubblePhysicsBody body,
    Vector2 oldPerp,
  ) {
    if (body.waveAmplitude <= _epsilon || body.waveFrequency <= _epsilon) {
      return;
    }

    // Calcule le deplacement ondulatoire precedent.
    final oldWaveOffset = oldPerp *
        (math.sin(body.waveTime * body.waveFrequency) * body.waveAmplitude);

    // Projette le deplacement precedent sur le nouveau vecteur orthogonal.
    final projection = oldWaveOffset.dot(body.movePerp);
    final normalizedScalar = (projection / body.waveAmplitude).clamp(-1.0, 1.0);

    // Deduit l'angle de phase coherent pour la nouvelle orientation.
    final targetAngle = math.asin(normalizedScalar);
    body.waveTime = targetAngle / body.waveFrequency;

    // Ajuste centerBase pour que la somme centerBase + wave reste parfaitement continue.
    final newWaveOffset = body.movePerp *
        (math.sin(body.waveTime * body.waveFrequency) * body.waveAmplitude);
    body.centerBase.setFrom(body.position - newWaveOffset);
  }
}
