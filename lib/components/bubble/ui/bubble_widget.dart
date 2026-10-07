import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bubble_style.dart';
import '../render/bubble_renderer.dart';
import '../render/bubble_text_helper.dart';

/// A reusable Flutter Widget that renders a bubble (Sphere, Ellipsoid, or 3D Cube)
/// for standard UI displays, posters, cards, or screens without requiring a Flame game.
class BubbleWidget extends StatelessWidget {
  const BubbleWidget({
    super.key,
    this.text = '',
    this.textColor = Colors.white,
    this.style = const BubbleStyle(),
    this.maxLines = 3,
    this.autoFit = true,
  });

  final String text;
  final Color textColor;
  final BubbleStyle style;
  final int maxLines;
  final bool autoFit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: style.size.width,
      height: style.size.height,
      child: CustomPaint(
        painter: BubblePainter(
          style: style,
          text: text,
          textColor: textColor,
          maxLines: maxLines,
          autoFit: autoFit,
        ),
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  BubblePainter({
    required this.style,
    required this.text,
    required this.textColor,
    required this.maxLines,
    required this.autoFit,
  }) : _renderer = BubbleRenderer(style);

  final BubbleStyle style;
  final String text;
  final Color textColor;
  final int maxLines;
  final bool autoFit;
  final BubbleRenderer _renderer;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paint body layer
    _renderer.paintBody(canvas);

    // 2. Paint label text if present using shared BubbleTextHelper
    if (text.isNotEmpty) {
      final textPainter = BubbleTextHelper.createTextPainter(
        text: text,
        style: GoogleFonts.quicksand(
          color: textColor,
          fontSize: size.shortestSide * 0.2,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black45,
              offset: Offset(0, size.shortestSide * 0.015),
              blurRadius: size.shortestSide * 0.03,
            ),
          ],
        ),
        box: size,
        maxLines: maxLines,
        autoFit: autoFit,
      );

      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      textPainter.dispose();
    }

    // 3. Paint gloss layer (highlights)
    _renderer.paintGloss(canvas);
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.text != text ||
        oldDelegate.textColor != textColor;
  }
}
