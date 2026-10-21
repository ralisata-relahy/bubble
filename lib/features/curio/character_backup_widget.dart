import 'dart:async';
import 'dart:math' show min;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'character_backup_painter.dart';

export 'character_backup_painter.dart' show Mood;

/// Personnage animé.
///
///   CharacterBackupWidget(mood: Mood.happy)
///   CharacterBackupWidget(mood: _mood, onTap: () => debugPrint('tap'))
///
/// Changer `mood` fait glisser en douceur toutes les expressions (~450 ms).
/// Un tap fait sauter le personnage (désactivable avec hopOnTap: false).
class CharacterBackupWidget extends StatefulWidget {
  const CharacterBackupWidget({
    super.key,
    this.size = const Size(340, 320),
    this.mood = Mood.happy,
    this.onTap,
    this.hopOnTap = true,
  });

  /// Taille de référence du personnage. Le dessin a un rapport 680 / 640
  /// (≈ 1,0625), donc gardez largeur / hauteur proche de cette valeur
  /// pour éviter des marges vides.
  final Size size;

  final Mood mood;
  final VoidCallback? onTap;
  final bool hopOnTap;

  @override
  State<CharacterBackupWidget> createState() => _CharacterBackupWidgetState();
}

class _CharacterBackupWidgetState extends State<CharacterBackupWidget>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AudioPlayer _audioPlayer;
  int _soundRequest = 0;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final AnimationController _moodCtrl;
  late final AnimationController _hopCtrl;
  late final Listenable _repaint;

  late MoodParams _from;
  late MoodParams _to;

  @override
  void initState() {
    super.initState();
    _from = _to = MoodParams.of(widget.mood);
    _audioPlayer = AudioPlayer();
    unawaited(_playMoodSound(widget.mood));

    _moodCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1,
    );
    _hopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _repaint = Listenable.merge([_time, _moodCtrl, _hopCtrl]);

    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void didUpdateWidget(covariant CharacterBackupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      unawaited(_playMoodSound(widget.mood));
      // on part de l'état actuel pour éviter tout saut visuel
      _from = _current();
      _to = MoodParams.of(widget.mood);
      _moodCtrl.forward(from: 0);
    }
  }

  static const Map<Mood, String> _moodSounds = {
    Mood.happy: 'happy.mp3',
    Mood.excited: 'happy.mp3',
    Mood.surprised: 'surprised.mp3',
    Mood.sad: 'sad.mp3',
    Mood.angry: 'angry.mp3',
  };

  Future<void> _playMoodSound(Mood mood) async {
    final request = ++_soundRequest;
    await _audioPlayer.stop();
    final filename = _moodSounds[mood];
    if (filename == null || !mounted || request != _soundRequest) return;

    final assetPath = 'assets/audio/$filename';
    try {
      await rootBundle.load(assetPath);
      if (!mounted || request != _soundRequest) return;
      await _audioPlayer.play(AssetSource('audio/$filename'));
    } catch (_) {
      // Un son absent ou illisible reste silencieux.
    }
  }

  MoodParams _current() =>
      MoodParams.lerp(_from, _to, Curves.easeInOut.transform(_moodCtrl.value));

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_audioPlayer.dispose());
    _moodCtrl.dispose();
    _hopCtrl.dispose();
    _time.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.hopOnTap) _hopCtrl.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthScale = constraints.hasBoundedWidth
            ? constraints.maxWidth / size.width
            : 1.0;
        final heightScale = constraints.hasBoundedHeight
            ? constraints.maxHeight / size.height
            : 1.0;
        final scale = min(1.0, min(widthScale, heightScale));
        final fittedSize = Size(size.width * scale, size.height * scale);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: SizedBox(
            width: fittedSize.width,
            height: fittedSize.height,
            child: CustomPaint(
              size: fittedSize,
              painter: CharacterBackupPainter(
                time: _time,
                hop: _hopCtrl,
                params: _current,
                isMoodTransitioning: () => _moodCtrl.isAnimating,
                repaint: _repaint,
              ),
            ),
          ),
        );
      },
    );
  }
}
