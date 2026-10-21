# Audio generation

This module synthesizes short sound effects directly in Dart. It creates audio
samples in memory and encodes them as mono, 16-bit PCM WAV data at 44.1 kHz, so
the generated sounds do not need to be stored as audio asset files.

## Files

- [`sfx_generate.dart`](sfx_generate.dart) contains `SfxSynth`, the low-level
  waveform helpers, and `GameSfx`, the ready-made sound effects.
- `sound_effect.dart` and `sound_sfx.dart` are currently empty files.

Playback is handled separately by
[`lib/audio/sfx_audio.dart`](../lib/audio/sfx_audio.dart), which loads the WAV
bytes into SoLoud and exposes the app-facing `SfxPlayer` API.

## Available sound effects

`GameSfx` returns each effect as a `Uint8List` containing a WAV file:

| Method | Sound |
| --- | --- |
| `bubbleBurst()` | Soft click and rising bubble chirp |
| `beamIncorrect()` | Gentle two-note descending cue |
| `redBubbleForming()` | Rising frequency sweep |
| `beamCorrect()` | Rising C–E–G chime |
| `bubbleSplit()` | Two quick rising sweeps |
| `alert()` | Two-note chime with a pause for looping |
| `click()` | Soft, low click |
| `switchOn()` / `switchOff()` | Short rising / falling blips |
| `tick()` | Quiet, very short scroll tick |
| `popupOpen()` / `popupClose()` | Rising / falling popup cue |

## Generate a WAV

Import the generator from the app package and pass its bytes to an audio
backend, or write them to a file when developing or debugging:

```dart
import 'dart:io';

import 'package:ai_buddy/audio_generation/sfx_generate.dart';

Future<void> savePreview() async {
  final wavBytes = GameSfx.beamCorrect();
  await File('beam_correct.wav').writeAsBytes(wavBytes);
}
```

The generator is synchronous; it computes the samples and WAV bytes when the
method is called. Generate and cache sounds during initialization for playback
instead of regenerating them for every event.

## Synthesize a custom sound

`SfxSynth` exposes sample-level helpers. These helpers return `Float64List`
sample buffers; combine them as needed, then call `toWav` to encode them.

```dart
final samples = SfxSynth.mix([
  SfxSynth.tone(
    startHz: 440,
    endHz: 880,
    seconds: 0.2,
    wave: Wave.sine,
  ),
  SfxSynth.delay(
    SfxSynth.chime(hz: 1320, seconds: 0.3),
    0.12,
  ),
]);

final wavBytes = SfxSynth.toWav(samples);
```

Available building blocks are `silence`, `sweep`, `tone`, `noise`,
`softNoise`, `chime`, `mix`, `delay`, and `toWav`. `Wave` supports `sine`,
`square`, `saw`, and `triangle` oscillators. `mix` adds buffers sample by
sample and clamps the result to the valid WAV range during encoding.

## Playback in the app

Use `SfxPlayer` from `lib/audio/sfx_audio.dart` for app playback. Initialize it
once before requesting sounds:

```dart
await SfxPlayer.instance.init();
await SfxPlayer.instance.play(Sfx.beamCorrect);
```

`play` accepts an optional `volume` and `varyPitch` flag. The player also
provides `startLoop`, `stopLoop`, `toggleLoop`, and a throttled `tick` helper.
Call `dispose()` when the audio engine is no longer needed to release its
loaded sources.
