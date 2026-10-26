import 'package:bubble/features/bubble/controllers/bubble_controller.dart';
import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BubbleController', () {
    test('updates text reactively', () {
      final controller = BubbleController();
      expect(controller.config.value.text, '');

      controller.updateText('Test Answer');
      expect(controller.config.value.text, 'Test Answer');
    });

    test('updates style reactively', () {
      final controller = BubbleController();
      const newStyle = BubbleStyle(baseColor: Colors.deepPurple);

      controller.updateStyle(newStyle);
      expect(controller.style.value.baseColor, Colors.deepPurple);
      expect(controller.config.value.style.baseColor, Colors.deepPurple);
    });
  });
}
