import 'dart:math' as math;
import 'dart:typed_data';
import 'sfx_generate.dart';
import 'package:flutter_soloud/flutter_soloud.dart';


// Every available sound, with its default volume and pitch behaviour
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
  popupClose(varyPitch: false);

  const Sfx({this.volume = 1.0, this.varyPitch = true});

  final double volume;
  final bool varyPitch;
}

class SoundEffects {
  SoundEffects._();

  static final _sources = <Sfx, AudioSource>{};
  static final _loops = <Sfx, SoundHandle>{};
  static final _rnd = math.Random();
  static Future<void>? _initFuture;
  static bool _ready = false;
  static int _lastTick = 0;

  static bool enabled = true;

  static final Map<Sfx, Uint8List Function()> _builders = {
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
  };

  // Call once at startup. Safe to call several times.
  static Future<void> init({Set<Sfx>? only}) =>
      _initFuture ??= _init(only ?? Sfx.values.toSet()).catchError((Object e) {
        _initFuture = null; // allow a retry after a failure
        throw e;
      });

  static Future<void> _init(Set<Sfx> wanted) async {
    await SoLoud.instance.init();
    for (final sfx in wanted) {
      final bytes = _builders[sfx]!();
      _sources[sfx] = await SoLoud.instance.loadMem('${sfx.name}.wav', bytes);
    }
    _ready = true;
  }

  // Plays a one-shot sound
  static Future<void> play(Sfx sfx, {double? volume, bool? varyPitch}) async {
    if (!enabled || !_ready) return;
    final source = _sources[sfx];
    if (source == null) return;

    try {
      final handle = await SoLoud.instance.play(
        source,
        volume: volume ?? sfx.volume,
        paused: true,
      );
      if (varyPitch ?? sfx.varyPitch) {
        SoLoud.instance.setRelativePlaySpeed(
          handle,
          0.92 + _rnd.nextDouble() * 0.16,
        );
      }
      SoLoud.instance.setPause(handle, false);
    } catch (_) {
    }
  }

  // Scroll/slider tick
  static void tick({int minGapMs = 45}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTick < minGapMs) return;
    _lastTick = now;
    play(Sfx.tick);
  }

  // Looping sounds

  static bool isLooping(Sfx sfx) => _loops.containsKey(sfx);

  static Future<void> startLoop(Sfx sfx, {double? volume}) async {
    if (!enabled || !_ready || _loops.containsKey(sfx)) return;
    final source = _sources[sfx];
    if (source == null) return;
    try {
      _loops[sfx] = await SoLoud.instance.play(
        source,
        volume: volume ?? sfx.volume,
        looping: true,
      );
    } catch (_) {}
  }

  static Future<void> stopLoop(Sfx sfx) async {
    final handle = _loops.remove(sfx);
    if (handle == null) return;
    try {
      await SoLoud.instance.stop(handle);
    } catch (_) {
      // already stopped
    }
  }

  // Starts the loop if stopped, stops it if running. Returns the new state.
  static Future<bool> toggleLoop(Sfx sfx, {double? volume}) async {
    if (isLooping(sfx)) {
      await stopLoop(sfx);
      return false;
    }
    await startLoop(sfx, volume: volume);
    return isLooping(sfx);
  }

  static Future<void> stopAllLoops() async {
    for (final sfx in _loops.keys.toList()) {
      await stopLoop(sfx);
    }
  }

  static Future<void> dispose() async {
    await stopAllLoops();
    for (final s in _sources.values) {
      await SoLoud.instance.disposeSource(s);
    }
    _sources.clear();
    if (_ready) SoLoud.instance.deinit();
    _ready = false;
    _initFuture = null;
  }
}
