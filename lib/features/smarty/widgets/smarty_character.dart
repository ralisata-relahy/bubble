import 'package:bubble/features/smarty/models/smarty_pose.dart';
import 'package:bubble/features/smarty/widgets/cage_painter.dart';
import 'package:bubble/features/smarty/widgets/smarty_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A laser target with an optional text bubble
@immutable
class SmartyTarget {
  const SmartyTarget(this.position, [this.label]);
  final Offset position;
  final String? label;
}

/// Animated Edutainer character widget that drives pose, emotion,
/// laser targets, and an optional laser cage via a [Ticker].
class SmartyAvatar extends StatefulWidget {
  const SmartyAvatar({
    super.key,
    this.size,
    this.bodyColor,
    this.saucerColor,
    this.laserColor = const Color(0xFF4DF0FF),
    this.showShadow = false,
    this.targets = const [],
    this.animate = true,
    this.speed = 1.0,
    this.emotion = SmartyEmotion.normal,
    this.pose,
    this.poseBuilder,
    this.isCaged = false,
    this.barCount = 5,
  });

  final double? size;

  /// Optional tint applied to the character body gradient.
  final Color? bodyColor;

  /// Optional tint applied to the saucer and orb.
  final Color? saucerColor;

  final Color laserColor;
  final bool showShadow;

  /// Laser targets to aim at (ignored while caged).
  final List<SmartyTarget> targets;

  /// Whether the animation ticker is running.
  final bool animate;

  /// Animation playback speed multiplier (1.0 = normal).
  final double speed;

  /// Emotion preset
  final SmartyEmotion emotion;

  final SmartyPose? pose;

  final SmartyPose Function(double t)? poseBuilder;

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
  State<SmartyAvatar> createState() => _SmartyAvatarState();
}

class _SmartyAvatarState extends State<SmartyAvatar>
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

  SmartyEmotion get _emotion =>
      _isCaged ? SmartyEmotion.sad : widget.emotion;

  double get _effectiveSpeed => widget.speed * _emotion.speed;

  void _syncTargets() {
    // A caged character doesn't shoot lasers.
    final targets = _isCaged ? const <SmartyTarget>[] : widget.targets;
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
  void didUpdateWidget(covariant SmartyAvatar old) {
    super.didUpdateWidget(old);

    final cagedChanged = old.effectivelyCaged != widget.effectivelyCaged;

    if (old.targets != widget.targets || cagedChanged) {
      _syncTargets();
    }

    final speedChanged =
        old.speed != widget.speed ||
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

  SmartyPose _poseAt(double t) {
    final base =
        widget.pose ??
        widget.poseBuilder?.call(t) ??
        SmartyPose.idle(t, targets: _positions, labels: _labels);
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
                painter: SmartyPainter(
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
        height: size / SmartyAvatar.aspectRatio,
        child: painted,
      );
    }
    return AspectRatio(
      aspectRatio: SmartyAvatar.aspectRatio,
      child: painted,
    );
  }
}
