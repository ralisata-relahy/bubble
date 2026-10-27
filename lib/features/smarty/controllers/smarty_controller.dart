import 'package:get/get.dart';

import '../models/smarty_pose.dart';
import '../models/saucer_palette.dart';

/// GetX controller managing Smarty mascot poses, emotions, and saucer styling.
class SmartyController extends GetxController {
  /// Reactive emotional state of the character.
  final emotion = SmartyEmotion.normal.obs;

  /// Reactive physical pose of the character.
  final pose = const SmartyPose().obs;

  // Be in caged
  bool isCaged=false;

  /// Reactive color palette for the saucer vehicle.
  final saucerPalette = SaucerPalette.from(null).obs;

  /// Updates the character's active emotion.
  void setEmotion(SmartyEmotion newEmotion) {
    emotion.value = newEmotion;
  }

  /// Updates the character's active pose.
  void setPose(SmartyPose newPose) {
    pose.value = newPose;
  }
  void setCaged(){
    isCaged=!isCaged;
  }
  /// Updates the saucer visual palette.
  void setPalette(SaucerPalette newPalette) {
    saucerPalette.value = newPalette;
  }
}
