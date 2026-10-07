import 'dart:math';
import 'dart:ui';

import 'cube_face.dart';

/// Rotates, projects (perspective) and lights the faces of the cube.
class CubeProjector {
  const CubeProjector({
    this.cameraDistance = 5.0,
    this.lightX = -0.45, // top-left-front light
    this.lightY = -0.6,
    this.lightZ = 0.66,
  });

  final double cameraDistance;
  final double lightX, lightY, lightZ;

  void project(
      List<CubeFace> faces, {
        required double pitch,
        required double yaw,
        required Offset center,
        required double scale,
      }) {
    final cy = cos(yaw), sy = sin(yaw);
    final cp = cos(-pitch), sp = sin(-pitch);

    (double, double, double) rotate(double x, double y, double z) {
      final x1 = -x * cy + z * sy;
      final z1 = x * sy + z * cy;
      return (x1, y * cp - z1 * sp, y * sp + z1 * cp);
    }

    Offset toScreen((double, double, double) p) =>
        center + Offset(p.$1, p.$2) * (scale * cameraDistance / (cameraDistance - p.$3));

    for (final face in faces) {
      for (var i = 0; i < 4; i++) {
        final v = face.vertices[i];
        face.corners[i] = toScreen(rotate(v[0], v[1], v[2]));
      }
      final n = rotate(face.normal[0], face.normal[1], face.normal[2]);
      face.facing = n.$3;
      face.light = max(0.0, n.$1 * lightX + n.$2 * lightY + n.$3 * lightZ);
    }
  }
}