// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/bubble_component.dart';

void main() {
  testWidgets('renders each supported bubble shape', (tester) async {
    for (final shape in BubbleShape.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BubbleWidget(
              text: 'Hello',
              style: BubbleStyle(shape: shape, size: const Size(120, 100)),
            ),
          ),
        ),
      );

      expect(find.byType(BubbleWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
