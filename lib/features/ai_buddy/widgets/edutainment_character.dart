import '../widgets/edutainer_painter.dart';
import '../models/character_pose.dart';
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
  });

  final double? size;

  /// Body color
  final Color? bodyColor;

  /// Saucer color
  final Color? saucerColor;

  final Color laserColor;
  final bool showShadow;

  /// Laser targets
  final List<EdutainerTarget> targets;

  /// Pause or resume the animation.
  final bool animate;

  /// Animation speed multiplier
  final double speed;

  /// Emotion preset: sets the face and the base speed.
  final EdutainerEmotion emotion;

  final EdutainerPose? pose;

  final EdutainerPose Function(double t)? poseBuilder;

  static const double aspectRatio = 400 / 520;

  @override
  State<AiBudddyEdutainment> createState() => _AiBudddyEdutainmentState();
}

class _AiBudddyEdutainmentState extends State<AiBudddyEdutainment>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  double _base = 0;

  late List<Offset> _positions;
  late List<String> _labels;

  bool get _needsTicker => widget.animate && widget.pose == null;

  double get _effectiveSpeed => widget.speed * widget.emotion.speed;

  void _syncTargets() {
    _positions = [for (final t in widget.targets) t.position];
    _labels = [for (final t in widget.targets) t.label ?? ''];
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
    if (old.targets != widget.targets) _syncTargets();

    final speedChanged =
        old.speed != widget.speed || old.emotion != widget.emotion;

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
    return base.withEmotion(widget.emotion);
  }

  @override
  Widget build(BuildContext context) {
    final painted = RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _time,
        builder: (context, t, _) => CustomPaint(
          painter: EdutainerPainter(
            _poseAt(t),
            showShadow: widget.showShadow,
            laserColor: widget.laserColor,
            bodyColor: widget.bodyColor,
            saucerColor: widget.saucerColor,
          ),
        ),
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