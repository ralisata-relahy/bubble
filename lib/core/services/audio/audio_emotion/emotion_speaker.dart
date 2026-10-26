import 'dart:math' as math;
import 'dart:typed_data';

import '../sfx_generate.dart';

const int _sr = SfxSynth.sampleRate;

// Synthesize LOW so the vowels are clear, then resample faster (_speedUp).
// Final pitch is roughly _pitchLift * _speedUp (about 1.05 here).
const double _pitchLift = 0.6;
const double _formantLift = 1.0;

// Resample ratio: raises pitch AND formants together (small, cute creature)
// and makes everything faster. Try 1.3 to 1.8.
const double _speedUp = 1.7;

// Formant bandwidths in Hz (narrower = clearer vowel) and relative gains.
const _bw = [90.0, 110.0, 160.0];
const _fGain = [1.0, 0.55, 0.25];

/// Vowels used to select formant frequencies while synthesizing speech.
enum _V { a, e, i, o, u }

// Formant frequencies (Hz) of each vowel: how the "mouth" is shaped.
const _formants = <_V, List<double>>{
  _V.a: [800.0, 1150.0, 2900.0], // "ah"
  _V.e: [450.0, 1900.0, 2600.0], // "eh"
  _V.i: [300.0, 2200.0, 3000.0], // "ee"
  _V.o: [450.0, 800.0, 2830.0], // "oh"
  _V.u: [325.0, 700.0, 2700.0], // "oo"
};

double _smooth(double x) => x * x * (3 - 2 * x);

// Smoothly interpolates evenly spaced keyframes at t (0..1).
double _curve(List<double> pts, double t) {
  if (pts.length == 1) return pts[0];
  final p = t.clamp(0.0, 1.0) * (pts.length - 1);
  final i = math.min(p.floor(), pts.length - 2);
  return pts[i] + (pts[i + 1] - pts[i]) * _smooth(p - i);
}

// Glottal pulse (Rosenberg): a natural-shaped vocal-fold opening and closing.
double _pulse(double p) {
  const tp = 0.4, tn = 0.16;
  if (p < tp) return 0.5 * (1 - math.cos(math.pi * p / tp));
  if (p < tp + tn) return math.cos(math.pi / 2 * (p - tp) / tn);
  return 0.0;
}

/// One spoken syllable.
class _Syl {
  const _Syl(
    this.at,
    this.dur, {
    required this.pitch, // pitch keyframes (Hz), spread evenly over the syllable
    required this.vowels, // vowel keyframes, morphed smoothly
    this.vol = 1.0,
    this.size = 1.0, // per-syllable pitch multiplier
    this.vibrato = 0.0, // pitch wobble depth (0.02 = subtle)
    this.vibHz = 5.5,
    this.vibFade = 0.25, // seconds before the vibrato fully kicks in
    this.breath = 0.0, // airy noise in the voice
    this.growl = 0.0, // rough amplitude buzz (0..1)
    this.growlHz = 45.0,
    this.jitter = 0.0, // random pitch roughness
    this.decay = 0.0, // >0 = fades out / snappier
    this.attack = 0.015,
    this.release = 0.05,
  }) : pitchScale = 1.0;

  final double at, dur;
  final List<double> pitch;
  final List<_V> vowels;
  final double vol, size, pitchScale, vibrato, vibHz, vibFade, breath;
  final double growl, growlHz, jitter, decay, attack, release;
}

/// Synthesizes short voice-like sounds for Curio's emotional reactions.
class EmotionSfx {
  // VOICE ENGINE

