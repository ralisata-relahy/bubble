import 'package:bubble/features/ai_buddy/models/character_pose.dart';
import 'package:bubble/features/ai_buddy/widgets/cage_painter.dart';
import 'package:bubble/features/ai_buddy/widgets/edutainer_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A laser target with an optional text bubble
@immutable
class EdutainerTarget {
  const EdutainerTarget(this.position, [this.label]);
  final Offset position;
  final String? label;
}

class AiBudddyEdutainment extends StatefulWidget {
  const AiBudddyEdutainment({
    super.key,
    this.size,
    this.bodyColor,
    this.saucerColor,
    this.laserColor = const Color(0xFF4DF0FF),
    this.showShadow = false,
    this.targets = const [],
    this.animate = true,
    this.speed = 1.0,
    this.emotion = EdutainerEmotion.normal,
    this.pose,
    this.poseBuilder,
    this.isCaged = false,
    this.barCount = 5,
  });

  final double? size;

  // Body color
  final Color? bodyColor;

  // Saucer color
  final Color? saucerColor;

  final Color laserColor;
  final bool showShadow;

  // Laser targets (ignored while caged)
  final List<EdutainerTarget> targets;

  // Pause or resume the animation.
  final bool animate;

  // Animation speed multiplier
  final double speed;

  /// Emotion preset
  final EdutainerEmotion emotion;

  final EdutainerPose? pose;

  final EdutainerPose Function(double t)? poseBuilder;

  /// When true, the character is locked in a laser cage and looks sad.
  /// Has no effect if [barCount] is 0.
  final bool isCaged;

  /// Number of vertical laser bars in the cage.
  /// If 0, the cage disappears and the character is not caged.
  final int barCount;

  /// True only when the cage is requested AND it has at least one bar.
  bool get effectivelyCaged => isCaged && barCount > 0;

  static const double aspectRatio = 400 / 600;

  @override
  State<AiBudddyEdutainment> createState() => _AiBudddyEdutainmentState();
}

class _AiBudddyEdutainmentState extends State<AiBudddyEdutainment>
    with SingleTickerProviderStateMixin {
  // Cage layout, shared by the cage painters and the character.
  static const double _cageCenterY = 0.50; // 0.5 = middle of the canvas
  static const double _characterScale = 0.62; // character size inside the cage
  static const double _characterDy = 0.0; // nudge: + = down, - = up

  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  double _base = 0;

  late List<Offset> _positions;
  late List<String> _labels;

  bool get _isCaged => widget.effectivelyCaged;

  bool get _needsTicker => widget.animate && widget.pose == null;

  EdutainerEmotion get _emotion =>
      _isCaged ? EdutainerEmotion.sad : widget.emotion;

  double get _effectiveSpeed => widget.speed * _emotion.speed;

  void _syncTargets() {
    // A caged character doesn't shoot lasers.
    final targets = _isCaged ? const <EdutainerTarget>[] : widget.targets;
    _positions = [for (final t in targets) t.position];
    _labels = [for (final t in targets) t.label ?? ''];
  }

  @override
  void initState() {
    super.initState();
    _syncTargets();
    _ticker = createTicker((elapsed) {
      _time.value = _base + elapsed.inMicroseconds / 1e6 * _effectiveSpeed;
    });
    if (_needsTicker) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant AiBudddyEdutainment old) {
    super.didUpdateWidget(old);

    final cagedChanged = old.effectivelyCaged != widget.effectivelyCaged;

    if (old.targets != widget.targets || cagedChanged) {
      _syncTargets();
    }

    final speedChanged = old.speed != widget.speed ||
        old.emotion != widget.emotion ||
        cagedChanged;

    // Stop and bank the elapsed time whenever the run must change.
    if (_ticker.isActive && (!_needsTicker || speedChanged)) {
      _base = _time.value;
      _ticker.stop();
    }
    if (_needsTicker && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  EdutainerPose _poseAt(double t) {
    final base = widget.pose ??
        widget.poseBuilder?.call(t) ??
        EdutainerPose.idle(t, targets: _positions, labels: _labels);
    return base.withEmotion(_emotion);
  }

  @override
  Widget build(BuildContext context) {
    final painted = RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ValueListenableBuilder<double>(
            valueListenable: _time,
            builder: (context, t, _) {
              Widget character = CustomPaint(
                painter: EdutainerPainter(
                  _poseAt(t),
                  showShadow: widget.showShadow,
                  laserColor: widget.laserColor,
                  bodyColor: widget.bodyColor,
                  saucerColor: widget.saucerColor,
                ),
              );

              // No cage (isCaged false, or barCount is 0): plain character.
              if (!_isCaged) return character;

              // Scale the character around the canvas center
              final dy =
                  (_cageCenterY - 0.5 + _characterDy) * constraints.maxHeight;
              character = Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: _characterScale,
                  alignment: Alignment.center,
                  child: character,
                ),
              );

              return Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // Back half of the cage
                  CustomPaint(
                    painter: LaserCagePainter(
                      barCount: widget.barCount,
                      color: widget.laserColor,
                      time: t,
                      front: false,
                      centerYFactor: _cageCenterY,
                    ),
                  ),
                  character,
                  // Front bars
                  CustomPaint(
                    painter: LaserCagePainter(
                      barCount: widget.barCount,
                      color: widget.laserColor,
                      time: t,
                      front: true,
                      centerYFactor: _cageCenterY,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    final size = widget.size;
    if (size != null) {
      return SizedBox(
        width: size,
        height: size / AiBudddyEdutainment.aspectRatio,
        child: painted,
      );
    }
    return AspectRatio(
      aspectRatio: AiBudddyEdutainment.aspectRatio,
      child: painted,
    );
  }
}