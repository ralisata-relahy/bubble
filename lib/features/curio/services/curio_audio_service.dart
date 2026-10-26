import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import 'package:bubble/features/curio/character_backup_painter.dart';

/// Plays the optional voice asset associated with Curio's current mood.
class CurioAudioService {
  static const _assetDirectory = 'assets/audio';
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
    // A mood can change while the player is stopping or the asset is loading;
    // discard stale requests so an old voice cannot play over the new mood.
    await _player.stop();
    final filename = _moodSounds[mood];
    if (filename == null || requestId != _requestId) return;

    try {
      await rootBundle.load('$_assetDirectory/$filename');
      if (requestId != _requestId) return;
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
