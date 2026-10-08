import 'dart:math';

/// A tiny speck of texture on a face (glass grain or trapped micro-bubble).
///
/// [u] and [v] are face coordinates in 0..1; [radius] is relative to the
/// cube side.
class FaceSpeck {
  const FaceSpeck({
    required this.u,
    required this.v,
    required this.radius,
    required this.alpha,
    required this.isBubble,
  });

  final double u;
  final double v;
  final double radius;
  final double alpha;
  final bool isBubble;
}

/// Deterministic specks for one face: the first [bubbles] are micro-bubbles,
/// the rest is fine grain.
List<FaceSpeck> buildSpecks(int seed, {int count = 30, int bubbles = 4}) {
  final random = Random(seed);
  return List.generate(count, (i) {
    final isBubble = i < bubbles;
    return FaceSpeck(
      u: 0.08 + random.nextDouble() * 0.84,
      v: 0.08 + random.nextDouble() * 0.84,
      radius: isBubble
          ? 0.006 + random.nextDouble() * 0.006
          : 0.0012 + random.nextDouble() * 0.0018,
      alpha: isBubble ? 0.35 : 0.08 + random.nextDouble() * 0.16,
      isBubble: isBubble,
    );
  });
}