import 'dart:math';
import 'dart:ui';
import 'cube_texture.dart';

/// Local frame of a face, anchored on the corner closest to the light.
class FaceFrame {
  const FaceFrame(this.origin, this.axisU, this.axisV);

  final Offset origin;
  final Offset axisU;
  final Offset axisV;

  /// Screen position of face coordinates (u, v) in this frame.
  Offset at(double u, double v) => origin + axisU * u + axisV * v;

  Offset get opposite => at(1, 1);
  double get uLength => axisU.distance;
  double get vLength => axisV.distance;
  double get angle => atan2(axisU.dy, axisU.dx);
}

/// One face of the unit cube plus its projected state (updated every frame).
class CubeFace {
  CubeFace._(this.normal, this.vertices, int seed) : specks = buildSpecks(seed);

  /// The six faces of a unit cube centered on the origin.
  static List<CubeFace> unitCube() => [
    CubeFace._([0, 0, 1], [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], 1),
    CubeFace._([0, 0, -1], [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]], 2),
    CubeFace._([1, 0, 0], [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]], 3),
    CubeFace._([-1, 0, 0], [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]], 4),
    CubeFace._([0, 1, 0], [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]], 5),
    CubeFace._([0, -1, 0], [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]], 6),
  ];

  // Static geometry
  final List<double> normal;
  final List<List<double>> vertices;
  final List<FaceSpeck> specks;

  // Projected state, written by CubeProjector
  final List<Offset> corners = List.filled(4, Offset.zero);
  double facing = 0; // > 0: face facing the camera
  double light = 0; // diffuse lighting (0..1)

  bool get isFront => facing > 0;

  /// Reflectivity at grazing incidence (Fresnel approximation).
  double get fresnel => pow(1 - facing, 2).toDouble();

  Offset get center => (corners[0] + corners[1] + corners[2] + corners[3]) / 4;

  /// Bilinear point on the face from (u, v) in [0,1] x [0,1].
  Offset pointAt(double u, double v) {
    final top = corners[0] + (corners[1] - corners[0]) * u;
    final bottom = corners[3] + (corners[2] - corners[3]) * u;
    return top + (bottom - top) * v;
  }

  /// Frame anchored on the corner closest to the top-left light.
  FaceFrame litFrame() {
    var k = 0;
    for (var i = 1; i < 4; i++) {
      if (corners[i].dx + corners[i].dy < corners[k].dx + corners[k].dy) k = i;
    }
    final origin = corners[k];
    return FaceFrame(
      origin,
      corners[(k + 1) % 4] - origin,
      corners[(k + 3) % 4] - origin,
    );
  }
}