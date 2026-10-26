import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'package:bubble/features/bubble/presentation/widgets/bubble_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BubblePainter.shouldRepaint', () {
    final basePainter = BubblePainter(
      style: const BubbleStyle(),
      text: 'Hello',
      textColor: Colors.white,
      maxLines: 2,
      autoFit: true,
    );

    test('returns false when properties are identical', () {
      final identicalPainter = BubblePainter(
        style: const BubbleStyle(),
        text: 'Hello',
        textColor: Colors.white,
        maxLines: 2,
        autoFit: true,
      );
      expect(basePainter.shouldRepaint(identicalPainter), isFalse);
    });

    test('returns true when maxLines changes', () {
      final differentMaxLines = BubblePainter(
        style: const BubbleStyle(),
        text: 'Hello',
        textColor: Colors.white,
        maxLines: 4,
        autoFit: true,
      );
      expect(basePainter.shouldRepaint(differentMaxLines), isTrue);
    });

    test('returns true when autoFit changes', () {
      final differentAutoFit = BubblePainter(
        style: const BubbleStyle(),
        text: 'Hello',
        textColor: Colors.white,
        maxLines: 2,
        autoFit: false,
      );
      expect(basePainter.shouldRepaint(differentAutoFit), isTrue);
    });

    test('returns true when text changes', () {
      final differentText = BubblePainter(
        style: const BubbleStyle(),
        text: 'World',
        textColor: Colors.white,
        maxLines: 2,
        autoFit: true,
      );
      expect(basePainter.shouldRepaint(differentText), isTrue);
    });
  });
}
