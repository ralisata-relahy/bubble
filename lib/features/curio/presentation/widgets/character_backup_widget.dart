import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'character_backup_painter.dart' show CharacterBackupPainter;
import '../../domain/models/mood.dart' show Mood, MoodParams;
import '../../services/curio_audio_service.dart';

export '../../domain/models/mood.dart' show Mood;

/// Animated Curio mascot widget.
///
///   CharacterBackupWidget(mood: Mood.happy)
///   CharacterBackupWidget(mood: _mood, onTap: () => debugPrint('tap'))
///
/// Changing `mood` smoothly interpolates all facial expressions (~450 ms).
/// Tapping causes the character to hop (can be disabled with hopOnTap: false).
class CharacterBackupWidget extends StatefulWidget {
  const CharacterBackupWidget({
    super.key,
    this.size = const Size(340, 320),
    this.mood = Mood.happy,
    this.onTap,
    this.hopOnTap = true,
    this.isPausedNotifier,
  });

  /// Reference size of the character. The artwork has an aspect ratio of 680 / 640
  /// (≈ 1.0625), so keep width / height close to this ratio to avoid letterboxing.
  final Size size;

  final Mood mood;
  final VoidCallback? onTap;
  final bool hopOnTap;
  final ValueNotifier<bool>? isPausedNotifier;

  @override
  State<CharacterBackupWidget> createState() => _CharacterBackupWidgetState();
}

/// Drives Curio's animation ticker and smooth transitions between moods.
class _CharacterBackupWidgetState extends State<CharacterBackupWidget>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final CurioAudioService _audioService;
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
    _audioService = CurioAudioService();
    unawaited(_audioService.playMood(widget.mood));

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

    widget.isPausedNotifier?.addListener(_onPauseChanged);
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    });
    if (widget.isPausedNotifier?.value != true) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant CharacterBackupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      unawaited(_audioService.playMood(widget.mood));
      // Start from the current interpolated state to avoid visual jumps.
      _from = _current();
      _to = MoodParams.of(widget.mood);
      _moodCtrl.forward(from: 0);
    }
  }

  MoodParams _current() =>
      MoodParams.lerp(_from, _to, Curves.easeInOut.transform(_moodCtrl.value));

  void _onPauseChanged() {
    if (widget.isPausedNotifier?.value == true) {
      if (_ticker.isActive) _ticker.stop();
    } else {
      if (!_ticker.isActive) _ticker.start();
    }
  }

  @override
  void dispose() {
    widget.isPausedNotifier?.removeListener(_onPauseChanged);
    _ticker.dispose();
    unawaited(_audioService.dispose());
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
