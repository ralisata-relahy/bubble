import 'dart:ui';

/// Builds the pillowy outline of a face, like an inflated soap-film cube:
/// strongly rounded corners and edges that bulge slightly outwards.
class FaceOutline {
  const FaceOutline({this.cornerRadius = 0.22, this.bulge = 0.07});

  /// Corner rounding, as a fraction of the shortest adjacent edge.
  final double cornerRadius;

  /// Edge bulge, as a fraction of the edge length.
  final double bulge;

  /// [inset] shrinks the outline toward the face center (0..1).
  Path build(List<Offset> corners, {double inset = 0}) {
    final center = (corners[0] + corners[1] + corners[2] + corners[3]) / 4;
    final p = [for (final q in corners) q + (center - q) * inset];
    final n = p.length;

    // Points where each corner curve starts / ends
    final starts = List<Offset>.filled(n, Offset.zero);
    final ends = List<Offset>.filled(n, Offset.zero);
    for (var i = 0; i < n; i++) {
      final prev = p[(i + n - 1) % n], cur = p[i], next = p[(i + 1) % n];
      final toPrev = prev - cur, toNext = next - cur;
      final dp = toPrev.distance, dn = toNext.distance;
      final r = (dp < dn ? dp : dn) * cornerRadius;
      starts[i] = cur + toPrev / dp * r;
      ends[i] = cur + toNext / dn * r;
    }

    final path = Path()..moveTo(starts[0].dx, starts[0].dy);
    for (var i = 0; i < n; i++) {
      final cur = p[i];
      final nextStart = starts[(i + 1) % n];

      // Rounded corner
      path.quadraticBezierTo(cur.dx, cur.dy, ends[i].dx, ends[i].dy);

      // Edge bulging away from the face center
      final mid = (ends[i] + nextStart) / 2;
      final outward = mid - center;
      final edgeLength = (p[(i + 1) % n] - cur).distance;
      final control = mid + outward / outward.distance * (edgeLength * bulge);
      path.quadraticBezierTo(control.dx, control.dy, nextStart.dx, nextStart.dy);
    }
    return path..close();
  }
}