  // Renders one syllable: glottal source -> 3 vowel filters -> envelope.
  static Float64List _syl(_Syl s) {
    final n = (_sr * s.dur).toInt();
    final out = Float64List(n);
    final rnd = math.Random((s.at * 1000).toInt() + 7);
    final driftPh1 = rnd.nextDouble() * 2 * math.pi;
    final driftPh2 = rnd.nextDouble() * 2 * math.pi;
    final low = [0.0, 0.0, 0.0];
    final band = [0.0, 0.0, 0.0];
    final att = math.min(s.attack, s.dur * 0.4);
    final rel = math.min(s.release, s.dur * 0.6);
    final nv = s.vowels.length;
    final lift = _pitchLift * s.pitchScale;
    double phase = 0;
    double prevG = 0;

    for (int i = 0; i < n; i++) {
      final t = i / n;
      final sec = i / _sr;

      // Pitch: contour + vibrato (fades in) + slow natural drift.
      var hz = _curve(s.pitch, t) * lift;
      final vibAmt =
          s.vibrato * math.min(1.0, sec / math.max(0.001, s.vibFade));
      hz *= 1 + vibAmt * math.sin(2 * math.pi * s.vibHz * sec);
      hz *=
          1 +
          0.006 * math.sin(2 * math.pi * 2.3 * sec + driftPh1) +
          0.004 * math.sin(2 * math.pi * 5.7 * sec + driftPh2);
      if (s.jitter > 0) hz *= 1 + s.jitter * (rnd.nextDouble() - 0.5);
      phase = (phase + hz / _sr) % 1.0;

      // Voice source: glottal pulse (its derivative gives natural brightness).
      final g = _pulse(phase);
      var src = (g - prevG) * (_sr / hz) * 0.2 + 0.25 * g;
      prevG = g;
      if (s.breath > 0) src += s.breath * (rnd.nextDouble() * 2 - 1) * 0.5;
      if (s.growl > 0) {
        src *=
            1 -
            s.growl +
            s.growl * (0.5 + 0.5 * math.sin(2 * math.pi * s.growlHz * sec));
      }

      // Vowel position, smoothly morphing between keyframes.
      int vi = 0;
      double vf = 0;
      if (nv > 1) {
        final p = t * (nv - 1);
        vi = math.min(p.floor(), nv - 2);
        vf = _smooth(p - vi);
      }
      final fa = _formants[s.vowels[vi]]!;
      final fb = _formants[s.vowels[nv > 1 ? vi + 1 : vi]]!;

      // Three resonators (state-variable filters) with real bandwidths.
      double y = 0;
      for (int k = 0; k < 3; k++) {
        final fc =
            (fa[k] + (fb[k] - fa[k]) * vf) *
            s.size *
            _formantLift *
            math.sqrt(s.pitchScale); // formants follow pitch a little
        final qi = _bw[k] / fc; // 1/Q from a real bandwidth
        final f = 2 * math.sin(math.pi * fc / _sr);
        low[k] += f * band[k];
        final high = src - low[k] - qi * band[k];
        band[k] += f * high;
        y += band[k] * qi * _fGain[k];
      }

      final env =
          math.min(1.0, sec / att) *
          math.min(1.0, (s.dur - sec) / rel) *
          math.exp(-s.decay * t);
      out[i] = y * env * s.vol;
    }
    return out;
  }

  // One-pole low-pass: smaller alpha = darker/softer.
  static Float64List _lowpass(Float64List x, double alpha) {
    final out = Float64List(x.length);
    double y = 0;
    for (int i = 0; i < x.length; i++) {
      y += alpha * (x[i] - y);
      out[i] = y;
    }
    return out;
  }

  // Linear-interpolation resampler. ratio > 1 = higher pitch and faster.
  static Float64List _resample(Float64List x, double ratio) {
    final n = (x.length / ratio).floor();
    final out = Float64List(n);
    for (int i = 0; i < n; i++) {
      final p = i * ratio;
      final j = p.floor();
      final fr = p - j;
      final a = x[j];
      final b = j + 1 < x.length ? x[j + 1] : 0.0;
      out[i] = a + (b - a) * fr;
    }
    return out;
  }

  // Scale so the loudest sample hits [peak]; every emotion is equally loud.
  static Float64List _normalize(Float64List x, {double peak = 0.8}) {
    double max = 0;
    for (final s in x) {
      if (s.abs() > max) max = s.abs();
    }
    if (max == 0) return x;
    final k = peak / max;
    final out = Float64List(x.length);
    for (int i = 0; i < x.length; i++) {
      out[i] = x[i] * k;
    }
    return out;
  }

