import 'dart:math' as math;
import 'dart:typed_data';

class SfxSynth {
  static const int sampleRate = 44100;

  // Silence, used to leave a pause at the end of a looping sound.
  static Float64List silence(double seconds) =>
      Float64List((sampleRate * seconds).toInt());

  // Frequency sweep with an envelope.
  static Float64List sweep({
    required double startHz,
    required double endHz,
    required double seconds,
    double volume = 0.6,
    Wave wave = Wave.sine,
  }) {
    final n = (sampleRate * seconds).toInt();
    final out = Float64List(n);
    double phase = 0;
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final hz = startHz + (endHz - startHz) * t;
      phase += 2 * math.pi * hz / sampleRate;
      final env = _envelope(t);
      out[i] = _osc(wave, phase) * env * volume;
    }
    return out;
  }

  // Flexible tone: exponential pitch sweep, soft attack, exponential decay.
  static Float64List tone({
    required double startHz,
    required double endHz,
    required double seconds,
    double volume = 0.5,
    Wave wave = Wave.sine,
    double attack = 0.005,
    double decay = 4.0, // higher = shorter
  }) {
    final n = (sampleRate * seconds).toInt();
    final out = Float64List(n);
    final tail = sampleRate * 0.005; // 5ms fade-out to avoid clicks
    double phase = 0;
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final sec = i / sampleRate;
      final hz = startHz * math.pow(endHz / startHz, t).toDouble();
      phase += 2 * math.pi * hz / sampleRate;
      final a = sec < attack ? sec / attack : 1.0;
      final fadeOut = math.min(1.0, (n - i) / tail);
      out[i] = _osc(wave, phase) * a * math.exp(-decay * t) * fadeOut * volume;
    }
    return out;
  }

  // Noise burst with exponential decay.
  static Float64List noise({required double seconds, double volume = 0.5}) {
    final rnd = math.Random();
    final n = (sampleRate * seconds).toInt();
    final out = Float64List(n);
    for (int i = 0; i < n; i++) {
      final t = i / n;
      out[i] = (rnd.nextDouble() * 2 - 1) * math.exp(-6 * t) * volume;
    }
    return out;
  }

  // Low-passed noise (soft "pff" instead of harsh static).
  static Float64List softNoise({
    required double seconds,
    double volume = 0.5,
    double decay = 8,
    double smoothing = 0.8, // 0..1, higher = darker/softer
  }) {
    final rnd = math.Random();
    final n = (sampleRate * seconds).toInt();
    final out = Float64List(n);
    double prev = 0;
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final raw = rnd.nextDouble() * 2 - 1;
      prev = prev * smoothing + raw * (1 - smoothing);
      out[i] = prev * math.exp(-decay * t) * volume;
    }
    return out;
  }

  // Bell/chime note: fundamental + decaying harmonics.
  static Float64List chime({
    required double hz,
    required double seconds,
    double volume = 0.3,
  }) {
    final n = (sampleRate * seconds).toInt();
    final out = Float64List(n);
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final sec = i / sampleRate;
      final a = sec < 0.003 ? sec / 0.003 : 1.0;
      final fundamental = math.sin(2 * math.pi * hz * sec) * math.exp(-4 * t);
      final h2 = math.sin(2 * math.pi * hz * 2 * sec) * 0.35 * math.exp(-7 * t);
      final h3 =
          math.sin(2 * math.pi * hz * 3 * sec) * 0.12 * math.exp(-10 * t);
      out[i] = (fundamental + h2 + h3) * a * volume;
    }
    return out;
  }

  // Mix several buffers (different lengths allowed).
  static Float64List mix(List<Float64List> buffers) {
    final len = buffers.map((b) => b.length).reduce(math.max);
    final out = Float64List(len);
    for (final b in buffers) {
      for (int i = 0; i < b.length; i++) {
        out[i] += b[i];
      }
    }
    return out;
  }

  // Place a buffer after a delay.
  static Float64List delay(Float64List b, double seconds) {
    final offset = (sampleRate * seconds).toInt();
    final out = Float64List(offset + b.length);
    out.setRange(offset, offset + b.length, b);
    return out;
  }

  // Attack/decay envelope to avoid clicks.
  static double _envelope(double t) {
    const attack = 0.05;
    if (t < attack) return t / attack;
    return math.pow(1 - (t - attack) / (1 - attack), 1.5).toDouble();
  }

  static double _osc(Wave w, double phase) {
    switch (w) {
      case Wave.sine:
        return math.sin(phase);
      case Wave.square:
        return math.sin(phase) >= 0 ? 1.0 : -1.0;
      case Wave.saw:
        return 2 * ((phase / (2 * math.pi)) % 1.0) - 1;
      case Wave.triangle:
        return 2 * (2 * ((phase / (2 * math.pi)) % 1.0) - 1).abs() - 1;
    }
  }

  // Convert samples to a 16-bit mono WAV in memory.
  static Uint8List toWav(Float64List samples) {
    final dataSize = samples.length * 2;
    final bytes = ByteData(44 + dataSize);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        bytes.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i].clamp(-1.0, 1.0);
      bytes.setInt16(44 + i * 2, (s * 32767).toInt(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}

enum Wave { sine, square, saw, triangle }

// Synthesized game and interface sounds.
class GameSfx {
  // Bubble pop: a tiny soft click plus a quick rising "bloop" chirp.
  static Uint8List bubbleBurst() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.softNoise(seconds: 0.03, volume: 0.6, decay: 5, smoothing: 0.6),
      SfxSynth.tone(
        startHz: 500,
        endHz: 1500,
        seconds: 0.07,
        volume: 0.6,
        decay: 5,
      ),
      SfxSynth.delay(
        SfxSynth.tone(
          startHz: 900,
          endHz: 2200,
          seconds: 0.05,
          volume: 0.25,
          decay: 6,
        ),
        0.012,
      ),
    ]),
  );

  // Soft "uh-oh": two gentle descending sine notes, no buzz.
  static Uint8List beamIncorrect() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.tone(
        startHz: 330,
        endHz: 294,
        seconds: 0.18,
        volume: 0.9,
        decay: 3,
        attack: 0.02,
      ),
      SfxSynth.delay(
        SfxSynth.tone(
          startHz: 262,
          endHz: 220,
          seconds: 0.28,
          volume: 0.9,
          decay: 3.5,
          attack: 0.02,
        ),
        0.14,
      ),
    ]),
  );

  static Uint8List redBubbleForming() => SfxSynth.toWav(
    SfxSynth.sweep(startHz: 200, endHz: 650, seconds: 0.45, volume: 0.5),
  );

  // Short, bright laser zap with a sharp attack and a fast falling pitch.
  static Uint8List laser() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.noise(seconds: 0.025, volume: 0.18),
      SfxSynth.tone(
        startHz: 1500,
        endHz: 180,
        seconds: 0.4,
        volume: 0.32,
        wave: Wave.saw,
        attack: 0.002,
        decay: 6,
      ),
      SfxSynth.delay(
        SfxSynth.tone(
          startHz: 3000,
          endHz: 40,
          seconds: 0.25,
          volume: 0.15,
          attack: 0.002,
          decay: 7,
        ),
        0.015,
      ),
    ]),
  );

  // "Correct answer" chime: quick rising C-E-G arpeggio, last note rings.
  static Uint8List beamCorrect() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.chime(hz: 1046.5, seconds: 0.35), // C6
      SfxSynth.delay(SfxSynth.chime(hz: 1318.5, seconds: 0.35), 0.08),
      SfxSynth.delay(
        SfxSynth.chime(hz: 1568.0, seconds: 0.6, volume: 0.35),
        0.16,
      ),
    ]),
  );

  static Uint8List bubbleSplit() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.sweep(startHz: 700, endHz: 800, seconds: 0.07, volume: 0.5),
      SfxSynth.delay(
        SfxSynth.sweep(startHz: 900, endHz: 1000, seconds: 0.07, volume: 0.5),
        0.06,
      ),
    ]),
  );

  // Heavy alert: one single strike (all layers start together), then a pause.
  static Uint8List alert() => SfxSynth.toWav(
    SfxSynth.mix([
      // Main bell tone (E5), long ring.
      SfxSynth.chime(hz: 659.3, seconds: 0.8, volume: 0.42),

      // Heavy low body, an octave below, same instant.
      SfxSynth.tone(
        startHz: 330,
        endHz: 315,
        seconds: 0.55,
        volume: 0.38,
        wave: Wave.triangle,
        attack: 0.003,
        decay: 3,
      ),

      // Sub weight for the "heavy" feel.
      SfxSynth.tone(
        startHz: 165,
        endHz: 160,
        seconds: 0.4,
        volume: 0.2,
        attack: 0.004,
        decay: 4,
      ),

      // Short square edge so it cuts through.
      SfxSynth.tone(
        startHz: 659.3,
        endHz: 620,
        seconds: 0.15,
        volume: 0.08,
        wave: Wave.square,
        attack: 0.002,
        decay: 6,
      ),

      // Tiny soft transient for the "strike".
      SfxSynth.softNoise(seconds: 0.02, volume: 0.25, decay: 6, smoothing: 0.7),

      SfxSynth.silence(0.5), // keeps a pause at the end of the loop
    ]),
  );

  // Basic click: a soft, low "thock" instead of a sharp tick.
  static Uint8List click() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.tone(
        startHz: 480,
        endHz: 280,
        seconds: 0.06,
        volume: 0.7,
        decay: 5,
        attack: 0.003,
      ),
      SfxSynth.softNoise(
        seconds: 0.015,
        volume: 0.8,
        decay: 6,
        smoothing: 0.85,
      ),
    ]),
  );

  // Switch ON: two quick rising blips.
  static Uint8List switchOn() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.tone(
        startHz: 500,
        endHz: 700,
        seconds: 0.06,
        volume: 0.5,
        decay: 4,
      ),
      SfxSynth.delay(
        SfxSynth.tone(
          startHz: 800,
          endHz: 1100,
          seconds: 0.08,
          volume: 0.5,
          decay: 5,
        ),
        0.05,
      ),
    ]),
  );

  // Switch OFF: the same idea, falling.
  static Uint8List switchOff() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.tone(
        startHz: 800,
        endHz: 600,
        seconds: 0.06,
        volume: 0.5,
        decay: 4,
      ),
      SfxSynth.delay(
        SfxSynth.tone(
          startHz: 550,
          endHz: 380,
          seconds: 0.08,
          volume: 0.5,
          decay: 5,
        ),
        0.05,
      ),
    ]),
  );

  // Scroll tick: tiny and quiet, meant to fire many times.
  static Uint8List tick() => SfxSynth.toWav(
    SfxSynth.tone(
      startHz: 2600,
      endHz: 2200,
      seconds: 0.014,
      volume: 0.35,
      decay: 5,
      attack: 0.001,
    ),
  );

  // Pop-up open: a soft rising "bloop" with a light sparkle.
  static Uint8List popupOpen() => SfxSynth.toWav(
    SfxSynth.mix([
      SfxSynth.tone(
        startHz: 350,
        endHz: 900,
        seconds: 0.11,
        volume: 0.55,
        decay: 4,
        attack: 0.008,
      ),
      SfxSynth.delay(
        SfxSynth.tone(
          startHz: 700,
          endHz: 1400,
          seconds: 0.07,
          volume: 0.2,
          decay: 5,
        ),
        0.02,
      ),
    ]),
  );

  // Pop-up close: the open sound reversed in pitch.
  static Uint8List popupClose() => SfxSynth.toWav(
    SfxSynth.tone(
      startHz: 900,
      endHz: 350,
      seconds: 0.10,
      volume: 0.5,
      decay: 4,
      attack: 0.005,
    ),
  );
}
