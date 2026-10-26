import 'package:flutter_test/flutter_test.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_heat_effect.dart';

void main() {
  group('BubbleHeatEffect', () {
    late BubbleHeatEffect heatEffect;

    setUp(() {
      heatEffect = BubbleHeatEffect();
    });

    test('initializes with default baseline values', () {
      expect(heatEffect.inflationScale, equals(1.0));
      expect(heatEffect.hitNormal, equals(Offset.zero));
    });

    test('registerHit stores the impact normal', () {
      const normal = Offset(0.5, -0.8);
      heatEffect.registerHit(normal);
      expect(heatEffect.hitNormal, equals(normal));
    });

    test('reset clears impact normal and inflation scale', () {
      heatEffect.registerHit(const Offset(1.0, 1.0));
      heatEffect.reset();
      expect(heatEffect.inflationScale, equals(1.0));
      expect(heatEffect.hitNormal, equals(Offset.zero));
    });

    test('update dissipates heat when no active hit TTL', () {
      heatEffect.update(0.1);
      expect(heatEffect.inflationScale, equals(1.0));
    });
  });
}
