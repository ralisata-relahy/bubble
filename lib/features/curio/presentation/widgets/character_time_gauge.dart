import 'dart:async';
import 'dart:math' as math;

import 'package:bubble/core/services/audio/sound_effect.dart';
import 'package:flutter/material.dart';

import 'character_backup_widget.dart';

/// Visual countdown gauge that maps remaining time ratio to Curio's facial mood.
class CharacterTimeGauge extends StatefulWidget {
  const CharacterTimeGauge({
    super.key,
    required this.duration,
    this.onFinished,
    this.barHeight,
    this.barWidth = 20,
    this.characterSize = const Size(120, 113), // Aspect ratio approx 680 / 640
    this.autoStart = true,
    this.isCriticalNotifier,
    this.isTimerPausedNotifier,
    this.soundEffects,
  });

  final Duration duration;
  final VoidCallback? onFinished;
  final double? barHeight;
  final double barWidth;
  final Size characterSize;
  final bool autoStart;
  final ValueNotifier<bool>? isCriticalNotifier;
  final ValueNotifier<bool>? isTimerPausedNotifier;
  final SoundEffects? soundEffects;

  @override
  State<CharacterTimeGauge> createState() => CharacterTimeGaugeState();
}

/// State controller for the character time countdown gauge.
class CharacterTimeGaugeState extends State<CharacterTimeGauge>
    with TickerProviderStateMixin {
  static const _criticalTimeThreshold = 0.3;
  static const _criticalAlertInterval = Duration(seconds: 1);
  static const _pulseDuration = Duration(milliseconds: 1600);

  late final AnimationController _ctrl;
  late final AnimationController _pulse;
  final ValueNotifier<bool> isCriticalNotifier = ValueNotifier<bool>(false);

  /// Normalized remaining time: 1.0 is full and 0.0 is expired.
  double get remaining => 1 - _ctrl.value;

  int _lastAlertTimestamp = 0;
  bool _wasCritical = false;

  @override
  void initState() {
    super.initState();
    widget.isTimerPausedNotifier?.addListener(_onTimerPauseChanged);
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(() {
        final r = 1 - _ctrl.value;
        final isCritical = r <= _criticalTimeThreshold && r > 0;
        // Notify the overlay only when the threshold changes; the gauge itself
        // still follows the animation controller on every frame.
        if (isCriticalNotifier.value != isCritical) {
          isCriticalNotifier.value = isCritical;
        }
        final externalCriticalNotifier = widget.isCriticalNotifier;
        if (externalCriticalNotifier != null &&
            externalCriticalNotifier.value != isCritical) {
          externalCriticalNotifier.value = isCritical;
        }

        if (isCritical) {
          final now = DateTime.now().millisecondsSinceEpoch;
          // Repeat the alert at a fixed wall-clock interval rather than per frame.
          if (!_wasCritical ||
              now - _lastAlertTimestamp >=
                  _criticalAlertInterval.inMilliseconds) {
            _lastAlertTimestamp = now;
            final effects = widget.soundEffects;
            if (effects != null) unawaited(effects.play(Sfx.alert));
          }
        } else {
          _lastAlertTimestamp = 0;
        }
        _wasCritical = isCritical;
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished?.call();
      });
    _pulse = AnimationController(vsync: this, duration: _pulseDuration)
      ..repeat(reverse: true);
    if (widget.autoStart) _ctrl.forward();
  }

  void _onTimerPauseChanged() {
    if (widget.isTimerPausedNotifier?.value == true) {
      pause();
    } else {
      resume();
    }
  }

  /// Restarts, pauses, or resumes the countdown from the game engine.
  void restart({Duration? duration}) {
    if (duration != null) {
      _ctrl.duration = duration;
    }
    isCriticalNotifier.value = false;
    widget.isCriticalNotifier?.value = false;
    _lastAlertTimestamp = 0;
    _wasCritical = false;
    _pulse.repeat(reverse: true);
    _ctrl.forward(from: 0);
  }

  void pause() {
    _ctrl.stop();
    _pulse.stop();
  }

  void resume() {
    _ctrl.forward();
    _pulse.repeat(reverse: true);
  }

  /// Adds or subtracts a fraction of total game duration to/from the countdown timer.
  /// A negative value represents a time penalty.
  void addTime(double fraction) {
    final wasRunning = _ctrl.isAnimating;
    final nextValue = (_ctrl.value - fraction).clamp(0.0, 1.0);

    // Audio feedback based on time bonus or penalty
    if (fraction > 0) {
      final effects = widget.soundEffects;
      if (effects != null) unawaited(effects.play(Sfx.redForming));
    } else if (fraction < 0) {
      final effects = widget.soundEffects;
      if (effects != null) unawaited(effects.play(Sfx.beamIncorrect));
    }

    _ctrl.value = nextValue;
    if (nextValue >= 1.0) {
      widget.onFinished?.call();
      return;
    }
    if (wasRunning && widget.isTimerPausedNotifier?.value != true) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    widget.isTimerPausedNotifier?.removeListener(_onTimerPauseChanged);
    isCriticalNotifier.dispose();
    _ctrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Maps remaining time ratio to Curio's corresponding mood.
  Mood _moodFor(double r) {
    if (r > 0.66) return Mood.excited;
    if (r > 0.33) return Mood.stressed;
    if (r > 0.11) return Mood.disapointed;
    if (r > 0.01) return Mood.sad;
    return Mood.sleepy;
  }

  /// Neon bar glow color interpolated based on remaining time.
  Color _glowColor(double r) {
    if (r > 0.66) {
      return const Color(0xFF00E5FF); // Electric Cyan
    } else if (r > 0.33) {
      return const Color(0xFFFFB300); // Amber warning
    } else if (r > 0.11) {
      return const Color(0xFFFF3D00); // Crimson urgency
    } else {
      return const Color(0xFFFF1744); // Critical Red
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ch = widget.characterSize.height;
        final cw = widget.characterSize.width;
        final bh =
            widget.barHeight ?? math.max(120.0, constraints.maxHeight - ch);
        final bw = widget.barWidth;

        return SizedBox(
          width: cw,
          height: bh + ch,
          child: AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _pulse]),
            builder: (context, _) {
              final r = 1 - _ctrl.value;
              final glow = _glowColor(r);
              final fillHeight = bh * r;

              // Accelerated pulsing when remaining time is low
              final urgency = r < 0.2 ? 1.0 : 0.0;
              final pulse = 0.55 + 0.45 * _pulse.value;
              final intensity = urgency > 0 ? 0.6 + 0.4 * _pulse.value : pulse;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Diffuse aura behind the gauge tube
                  Positioned(
                    left: (cw - bw) / 2,
                    top: ch / 2,
                    width: bw,
                    height: bh,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(bw / 2),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.35 * intensity),
                            blurRadius: 26,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dark glass tube with outer neon border
                  Positioned(
                    left: (cw - bw) / 2,
                    top: ch / 2,
                    width: bw,
                    height: bh,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(bw / 2),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xCC0B0B24),
                            Color(0xCC1A1240),
                            Color(0xCC0B0B24),
                          ],
                        ),
                        border: Border.all(
                          color: glow.withValues(alpha: 0.75),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.5 * intensity),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Energy level liquid fill
                  Positioned(
                    left: (cw - bw) / 2 + 3,
                    top: ch / 2 + 3 + (bh - 6 - (bh - 6) * r),
                    width: bw - 6,
                    height: math.max(0, (bh - 6) * r),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular((bw - 6) / 2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            glow,
                            Color.lerp(glow, const Color(0xFF6A1B9A), 0.7)!,
                          ],
                          stops: const [0.0, 0.18, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.9 * intensity),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Ticks / illuminated graduations on the tube
                  Positioned(
                    left: (cw - bw) / 2,
                    top: ch / 2,
                    width: bw,
                    height: bh,
                    child: IgnorePointer(
                      child: CustomPaint(painter: _TicksPainter(color: glow)),
                    ),
                  ),

                  // Glowing aura behind character
                  Positioned(
                    left: 0,
                    top: bh - fillHeight,
                    width: cw,
                    height: ch,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.35 * intensity),
                            blurRadius: 30,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Mascot character positioned on the current level
                  Positioned(
                    left: 0,
                    top: bh - fillHeight,
                    width: cw,
                    height: ch,
                    child: CharacterBackupWidget(
                      size: widget.characterSize,
                      mood: _moodFor(r),
                      isPausedNotifier: widget.isTimerPausedNotifier,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Small illuminated tick marks on the tube edge.
class _TicksPainter extends CustomPainter {
  _TicksPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const count = 10;
    for (var i = 1; i < count; i++) {
      final y = size.height * i / count;
      final long = i % 5 == 0;
      final len = long ? size.width * 0.45 : size.width * 0.25;
      canvas.drawLine(
        Offset(size.width - len - 4, y),
        Offset(size.width - 4, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TicksPainter old) => old.color != color;
}
