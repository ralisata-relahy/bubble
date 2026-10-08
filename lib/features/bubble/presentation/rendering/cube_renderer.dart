import 'dart:math';
import 'dart:ui';

import 'package:bubble/features/bubble/models/bubble_style.dart';

import 'bubble_renderer.dart';
import 'cube/cube_face.dart';
import 'cube/cube_motion.dart';
import 'cube/cube_palette.dart';
import 'cube/cube_projector.dart';
import 'cube/face_outline.dart';
import 'cube/glass_painter.dart';
import 'cube/ground_painter.dart';
import 'cube/surface_detail_painter.dart';

/// Animated 3D soap-film cube, monochrome (base color only).
///
/// This class only orchestrates: state lives in [CubeMotion] / [CubeFace],
/// geometry in [CubeProjector] / [FaceOutline], and drawing in the painters.
class CubeRenderer implements BubbleRenderer {
  CubeRenderer(BubbleStyle style)
      : _side = min(style.size.width, style.size.height),
        _center = Offset(style.size.width / 2, style.size.height / 2),
        _palette = CubePalette(style.baseColor),
        _motion = CubeMotion(
          baseYaw: style.initialRotation.dy,
          basePitch: style.initialRotation.dx,
        ) {
    update(0); // initial projection
  }

  static const _unitFraction = 0.5 / 1.8; // cube half-size relative to side
  static const _floatAmplitude = 0.025; // vertical float, relative to side

  final double _side;
  final Offset _center;
  final CubePalette _palette;
  final CubeMotion _motion;

  final List<CubeFace> _faces = CubeFace.unitCube();
  final _projector = const CubeProjector();
  final _outline = const FaceOutline();

  late final _ground = GroundPainter(side: _side, palette: _palette);
  late final _glass = GlassPainter(side: _side, palette: _palette, outline: _outline);
  late final _detail = SurfaceDetailPainter(side: _side, palette: _palette);

  Offset _floatingCenter = Offset.zero;
  CubeFace? _mainFace; // most lit visible face, carries the main glints

  /// On touch / collision: cube snaps and returns in place.
  void poke([double strength = 1]) => _motion.poke(strength);

  @override
  void update(double dt) {
    _motion.update(dt);
    _floatingCenter = _center.translate(0, -_motion.bob * _side * _floatAmplitude);
    _projector.project(
      _faces,
      pitch: _motion.pitch,
      yaw: _motion.yaw,
      center: _floatingCenter,
      scale: _side * _unitFraction * _motion.scale,
    );
    _mainFace = _findMainFace();
  }

  CubeFace? _findMainFace() {
    CubeFace? best;
    for (final face in _faces) {
      if (face.isFront && (best == null || face.light > best.light)) best = face;
    }
    return best;
  }

  /// Back faces viewed through glass (under text).
  @override
  void paintBody(Canvas c) {
    _ground.paint(c, _center, _motion.bob);
    for (final face in _faces) {
      if (!face.isFront) _glass.paintBack(c, face);
    }
  }

  /// Front faces: glass volume, details, edges (above text).
  @override
  void paintGloss(Canvas c) {
    final time = _motion.phasedTime;

    for (var i = 0; i < _faces.length; i++) {
      final face = _faces[i];
      if (!face.isFront) continue;

      final path = _outline.build(face.corners);

      c.save();
      c.clipPath(path);
      _glass.paintVolume(c, face, path);
      _detail.paint(c, face, time: time, isMain: identical(face, _mainFace));
      c.restore();

      _glass.paintEdges(c, face, path, 0.05 * sin(time * 2.0 + i));
    }
  }
}