  // Mixes syllables, each starting at its own time, speeds the result up,
  // then softens it.
  static Float64List _speak(List<_Syl> syllables) {
    final mixed = SfxSynth.mix([
      for (final s in syllables)
        s.at == 0 ? _syl(s) : SfxSynth.delay(_syl(s), s.at),
    ]);
    final shifted = _resample(mixed, _speedUp);
    return _lowpass(_normalize(shifted, peak: 0.7), 0.8);
  }

  // "sss" consonant: high-passed noise with a soft fade in and out.
  static Float64List _hiss(
    double seconds, {
    double vol = 0.2,
    double attack = 0.06,
    double decay = 2.0,
  }) {
    final rnd = math.Random(11);
    final n = (_sr * seconds).toInt();
    final out = Float64List(n);
    double x1 = 0, x2 = 0;
    for (int i = 0; i < n; i++) {
      final x0 = rnd.nextDouble() * 2 - 1;
      final hp = x0 - 2 * x1 + x2; // second difference = strong high-pass
      x2 = x1;
      x1 = x0;
      final t = i / n;
      final sec = i / _sr;
      final env =
          math.min(1.0, sec / attack) *
          math.min(1.0, (seconds - sec) / 0.12) *
          math.exp(-decay * t);
      out[i] = hp * 0.25 * env * vol;
    }
    return out;
  }

  static Float64List _at(Float64List b, double seconds) =>
      seconds == 0 ? b : SfxSynth.delay(b, seconds);

  static Uint8List _wav(
    Float64List voice, {
    List<Float64List> extras = const [],
  }) => SfxSynth.toWav(_normalize(SfxSynth.mix([voice, ...extras])));

  // EMOTIONS (character voice)

  /// Synthesizes Curio's bright, rising "woo-hoo" reaction.
  static Uint8List veryHappy() => _wav(
    _speak(const [
      _Syl(
        0.00,
        0.45,
        pitch: [300, 420, 500],
        vowels: [_V.u, _V.o, _V.u],
        attack: 0.03,
        release: 0.06,
      ),
      // "h" breath between the two
      _Syl(
        0.52,
        0.10,
        pitch: [480, 500],
        vowels: [_V.o],
        breath: 1.0,
        vol: 0.4,
        attack: 0.01,
        release: 0.04,
      ),
      _Syl(
        0.58,
        0.90,
        pitch: [480, 700, 760, 620],
        vowels: [_V.o, _V.o, _V.u],
        vibrato: 0.03,
        vibHz: 6,
        vibFade: 0.3,
        attack: 0.02,
        release: 0.3,
      ),
    ]),
  );

  /// Synthesizes Curio's long, drooping disappointed reaction.
  static Uint8List veryDisappointed() => _wav(
    _speak(const [
      _Syl(
        0.00,
        1.5,
        pitch: [440, 470, 390, 310, 240],
        vowels: [_V.o, _V.o, _V.u],
        vibrato: 0.03,
        vibHz: 4.5,
        breath: 0.07,
        attack: 0.12,
        release: 0.5,
        decay: 0.5,
      ),
    ]),
  );

  /// Synthesizes a low, rough angry reaction.
  /// The larger mouth setting keeps the voice low after playback speed-up.
  static Uint8List angry() => _wav(
    _speak(const [
      _Syl(
        0.00,
        0.40,
        pitch: [150, 135, 115],
        vowels: [_V.a, _V.o],
        size: 0.9,
        growl: 0.8,
        growlHz: 50,
        jitter: 0.04,
        breath: 0.1,
        attack: 0.03,
        release: 0.12,
      ),
      _Syl(
        0.46,
        0.38,
        pitch: [155, 135, 108],
        vowels: [_V.a, _V.o],
        size: 0.9,
        growl: 0.8,
        growlHz: 58,
        jitter: 0.04,
        breath: 0.1,
        attack: 0.03,
        release: 0.12,
      ),
      _Syl(
        0.90,
        0.25,
        pitch: [260, 200],
        vowels: [_V.a],
        size: 0.95,
        growl: 0.45,
        growlHz: 60,
        jitter: 0.03,
        breath: 0.25,
        decay: 1.5,
        attack: 0.01,
      ),
    ]),
  );

