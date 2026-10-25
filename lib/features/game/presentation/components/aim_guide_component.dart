import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'trajectory_calculator.dart';

/// Composant affichant en temps reel le faisceau laser cyan avec ricochets.
class AimGuideComponent extends Component with HasGameReference {
  AimGuideComponent({
    this.coreColor = const Color(0xFF4FD1C5), // cyan/turquoise du coeur
    this.glowColor = const Color(0xFF2BB5B0), // halo
    this.centerColor = const Color(0xFFB8FFF5), // liseré clair central
  });

  final Color coreColor;
  final Color glowColor;
  final Color centerColor;

  TrajectoryResult? _trajectory;
  TrajectoryResult? get currentTrajectory => _trajectory;
  double _pulseTime = 0.0;
  bool _isVisible = false;

  void updateTrajectory(TrajectoryResult? trajectory) {
    _trajectory = trajectory;
    _isVisible = trajectory != null && trajectory.points.length >= 2;
  }

  void hide() {
    _isVisible = false;
    _trajectory = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isVisible) {
      _pulseTime += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_isVisible || _trajectory == null) return;

    final points = _trajectory!.points;
    if (points.length < 2) return;

    // Tres legere variation (quasi constante) pour garder un faisceau stable
    final pulse = 0.96 + 0.04 * math.sin(_pulseTime * 8);

    final path = Path()..moveTo(points[0].x, points[0].y);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }

    // 1) Grand halo diffus
    final outerGlow = Paint()
      ..color = glowColor.withValues(alpha: 0.12 * pulse)
      ..strokeWidth = 18.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // 2) Halo moyen
    final midGlow = Paint()
      ..color = glowColor.withValues(alpha: 0.25 * pulse)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // 3) Coeur net (cyan plein)
    final core = Paint()
      ..color = coreColor.withValues(alpha: 0.8 * pulse)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // 4) Liseré central plus clair
    final center = Paint()
      ..color = centerColor.withValues(alpha: 0.22 * pulse)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, outerGlow);
    canvas.drawPath(path, midGlow);
    canvas.drawPath(path, core);
    canvas.drawPath(path, center);

    // Points lumineux aux rebonds (petites "etoiles" comme sur la photo)
    final bounceHalo = Paint()
      ..color = centerColor.withValues(alpha: 0.35 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final bounceCore = Paint()
      ..color = Colors.white.withValues(alpha: 0.95 * pulse);
    for (var i = 1; i < points.length - 1; i++) {
      final p = Offset(points[i].x, points[i].y);
      canvas.drawCircle(p, 8.0, bounceHalo);
      canvas.drawCircle(p, 3.5, bounceCore);
    }

    // Point final
    final lastPoint = Offset(points.last.x, points.last.y);
    final dotRadius = 4.5 + 1.0 * math.sin(_pulseTime * 10);
    final targetHit = _trajectory!.hitLaserTarget != null;
    final endColor = targetHit ? Colors.yellowAccent : centerColor;

    canvas.drawCircle(
      lastPoint,
      dotRadius + 5,
      Paint()
        ..color = endColor.withValues(alpha: 0.35 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      lastPoint,
      dotRadius,
      Paint()..color = endColor.withValues(alpha: 0.95 * pulse),
    );

    // Cercle de visee si une cible est verrouillee
    if (targetHit) {
      final ringPaint = Paint()
        ..color = Colors.yellowAccent.withValues(alpha: 0.7 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(lastPoint, dotRadius + 8, ringPaint);
    }
  }
}
