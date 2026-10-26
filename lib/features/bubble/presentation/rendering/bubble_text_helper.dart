import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Helper utility for creating and auto-fitting text inside bubble components and widgets.
class BubbleTextHelper {
  /// Calculates an ellipse size that accommodates the text without enlarging the font.
  static Size bubbleSizeForText({
    required String text,
    required double maxWidth,
    double fontSize = 20,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final width = (painter.width + 72).clamp(110.0, maxWidth).toDouble();
    painter.dispose();

    // Long text stretches the ellipse horizontally; short text maintains a vertical shape.
    final wrappedText = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 32);
    final height = math
        .max(100 - (width - 110) * 0.05, wrappedText.height + 36)
        .toDouble();
    wrappedText.dispose();

    return Size(width, height);
  }

  /// Creates a [TextPainter] that auto-fits [text] inside [box].
  ///
  /// Shrinks the font size until the text fits within [widthFactor] of [box.width]
  /// and [heightFactor] of [box.height], respecting [maxLines].
  /// Pass [autoFit] = false to disable font shrinking.
  static TextPainter createTextPainter({
    required String text,
    required TextStyle style,
    required Size box,
    int maxLines = 3,
    bool autoFit = true,
    double widthFactor = 0.7,
    double heightFactor = 0.6,
  }) {
    final maxWidth = box.width * widthFactor;
    final maxHeight = box.height * heightFactor;
    var fontSize = style.fontSize ?? (box.shortestSide * 0.2);

    var allowAdditionalLines = !autoFit;
    while (true) {
      final effectiveMaxLines = allowAdditionalLines ? null : maxLines;
      final textStyle = style.copyWith(fontSize: fontSize);
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: effectiveMaxLines,
      )..layout(maxWidth: maxWidth);

      final exceedsLineLimit = painter.didExceedMaxLines;
      final exceedsHeight = painter.height > maxHeight;
      final textHeight = painter.height;
      final widestWord = _widestWordWidth(text, textStyle);
      if (widestWord <= maxWidth &&
          !exceedsLineLimit &&
          (!autoFit || !exceedsHeight)) {
        return painter;
      }

      painter.dispose();

      if (autoFit && !allowAdditionalLines && fontSize <= 1) {
        allowAdditionalLines = true;
        continue;
      }
      if (widestWord > maxWidth) {
        fontSize *= maxWidth / widestWord * 0.95;
      } else if (autoFit && exceedsHeight) {
        fontSize *= maxHeight / textHeight * 0.9;
      } else {
        fontSize *= 0.9;
      }
    }
  }

  static double _widestWordWidth(String text, TextStyle style) {
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      widest = widest < painter.width ? painter.width : widest;
      painter.dispose();
    }
    return widest;
  }
}
