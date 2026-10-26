import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ai_buddy_controller.dart';
import '../widgets/edutainment_character.dart';

/// Flutter View displaying the AI Buddy character, reactive to [AiBuddyController].
class EdutainmentView extends StatelessWidget {
  const EdutainmentView({
    super.key,
    this.targets = const [],
    this.size = 200.0,
  });

  final List<EdutainerTarget> targets;
  final double size;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<AiBuddyController>()
        ? Get.find<AiBuddyController>()
        : null;

    if (controller == null) {
      return SizedBox(
        width: size,
        height: size,
        child: AiBudddyEdutainment(size: size, targets: targets),
      );
    }

    return Obx(() {
      return SizedBox(
        width: size,
        height: size,
        child: AiBudddyEdutainment(
          size: size,
          targets: targets,
          emotion: controller.emotion.value,
          pose: controller.pose.value,
        ),
      );
    });
  }
}
