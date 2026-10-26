import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:bubble/features/game/domain/models/game_question.dart';

/// Plays optional spoken answers associated with game questions.
class GameAudioService {
  static const _frenchThankYouAnswer = 'Merci';
  static const _defaultAudioDirectory = 'audio';
  static const _frenchAudioDirectory = 'audio/french';
  static const _answerVolume = 1.0;

  final AudioPlayer _player = AudioPlayer();

  /// Plays a question's optional pronunciation asset when one is configured.
  Future<void> playAnswer(GameQuestion question) async {
    final audioName = question.nameAudio;
    if (audioName == null || audioName.isEmpty) return;

    final audioDirectory = question.answer == _frenchThankYouAnswer
        ? _frenchAudioDirectory
        : _defaultAudioDirectory;
    final audioPath = '$audioDirectory/$audioName';

    try {
      await _player.stop();
      await _player.setVolume(_answerVolume);
      await _player.play(AssetSource(audioPath));
    } catch (error) {
      debugPrint('Failed to play answer audio "$audioPath": $error');
    }
  }

  /// Releases the player owned by this service.
  Future<void> dispose() => _player.dispose();
}
