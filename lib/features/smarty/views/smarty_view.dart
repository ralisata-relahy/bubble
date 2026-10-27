import 'package:bubble/features/game/controllers/game_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/smarty_controller.dart';
import '../widgets/smarty_character.dart';

/// Flutter View displaying the AI Buddy character, reactive to [SmartyController].
class SmartyView extends StatelessWidget {
  const SmartyView({
    super.key,
    this.targets = const [],
    this.size = 200.0,
    this.isCaged = true,
    this.barCount = 0,
  });

  final List<SmartyTarget> targets;
  final double size;
  final bool isCaged;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<SmartyController>()
        ? Get.find<SmartyController>()
        : null;
    final gameController = Get.isRegistered<GameController>()
        ? Get.find<GameController>()
        : null;

    if (controller == null) {
      return SizedBox(
        width: size,
        height: size,
        child: SmartyAvatar(
          size: size,
          targets: targets,
          isCaged: gameController?.isCaged.value ?? isCaged,
          barCount: gameController?.barreCount.value ?? barCount,
        ),
      );
    }

    return Obx(() {
      return SizedBox(
        width: size,
        height: size,
        child: SmartyAvatar(
          size: size,
          targets: targets,
          emotion: controller.emotion.value,
          pose: controller.pose.value,
          isCaged: gameController?.isCaged.value ?? isCaged,
          barCount: gameController?.barreCount.value ?? barCount,
        ),
      );
    });
  }
}
