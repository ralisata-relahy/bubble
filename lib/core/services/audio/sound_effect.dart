import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'audio_emotion/emotion_speaker.dart';
import 'game_audio.dart';
import 'sfx_generate.dart';

/// Available generated sounds and their default playback settings.
enum Sfx {
  burst,
  beamIncorrect(varyPitch: false),
  redForming(varyPitch: false),
  laser(varyPitch: false),
  beamCorrect(varyPitch: false),
  split,
  alert(volume: 0.8, varyPitch: false),
  click,
  switchOn(varyPitch: false),
  switchOff(varyPitch: false),
  tick(volume: 0.6),
  popupOpen(varyPitch: false),
  popupClose(varyPitch: false),

  // Game
  splash(varyPitch: false),
  gameMusic(volume: 0.35, varyPitch: false),

  // Emotions
  veryHappy(varyPitch: false),
  veryDisappointed(varyPitch: false),
  angry(varyPitch: false),
  verySurprised(varyPitch: false),
  excited(varyPitch: false),
  satisfied(varyPitch: false),
  stressed(varyPitch: false),
  proud(varyPitch: false);

  const Sfx({this.volume = 1.0, this.varyPitch = true});

  /// Default gain used when playback does not supply a volume override.
  final double volume;

  /// Whether repeated one-shot playback may receive a small pitch variation.
  final bool varyPitch;
}

/// Owns generated sound buffers and players for one application/game session.
/// A player pool lets short effects overlap without allocating a player per hit.
class SoundEffects {
  SoundEffects();

  static const _poolSize = 6;
  static const _minimumPlaybackRate = 0.92;
  static const _playbackRateVariation = 0.16;
  static const _defaultTickGap = Duration(milliseconds: 45);

  final _bytes = <Sfx, Uint8List>{};
  final _loops = <Sfx, AudioPlayer>{};
  final _pool = <AudioPlayer>[];
  final _random = math.Random();
  Future<void>? _initFuture;
  bool _ready = false;

  /// Enables or suppresses playback without discarding the initialized cache.
  bool enabled = true;
  int _lastTick = 0;
  int _nextPlayerIndex = 0;

  static const Map<Sfx, Uint8List Function()> _builders = {
    Sfx.burst: GameSfx.bubbleBurst,
    Sfx.beamIncorrect: GameSfx.beamIncorrect,
    Sfx.redForming: GameSfx.redBubbleForming,
    Sfx.laser: GameSfx.laser,
    Sfx.beamCorrect: GameSfx.beamCorrect,
    Sfx.split: GameSfx.bubbleSplit,
    Sfx.alert: GameSfx.alert,
    Sfx.click: GameSfx.click,
    Sfx.switchOn: GameSfx.switchOn,
    Sfx.switchOff: GameSfx.switchOff,
    Sfx.tick: GameSfx.tick,
    Sfx.popupOpen: GameSfx.popupOpen,
    Sfx.popupClose: GameSfx.popupClose,

    // Game
    Sfx.splash: SplashSfx.splash,
    Sfx.gameMusic: GameMusic.cartoonLoop,

    // Emotions
    Sfx.veryHappy: EmotionSfx.veryHappy,
    Sfx.veryDisappointed: EmotionSfx.veryDisappointed,
    Sfx.angry: EmotionSfx.angry,
    Sfx.verySurprised: EmotionSfx.verySurprised,
    Sfx.excited: EmotionSfx.excited,
    Sfx.satisfied: EmotionSfx.satisfied,
    Sfx.stressed: EmotionSfx.stressed,
    Sfx.proud: EmotionSfx.proud,
  };

  /// Initializes the effect cache and player pool once for this service.
  /// Await it before playback; calls made before initialization are ignored.
  /// Pass [only] to synthesize a subset of sounds for a smaller client.
  Future<void> init({Set<Sfx>? only}) =>
      _initFuture ??= _initializeWithRetry(only ?? Sfx.values.toSet());

  Future<void> _initializeWithRetry(Set<Sfx> wanted) async {
    try {
      await _init(wanted);
    } catch (error, stackTrace) {
      _initFuture = null;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _init(Set<Sfx> wanted) async {
    // Mix with other app audio rather than taking exclusive audio focus.
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    for (final sfx in wanted) {
      _bytes[sfx] = _builders[sfx]!();
    }
    for (var i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.mediaPlayer); // BytesSource needs this
      await p.setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
    }
    _ready = true;
  }

  /// Plays one effect using the next player in the pool.
  /// It is a no-op while disabled, before initialization, or if [sfx] was
  /// excluded from [init]. Playback errors are logged without interrupting play.
  Future<void> play(Sfx sfx, {double? volume, bool? varyPitch}) async {
    if (!enabled || !_ready) return;
    final bytes = _bytes[sfx];
    if (bytes == null) return;

    try {
      final player = _pool[_nextPlayerIndex];
      _nextPlayerIndex = (_nextPlayerIndex + 1) % _pool.length;
      await player.stop();
      await player.setVolume(volume ?? sfx.volume);
      if (varyPitch ?? sfx.varyPitch) {
        await player.setPlaybackRate(
          _minimumPlaybackRate + _random.nextDouble() * _playbackRateVariation,
        );
      } else {
        await player.setPlaybackRate(1.0);
      }
      await player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('SFX play failed ($sfx): $e');
    }
  }

  /// Plays a rate-limited tick for scroll and slider interactions.
  /// Throttling avoids a dense stream of overlapping sounds during a drag.
  void tick({Duration minGap = _defaultTickGap}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTick < minGap.inMilliseconds) return;
    _lastTick = now;
    unawaited(play(Sfx.tick));
  }

  /// Whether a dedicated looping player currently exists for [sfx].
  bool isLooping(Sfx sfx) => _loops.containsKey(sfx);

  /// Starts a loop with its own player so one-shots cannot interrupt it.
  Future<void> startLoop(Sfx sfx, {double? volume}) async {
    if (!enabled || !_ready || _loops.containsKey(sfx)) return;
    final bytes = _bytes[sfx];
    if (bytes == null) return;
    try {
      final p = AudioPlayer();
      _loops[sfx] = p; // register first so a double tap can't start two
      await p.setPlayerMode(PlayerMode.mediaPlayer); // BytesSource needs this
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(volume ?? sfx.volume);
      await p.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('SFX loop failed ($sfx): $e');
      _loops.remove(sfx);
    }
  }

  /// Stops and releases the dedicated player for [sfx], if active.
  Future<void> stopLoop(Sfx sfx) async {
    final p = _loops.remove(sfx);
    if (p == null) return;
    try {
      await p.stop();
      await p.dispose();
    } catch (error) {
      debugPrint('SFX loop stop failed ($sfx): $error');
    }
  }

  /// Toggles [sfx] and returns whether its loop is active afterward.
  Future<bool> toggleLoop(Sfx sfx, {double? volume}) async {
    if (isLooping(sfx)) {
      await stopLoop(sfx);
      return false;
    }
    await startLoop(sfx, volume: volume);
    return isLooping(sfx);
  }

  /// Stops and releases every active loop.
  Future<void> stopAllLoops() async {
    for (final sfx in _loops.keys.toList()) {
      await stopLoop(sfx);
    }
  }

  /// Stops loops, disposes pooled players, and clears cached audio buffers.
  Future<void> dispose() async {
    await stopAllLoops();
    for (final p in _pool) {
      await p.dispose();
    }
    _pool.clear();
    _bytes.clear();
    _ready = false;
    _nextPlayerIndex = 0;
    _lastTick = 0;
    _initFuture = null;
  }
}
