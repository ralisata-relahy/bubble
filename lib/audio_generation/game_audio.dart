import 'dart:math' as math;
import 'dart:typed_data';

import 'sfx_generate.dart';

double _midi(int n) => 440 * math.pow(2, (n - 69) / 12).toDouble();

Float64List _blank(double seconds) =>
    Float64List((SfxSynth.sampleRate * seconds).toInt());

void _place(Float64List out, Float64List b, double atSeconds) {
  final offset = (SfxSynth.sampleRate * atSeconds).toInt();
  for (int i = 0; i < b.length && offset + i < out.length; i++) {
    out[offset + i] += b[i];
  }
}

// Smooth fade-out
void _fadeOut(Float64List out, double seconds) {
  final len = (SfxSynth.sampleRate * seconds).toInt();
  final start = out.length - len;
  if (start < 0) return;
  for (int i = 0; i < len; i++) {
    final k = 1 - i / len; // 1 -> 0
    out[start + i] *= k * k; // quadratic = gentle tail
  }
}

// Splash screen sting
class SplashSfx {
  static Uint8List splash() {
    final out = _blank(2.8);

    // Cartoon "boing" at the very start
    _place(
      out,
      SfxSynth.tone(
        startHz: 250,
        endHz: 700,
        seconds: 0.2,
        volume: 0.3,
        wave: Wave.triangle,
        decay: 3,
      ),
      0.0,
    );

    // Rising arpeggio C5-E5-G5-C6
    const arp = [523.3, 659.3, 784.0, 1046.5];
    for (var i = 0; i < arp.length; i++) {
      _place(
        out,
        SfxSynth.chime(hz: arp[i], seconds: 0.45, volume: 0.28),
        0.12 + i * 0.12,
      );
    }

    // Final chord (C major) + low thump, softer than before
    const chord = [1046.5, 1318.5, 1568.0, 2093.0];
    for (final hz in chord) {
      _place(out, SfxSynth.chime(hz: hz, seconds: 2.0, volume: 0.12), 0.65);
    }
    _place(
      out,
      SfxSynth.tone(
        startHz: 140,
        endHz: 60,
        seconds: 0.3,
        volume: 0.3,
        decay: 5,
      ),
      0.65,
    );

    // Sparkles, quieter
    for (var i = 0; i < 8; i++) {
      _place(
        out,
        SfxSynth.tone(
          startHz: 3000 + i * 300,
          endHz: 4200 + i * 250,
          seconds: 0.06,
          volume: 0.05,
          decay: 5,
        ),
        0.95 + i * 0.1,
      );
    }

    // Gentle fade so the end tapers off instead of ringing at full level.
    _fadeOut(out, 1.2);

    return SfxSynth.toWav(out);
  }
}

// Cartoonish background music
class GameMusic {
  static const double bpm = 132;
  static const double beat = 60 / bpm;
  static const int bars = 8;

  // Root of the bass
  static const _bass = [48, 45, 41, 43, 48, 45, 41, 43];

  // Chord stabs
  static const _chords = [
    [60, 64, 67], // C
    [57, 60, 64], // Am
    [57, 60, 65], // F
    [59, 62, 67], // G
    [60, 64, 67],
    [57, 60, 64],
    [57, 60, 65],
    [59, 62, 67],
  ];

  // Melody: 8 eighth-notes per bar
  static const _melody = [
    [72, 0, 76, 0, 79, 76, 72, 0],
    [69, 0, 72, 0, 76, 72, 69, 0],
    [72, 0, 77, 0, 81, 77, 72, 0],
    [74, 0, 79, 77, 76, 74, 71, 0],
    [72, 76, 79, 0, 84, 0, 79, 0],
    [81, 0, 79, 76, 72, 0, 76, 0],
    [77, 77, 0, 72, 77, 0, 81, 0],
    [79, 0, 77, 76, 74, 0, 67, 0],
  ];

  static Uint8List cartoonLoop() {
    final total = bars * 4 * beat;
    final out = _blank(total);

    for (var bar = 0; bar < bars; bar++) {
      final barStart = bar * 4 * beat;

      // Bass
      for (var b = 0; b < 4; b++) {
        final n = _bass[bar] + (b.isOdd ? 7 : 0);
        _place(
          out,
          SfxSynth.tone(
            startHz: _midi(n),
            endHz: _midi(n),
            seconds: beat * 0.45,
            volume: 0.25,
            wave: Wave.triangle,
            decay: 2,
          ),
          barStart + b * beat,
        );
      }

      // Off-beat chord stabs
      for (var b = 0; b < 4; b++) {
        for (final n in _chords[bar]) {
          _place(
            out,
            SfxSynth.tone(
              startHz: _midi(n),
              endHz: _midi(n),
              seconds: beat * 0.3,
              volume: 0.05,
              wave: Wave.square,
              decay: 5,
            ),
            barStart + (b + 0.5) * beat,
          );
        }
      }

      // Melody
      for (var i = 0; i < 8; i++) {
        final n = _melody[bar][i];
        if (n == 0) continue;
        _place(
          out,
          SfxSynth.tone(
            startHz: _midi(n),
            endHz: _midi(n),
            seconds: beat * 0.42,
            volume: 0.1,
            wave: Wave.square,
            decay: 3,
          ),
          barStart + i * beat / 2,
        );
      }

      // Drums
      for (var b = 0; b < 4; b++) {
        final t = barStart + b * beat;
        if (b.isEven) {
          _place(
            out,
            SfxSynth.tone(
              startHz: 150,
              endHz: 50,
              seconds: 0.12,
              volume: 0.35,
              decay: 5,
            ),
            t,
          );
        } else {
          _place(
            out,
            SfxSynth.softNoise(
              seconds: 0.08,
              volume: 0.18,
              decay: 6,
              smoothing: 0.3,
            ),
            t,
          );
        }
        for (var h = 0; h < 2; h++) {
          _place(
            out,
            SfxSynth.softNoise(
              seconds: 0.03,
              volume: 0.08,
              decay: 10,
              smoothing: 0.1,
            ),
            t + h * beat / 2,
          );
        }
      }
    }

    return SfxSynth.toWav(out);
  }
}