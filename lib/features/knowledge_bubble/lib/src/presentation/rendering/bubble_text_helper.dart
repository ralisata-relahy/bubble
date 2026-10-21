import 'package:flutter/painting.dart';

/// Helper utility for creating and auto-fitting text inside bubble components and widgets.
class BubbleTextHelper {
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

    TextPainter build(double size) => TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,

      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    var tp = build(fontSize);
    if (autoFit) {
      while ((tp.didExceedMaxLines || tp.height > maxHeight || tp.width > maxWidth) &&
          fontSize > 6) {
        tp.dispose();
        fontSize *= 0.9;
        tp = build(fontSize);
      }
    }
    return tp;
  }
}
