import 'package:get/get.dart';

import '../models/bubble_config.dart';
import '../models/bubble_style.dart';

/// GetX controller managing bubble configuration and visual styles for UI previews.
class BubbleController extends GetxController {
  /// Reactive bubble configuration.
  final config = const BubbleConfig().obs;

  /// Reactive bubble visual style.
  final style = const BubbleStyle().obs;

  /// Updates the bubble text content.
  void updateText(String newText) {
    config.value = config.value.copyWith(text: newText);
  }

  /// Updates the bubble style.
  void updateStyle(BubbleStyle newStyle) {
    style.value = newStyle;
    config.value = config.value.copyWith(style: newStyle);
  }
}
