import 'package:flutter/material.dart';
import '../../../game/configuration/game_configuration.dart';
import 'character_time_gauge.dart';
import '../../../game/presentation/bubble_game.dart';

/// Place Curio, sa jauge et la bordure néon d'alerte dans l'overlay Flutter.
class CurioOverlay extends StatefulWidget {
  const CurioOverlay({required this.game, super.key});

  final BubbleGame game;

  @override
  State<CurioOverlay> createState() => _CurioOverlayState();
}

/// Coordinates the critical-state border flash and the timer layout.
class _CurioOverlayState extends State<CurioOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashCtrl;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safeArea = MediaQuery.paddingOf(context);
    final availableHeight = screenHeight - safeArea.top - safeArea.bottom;

    return Stack(
      children: [
        // Bordure néon rouge clignotante UNIQUEMENT sur les bords de l'écran
        ValueListenableBuilder<bool>(
          valueListenable: widget.game.isCriticalNotifier,
          builder: (context, isCritical, _) {
            if (!isCritical) return const SizedBox.shrink();

            return AnimatedBuilder(
              animation: _flashCtrl,
              builder: (context, _) {
                final opacity = 0.35 + 0.65 * _flashCtrl.value;
                return IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ScreenNeonBorderPainter(opacity: opacity),
                  ),
                );
              },
            );
          },
        ),

        // Jauge et personnage Curio
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100, top: 8),
              child: CharacterTimeGauge(
                key: widget.game.gaugeKey,
                isCriticalNotifier: widget.game.isCriticalNotifier,
                isTimerPausedNotifier: widget.game.isTimerPausedNotifier,
                soundEffects: widget.game.soundEffects,
                duration: GameConfiguration.gameDuration,
                barHeight: availableHeight - 230,
                barWidth: 15,
                characterSize: const Size(90, 94),
                onFinished: widget.game.onTimeUp,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dessine une bordure néon brillante UNIQUEMENT sur les contours de l'écran
class _ScreenNeonBorderPainter extends CustomPainter {
  _ScreenNeonBorderPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1) Halo lumineux externe (flou néon)
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30.0
      ..color = Colors.redAccent.withValues(alpha: opacity * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    // 2) Ligne néon principale
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.redAccent.withValues(alpha: opacity);

    // 3) Cœur blanc brillant au centre du trait
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: opacity * 0.85);

    // Dessin uniquement le long du contour rectangulaire (centre 100 % transparent)
    canvas.drawRect(rect, glowPaint);
    canvas.drawRect(rect, strokePaint);
    canvas.drawRect(rect, corePaint);
  }

  @override
  bool shouldRepaint(_ScreenNeonBorderPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
