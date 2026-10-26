import 'dart:async';
import 'dart:math' as math;

import 'package:bubble/core/services/audio/sound_effect.dart';
import 'package:bubble/features/curio/character_backup_widget.dart';
import 'package:flutter/material.dart';

/// Compte à rebours visuel qui associe le niveau restant à l'humeur de Curio.
class CharacterTimeGauge extends StatefulWidget {
  const CharacterTimeGauge({
    super.key,
    required this.duration,
    this.onFinished,
    this.barHeight,
    this.barWidth = 20,
    this.characterSize = const Size(120, 113), // ≈ ratio 680 / 640
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

/// Contrôle les opérations de durée de vie du compte à rebours.
class CharacterTimeGaugeState extends State<CharacterTimeGauge>
    with TickerProviderStateMixin {
  static const _criticalTimeThreshold = 0.3;
  static const _criticalAlertInterval = Duration(seconds: 1);
  static const _pulseDuration = Duration(milliseconds: 1600);

  late final AnimationController _ctrl;
  late final AnimationController _pulse;
  final ValueNotifier<bool> isCriticalNotifier = ValueNotifier<bool>(false);

  /// Temps restant normalisé : 1 signifie plein et 0 signifie écoulé.
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

  /// Redémarre, suspend ou reprend l'animation depuis le jeu.
  void restart({Duration? duration}) {
    if (duration!=null){
      _ctrl.duration=duration;
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

  /// Ajoute une fraction de la durée totale au compte à rebours.
  /// Valeur négative = perte de temps.
  void addTime(double fraction) {
    final wasRunning = _ctrl.isAnimating;
    final nextValue = (_ctrl.value - fraction).clamp(0.0, 1.0);

    // Sons selon le sens de variation
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

  /// Associe une humeur à chaque tranche de temps restant.
  Mood _moodFor(double r) {
    if (r > 0.66) return Mood.excited;
    if (r > 0.33) return Mood.stressed;
    if (r > 0.01) return Mood.disapointed;
    return Mood.sleepy;
  }

  /// Couleur néon principale selon le temps restant.
  Color _glowColor(double r) {
    const cyan = Color(0xFF00E5FF);
    const violet = Color(0xFFB388FF);
    const alert = Color(0xFFFF1744);
    if (r > 0.5) return Color.lerp(violet, cyan, (r - 0.5) / 0.5)!;
    if (r > 0.2) return Color.lerp(alert, violet, (r - 0.2) / 0.3)!;
    return alert;
  }

  /// Dessine la jauge et place Curio au niveau de remplissage actuel.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = widget.characterSize.width;
        final ch = widget.characterSize.height;
        final bw = widget.barWidth;

        // Available height, or 80% of the screen if the parent is unbounded.
        final available = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.8;

        // The tube takes the remaining height after the character.
        final bh = widget.barHeight ?? math.max(0.0, available - ch);

        return SizedBox(
          width: cw,
          height: bh + ch,
          child: AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _pulse]),
            builder: (context, _) {
              final r = 1 - _ctrl.value;
              final glow = _glowColor(r);
              final fillHeight = bh * r;

              // Pulsation plus rapide quand il reste peu de temps
              final urgency = r < 0.2 ? 1.0 : 0.0;
              final pulse = 0.55 + 0.45 * _pulse.value;
              final intensity = urgency > 0 ? 0.6 + 0.4 * _pulse.value : pulse;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Halo diffus derrière le tube
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

                  // Tube de verre sombre + contour néon
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

                  // Niveau d'énergie (dégradé + lueur)
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

                  // Étoiles / graduations lumineuses sur le tube
                  Positioned(
                    left: (cw - bw) / 2,
                    top: ch / 2,
                    width: bw,
                    height: bh,
                    child: IgnorePointer(
                      child: CustomPaint(painter: _TicksPainter(color: glow)),
                    ),
                  ),

                  // Aura derrière le personnage
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

                  // Personnage posé sur le niveau
                  Positioned(
                    left: 0,
                    top: bh - fillHeight, // centre du perso = haut du niveau
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

/// Petites graduations lumineuses sur le côté du tube.
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