  /// Synthesizes a fast-rising, sustained surprised reaction.
  static Uint8List verySurprised() => _wav(
    _speak(const [
      _Syl(
        0.00,
        1.4,
        pitch: [330, 520, 640, 610, 480, 400],
        vowels: [_V.u, _V.o, _V.a, _V.a, _V.a],
        vibrato: 0.03,
        vibHz: 5.5,
        vibFade: 0.5,
        breath: 0.03,
        attack: 0.03,
        release: 0.5,
      ),
    ]),
  );

  /// Synthesizes a quick, energetic celebratory reaction.
  static Uint8List excited() => _wav(
    _speak(<_Syl>[
      for (int i = 0; i < 3; i++)
        _Syl(
          i * 0.13,
          0.10,
          pitch: [500 + i * 50.0, 540 + i * 55.0],
          vowels: const [_V.a],
          breath: 0.3,
          decay: 1.5,
          attack: 0.01,
          release: 0.04,
        ),
      const _Syl(
        0.46,
        0.5,
        pitch: [560, 760, 860, 800],
        vowels: [_V.e, _V.i],
        vibrato: 0.025,
        vibHz: 7,
        attack: 0.02,
        release: 0.2,
      ),
    ]),
  );

  /// Synthesizes a relaxed reaction that settles into a long vowel.
  static Uint8List satisfied() => _wav(
    _speak(const [
      _Syl(
        0.00,
        0.40,
        pitch: [300, 320, 300],
        vowels: [_V.u],
        vol: 0.6,
        vibrato: 0.015,
        attack: 0.08,
        release: 0.12,
      ),
      _Syl(
        0.42,
        1.0,
        pitch: [420, 410, 360, 300],
        vowels: [_V.o, _V.a, _V.o],
        breath: 0.15,
        vibrato: 0.02,
        vibHz: 4.5,
        attack: 0.08,
        release: 0.4,
        decay: 0.8,
      ),
    ]),
  );

  /// Synthesizes a breathy, accelerating nervous reaction for looping playback.
  static Uint8List stressed() {
    final syllables = <_Syl>[];
    double t = 0;
    double gap = 0.2;
    for (int i = 0; i < 8; i++) {
      syllables.add(
        _Syl(
          t,
          0.08,
          pitch: [600 + i * 25.0, 680 + i * 25.0],
          vowels: const [_V.e],
          breath: 0.3,
          vibrato: 0.04,
          vibHz: 14,
          vibFade: 0.0,
          decay: 2,
          attack: 0.01,
          release: 0.03,
        ),
      );
      t += gap;
      gap *= 0.82;
    }
    final voice = _speak(syllables);
    // Trailing pause so the loop breathes before restarting
    // (divided by _speedUp because the voice was resampled).
    final padded = SfxSynth.mix([
      voice,
      SfxSynth.delay(SfxSynth.silence(0.01), (t + 0.35) / _speedUp),
    ]);
    return _wav(padded);
  }

  /// Synthesizes a confident reaction ending in a sustained airy sound.
  static Uint8List proud() {
    final voice = _speak(const [
      _Syl(
        0.00,
        0.50,
        pitch: [400, 560, 640, 600, 560],
        vowels: [_V.i, _V.e, _V.e],
        vibrato: 0.02,
        vibHz: 5.5,
        breath: 0.04,
        attack: 0.03,
        release: 0.12,
      ),
    ]);
    // The hiss is not resampled, so scale its start and length by hand.
    return _wav(
      voice,
      extras: [
        _at(_hiss(0.65 / _speedUp, vol: 0.22, decay: 2.2), 0.42 / _speedUp),
      ],
    );
  }
}
