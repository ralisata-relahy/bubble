import 'package:get/get.dart';

import '../models/character_pose.dart';
import '../models/saucer_palette.dart';

/// GetX controller managing AI Buddy mascot poses, emotions, and saucer styling.
class AiBuddyController extends GetxController {
  /// Reactive emotional state of the character.
  final emotion = EdutainerEmotion.normal.obs;

  /// Reactive physical pose of the character.
  final pose = const EdutainerPose().obs;

  /// Reactive color palette for the saucer vehicle.
  final saucerPalette = SaucerPalette.from(null).obs;

  /// Updates the character's active emotion.
  void setEmotion(EdutainerEmotion newEmotion) {
    emotion.value = newEmotion;
  }

  /// Updates the character's active pose.
  void setPose(EdutainerPose newPose) {
    pose.value = newPose;
  }

  /// Updates the saucer visual palette.
  void setPalette(SaucerPalette newPalette) {
    saucerPalette.value = newPalette;
  }
}
