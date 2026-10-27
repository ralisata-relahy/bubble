import 'dart:math' as math;

import '../models/smarty_pose.dart';

import 'package:flutter/material.dart';

import 'smarty_context.dart';

/// Draws the mouth, tongue, and educational symbols for the current mood.
class MouthPainter {
  MouthPainter(this.ctx);
  final SmartyContext ctx;
  SmartyPose get pose => ctx.pose;

  static const List<List<String>> symbolSets = [
    ['1 2 3', '# π §'],
    ['E=mc²', '∑ ∫ √'],
    ['ħ Δ Ω', 'F=ma'],
    ['∞ ≈ ≠', 'λ φ θ'],
    ['H₂O', '∂ ∇ ±'],
  ];

  static const double _top = 352.0;

  void paint(Canvas canvas) {
    if (pose.sadness > 0.01) {
      _frown(canvas);
      return; // no open mouth, tongue or symbols while sad
    }
    _mouth(canvas);
    final tongueRect = _tongue(canvas);
    _tongueSymbols(canvas, tongueRect);
  }

  /// Downturned arc: the ends sit lower than the middle.
  void _frown(Canvas canvas) {
    final sd = pose.sadness.clamp(0.0, 1.0);
    final endY = _top + 8 + 8 * sd;
    final ctrlY = _top - 12 - 4 * sd;
    final path = Path()
      ..moveTo(158, endY)
      ..quadraticBezierTo(200, ctrlY, 242, endY);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3A0407),
    );
  }

  void _mouth(Canvas canvas) {
    final mh = 14 + 26 * pose.mouthOpen;
    final mouth = Path()
      ..moveTo(146, _top)
      ..quadraticBezierTo(200, _top - 5, 254, _top)
      ..cubicTo(225, _top + mh * 1.6, 175, _top + mh * 1.6, 146, _top)
      ..close();
    canvas.drawPath(
      mouth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0407), Color(0xFF8B1018)],
        ).createShader(mouth.getBounds()),
    );
  }

  Rect _tongue(Canvas canvas) {
    final tLen = 38 + 26 * pose.tongueOut;
    final tTop = _top + 6;
    final tr = Rect.fromLTWH(168, tTop, 64, tLen);
    final tongue = RRect.fromRectAndCorners(
      tr,
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
      bottomLeft: const Radius.circular(32),
      bottomRight: const Radius.circular(32),
    );
    canvas.drawRRect(
      tongue,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8FA3), Color(0xFFE8405F)],
        ).createShader(tr),
    );
    canvas.drawOval(
      Rect.fromLTWH(176, tTop + 3, 18, 7),
      Paint()..color = const Color(0x66FFFFFF),
    );
    return tr;
  }

  void _tongueSymbols(Canvas canvas, Rect tr) {
    final tLen = tr.height;
    final rows = symbolSets[pose.symbolSet.abs() % symbolSets.length];
    for (var i = 0; i < rows.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: rows[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1,
            shadows: [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final sc = math.min(1.0, 54 / tp.width);
      canvas.save();
      canvas.translate(tr.center.dx, tr.top + tLen * 0.2 + i * tLen * 0.33 + 7);
      canvas.scale(sc);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}
