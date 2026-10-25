import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Particule individuelle de confetti avec physique de chute et scintillement 3D.
class _ConfettiParticle {
  _ConfettiParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.angularVelocity,
    required this.wobbleSpeed,
  });

  Vector2 position;
  Vector2 velocity;
  final Color color;
  final Vector2 size;
  double angle = 0.0;
  final double angularVelocity;
  double wobble = 0.0;
  final double wobbleSpeed;

  void update(double dt, double gravity) {
    velocity.y += gravity * dt;
    // Frottement de l'air
    velocity.x *= math.pow(0.96, dt * 60).toDouble();
    velocity.y *= math.pow(0.98, dt * 60).toDouble();

    position += velocity * dt;
    angle += angularVelocity * dt;
    wobble += wobbleSpeed * dt;
  }

  void render(Canvas canvas, Paint paint, double opacity) {
    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(angle);

    // Effet de retournement 3D (flutter)
    final scaleX = math.cos(wobble);
    canvas.scale(scaleX, 1.0);

    paint.color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );
    canvas.restore();
  }
}

/// Composant Flame animant une gerbe de confettis festifs lors d'une victoire.
class ConfettiComponent extends Component {
  ConfettiComponent({
    required this.origin,
    this.duration = 2.5,
    this.particleCount = 80,
    math.Random? random,
  }) : _random = random ?? math.Random();

  final Vector2 origin;
  final double duration;
  final int particleCount;
  final math.Random _random;

  final List<_ConfettiParticle> _particles = [];
  final Paint _paint = Paint()..style = PaintingStyle.fill;
  double _elapsed = 0.0;

  static const _palette = [
    Color(0xFFFFD700), // Or
    Color(0xFFFF4081), // Rose vif
    Color(0xFF00E5FF), // Cyan néon
    Color(0xFFB388FF), // Mauve clair
    Color(0xFF76FF03), // Vert lime
    Color(0xFFFF9100), // Orange
    Color(0xFFFFFFFF), // Blanc
    Color(0xFF00E676), // Émeraude
  ];

  @override
  void onLoad() {
    super.onLoad();
    _spawnParticles();
  }

  void _spawnParticles() {
    _particles.clear();
    for (var i = 0; i < particleCount; i++) {
      // Angle radial avec bias vers le haut (-pi/2)
      final angle =
          -math.pi / 2 + (_random.nextDouble() - 0.5) * (math.pi * 1.3);
      final speed = 250.0 + _random.nextDouble() * 450.0;
      final vx = math.cos(angle) * speed;
      final vy = math.sin(angle) * speed;

      final color = _palette[_random.nextInt(_palette.length)];
      final width = 6.0 + _random.nextDouble() * 7.0;
      final height = 4.0 + _random.nextDouble() * 6.0;

      _particles.add(
        _ConfettiParticle(
          position:
              origin.clone() +
              Vector2(
                (_random.nextDouble() - 0.5) * 20.0,
                (_random.nextDouble() - 0.5) * 20.0,
              ),
          velocity: Vector2(vx, vy),
          color: color,
          size: Vector2(width, height),
          angularVelocity: (_random.nextDouble() - 0.5) * 12.0,
          wobbleSpeed: 4.0 + _random.nextDouble() * 8.0,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_elapsed >= duration) {
      removeFromParent();
      return;
    }

    const gravity = 480.0;
    for (final particle in _particles) {
      particle.update(dt, gravity);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Fondu progressif dans le dernier tiers du temps
    final remaining = duration - _elapsed;
    final fadeDuration = duration * 0.35;
    final opacity = remaining < fadeDuration
        ? (remaining / fadeDuration).clamp(0.0, 1.0)
        : 1.0;

    for (final particle in _particles) {
      particle.render(canvas, _paint, opacity);
    }
  }
}
