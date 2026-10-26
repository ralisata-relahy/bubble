import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_pop_renderer.dart';

void main() {
  group('BubblePopRenderer', () {
    late BubblePopRenderer renderer;

    setUp(() {
      renderer = BubblePopRenderer();
    });

    test('createParticles generates a non-empty list of droplets', () {
      final particles = renderer.createParticles(
        bubbleSize: const Size(100, 100),
        popOrigin: const Offset(50, 50),
        popMaxHole: 60,
        dropColor: Colors.blue,
        random: math.Random(42),
      );

      expect(particles, isNotEmpty);
      expect(particles.length, inInclusiveRange(22, 28));

      for (final p in particles) {
        expect([Colors.blue, Colors.white].contains(p.color), isTrue);
        expect(p.speed, greaterThan(0));
        expect(p.radius, greaterThan(0));
        expect(p.life, greaterThan(0));
      }
    });

    test('calculateHoleRadius returns 0 before pop starts', () {
      final r = renderer.calculateHoleRadius(popProgress: 0.0, maxHole: 50.0);
      expect(r, equals(0.0));
    });

    test(
      'calculateHoleRadius increases monotonically during hole expansion',
      () {
        final r1 = renderer.calculateHoleRadius(
          popProgress: 0.05,
          maxHole: 50.0,
        );
        final r2 = renderer.calculateHoleRadius(
          popProgress: 0.20,
          maxHole: 50.0,
        );
        expect(r2, greaterThan(r1));
        expect(r2, lessThanOrEqualTo(50.0));
      },
    );
  });
}
