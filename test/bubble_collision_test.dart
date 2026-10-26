import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bubble/core/physics/bubble_collision_resolver.dart';

class _FakeBubbleBody implements BubblePhysicsBody {
  _FakeBubbleBody({
    required this.position,
    required this.collisionRadius,
    required this.moveDir,
    this.waveAmplitude = 15.0,
    this.waveFrequency = 2.0,
  })  : centerBase = position.clone(),
        movePerp = Vector2(-moveDir.y, moveDir.x),
        waveTime = 0.0;

  @override
  final Vector2 position;

  @override
  final Vector2 centerBase;

  @override
  final Vector2 moveDir;

  @override
  final Vector2 movePerp;

  @override
  final double collisionRadius;

  @override
  final double speed = 100.0;

  @override
  final double waveAmplitude;

  @override
  final double waveFrequency;

  @override
  bool isCollisionActive = true;

  @override
  double waveTime;
}

void main() {
  group('BubbleCollisionResolver', () {
    test('repousse les bulles en cas de chevauchement', () {
      final a = _FakeBubbleBody(
        position: Vector2(100, 100),
        collisionRadius: 30,
        moveDir: Vector2(1, 0),
      );
      final b = _FakeBubbleBody(
        position: Vector2(140, 100),
        collisionRadius: 30,
        moveDir: Vector2(-1, 0),
      );

      BubbleCollisionResolver.resolve(a, b, padding: 6.0);

      final distanceAfterResolution = (b.position - a.position).length;
      expect(distanceAfterResolution, greaterThanOrEqualTo(65.99));
    });

    test('inverse les composantes de vitesse le long de la normale', () {
      final a = _FakeBubbleBody(
        position: Vector2(100, 100),
        collisionRadius: 30,
        moveDir: Vector2(1, 0),
      );
      final b = _FakeBubbleBody(
        position: Vector2(150, 100),
        collisionRadius: 30,
        moveDir: Vector2(-1, 0),
      );

      BubbleCollisionResolver.resolve(a, b, padding: 6.0);

      expect(a.moveDir.x, lessThan(0));
      expect(b.moveDir.x, greaterThan(0));
    });

    test('ne modifie pas les bulles hors de portee', () {
      final a = _FakeBubbleBody(
        position: Vector2(100, 100),
        collisionRadius: 20,
        moveDir: Vector2(1, 0),
      );
      final b = _FakeBubbleBody(
        position: Vector2(300, 100),
        collisionRadius: 20,
        moveDir: Vector2(-1, 0),
      );

      BubbleCollisionResolver.resolve(a, b);

      expect(a.position, equals(Vector2(100, 100)));
      expect(b.position, equals(Vector2(300, 100)));
      expect(a.moveDir, equals(Vector2(1, 0)));
      expect(b.moveDir, equals(Vector2(-1, 0)));
    });

    test('preserve la continuite spatiale de londe lors de la collision', () {
      final a = _FakeBubbleBody(
        position: Vector2(100, 100),
        collisionRadius: 30,
        moveDir: Vector2(1, 0),
        waveAmplitude: 20.0,
        waveFrequency: 2.0,
      )..waveTime = 0.5;

      final b = _FakeBubbleBody(
        position: Vector2(140, 100),
        collisionRadius: 30,
        moveDir: Vector2(-1, 0),
        waveAmplitude: 20.0,
        waveFrequency: 2.0,
      )..waveTime = 0.5;

      final positionBeforeA = a.position.clone();
      BubbleCollisionResolver.resolve(a, b);

      expect(a.position.y, closeTo(positionBeforeA.y, 0.01));
    });
  });
}
