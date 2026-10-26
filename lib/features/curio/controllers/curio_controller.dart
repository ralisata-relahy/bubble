import 'package:get/get.dart';

import '../domain/models/mood.dart';
import '../services/curio_audio_service.dart';

/// GetX controller managing Curio mascot reactive mood state and voice reactions.
class CurioController extends GetxController {
  /// Creates a Curio controller with an optional [CurioAudioService].
  // ignore: avoid_positional_boolean_parameters
  CurioController({CurioAudioService? audioService})
    // ignore: prefer_initializing_formals
    : _audioService = audioService;

  final CurioAudioService? _audioService;

  /// The active emotional expression of Curio.
  final currentMood = Mood.excited.obs;

  /// Updates Curio's mood and triggers matching vocal reactions when the mood changes.
  void updateMood(Mood newMood) {
    if (currentMood.value != newMood) {
      currentMood.value = newMood;
      _audioService?.playMood(newMood);
    }
  }

  @override
  void onClose() {
    _audioService?.dispose();
    super.onClose();
  }
}
