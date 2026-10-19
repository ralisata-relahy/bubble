import 'dart:math' as math;

import '../models/character_pose.dart';

import 'package:flutter/material.dart';

import '../painter/arms_painter.dart';
import '../painter/body_painter.dart';
import '../painter/edutainer_context.dart';
import '../painter/eye_painter.dart';
import '../painter/ground_painter.dart';
import '../painter/laser_painter.dart';
import '../painter/mouth_painter.dart';
import '../painter/saucer_painter.dart';

/// Orchestrator
class EdutainerPainter extends CustomPainter {
  EdutainerPainter(
    this.pose, {
    this.showShadow = false,
    Color laserColor = const Color(0xFF4DF0FF),
    Color? bodyColor,
    Color? saucerColor,
  }) : _ctx = EdutainerContext(
         pose: pose,
         laserColor: laserColor,
         bodyColor: bodyColor,
         saucerColor: saucerColor,
       );

  final EdutainerPose pose;
  final bool showShadow;
  final EdutainerContext _ctx;

  // Kept for backwards compatibility with existing callers.
  static const Size designSize = EdutainerContext.designSize;
  static const List<List<String>> symbolSets = MouthPainter.symbolSets;

  Offset laserOrigin(Size size) {
    const design = EdutainerContext.designSize;
    final scale = math.min(
      size.width / design.width,
      size.height / design.height,
    );
    final source = _ctx.groupPoint(_saucer.laserOrigin);
    return Offset(
      (size.width - design.width * scale) / 2 + source.dx * scale,
      (size.height - design.height * scale) / 2 + source.dy * scale,
    );
  }

  late final _ground = GroundPainter(_ctx);
  late final _saucer = SaucerPainter(_ctx);
  late final _body = BodyPainter(_ctx);
  late final _eye = EyePainter(_ctx);
  late final _mouth = MouthPainter(_ctx);
  late final _arms = ArmsPainter(_ctx);
  late final _lasers = LaserPainter(_ctx);

  @override
  void paint(Canvas canvas, Size size) {
    const design = EdutainerContext.designSize;
    final s = math.min(size.width / design.width, size.height / design.height);
    canvas.save();
    canvas.translate(
      (size.width - design.width * s) / 2,
      (size.height - design.height * s) / 2,
    );
    canvas.scale(s);

    // ground layer (not affected by bob/tilt)
    if (showShadow) _ground.paintShadow(canvas);
    _ground.paintFoot(canvas, 148, pose.stepLeft, -1);
    _ground.paintFoot(canvas, 252, pose.stepRight, 1);

    // character layer (bob / squash / tilt around the pivot)
    canvas.save();
    canvas.translate(
      EdutainerContext.pivot.dx,
      EdutainerContext.pivot.dy + _ctx.dy,
    );
    canvas.rotate(pose.tilt);
    canvas.scale(_ctx.sx, _ctx.sy);
    canvas.translate(-EdutainerContext.pivot.dx, -EdutainerContext.pivot.dy);
    _saucer.paint(canvas);
    _body.paint(canvas);
    _eye.paint(canvas);
    _eye.paintAngerMark(canvas);
    _mouth.paint(canvas);
    _arms.paint(canvas);
    canvas.restore();

    // effects layer
    _lasers.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EdutainerPainter old) => true;
}
