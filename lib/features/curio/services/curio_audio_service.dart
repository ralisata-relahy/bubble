import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:bubble/features/curio/domain/models/mood.dart';

/// Plays the optional voice asset associated with Curio's current mood.
class CurioAudioService {
  static const _playerAssetDirectory = 'audio';

  final AudioPlayer _player = AudioPlayer();
  int _requestId = 0;

  static const Map<Mood, String> _moodSounds = {
    Mood.happy: 'happy.mp3',
    Mood.excited: 'happy.mp3',
    Mood.surprised: 'surprised.mp3',
    Mood.sad: 'sad.mp3',
    Mood.angry: 'angry.mp3',
  };

  /// Plays the voice clip mapped to [mood], superseding an earlier request.
  Future<void> playMood(Mood mood) async {
    final requestId = ++_requestId;
    // A mood can change while the player is stopping or starting playback;
    // discard stale requests so an old voice cannot play over the new mood.
    final filename = _moodSounds[mood];

    try {
      await _player.stop();
      if (filename == null || requestId != _requestId) return;
      await _player.play(AssetSource('$_playerAssetDirectory/$filename'));
    } catch (error) {
      debugPrint('Failed to play Curio voice "$filename": $error');
    }
  }

  /// Invalidates pending playback and releases the audio player.
  Future<void> dispose() {
    _requestId++;
    return _player.dispose();
  }
}
