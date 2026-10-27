import 'package:audioplayers/audioplayers.dart';
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
  final AudioPlayer _player = AudioPlayer();
  final RxString soundAsset = ''.obs;

  @override
  void onInit() {
    super.onInit();
    ever(soundAsset, (value) {
      if (value.isNotEmpty) play();
    });
  }
  Future<void> play([String? asset]) async {
    final target = asset ?? soundAsset.value;
    if (target.isEmpty) return;
    await _player.stop();
    await _player.play(AssetSource(target));
  }

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
    _player.dispose();
    super.onClose();
  }
}
