import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../game/bubble_game.dart';

class _Piece {
  double x = 0, y = 0, vx = 0, vy = 0;
  double rot = 0, vr = 0;
  double w = 8, h = 4;
  Color color = Colors.white;
}

/// Écran de victoire: fond sombre + confettis + texte. Tap = rejouer.
class WinOverlay extends PositionComponent
    with TapCallbacks, HasGameReference<BubbleGame> {
  WinOverlay({required this.score}) : super(priority: 100);

  final int score;
  final Random _rng = Random();
  final List<_Piece> _pieces = [];
  static const int _count = 80;

  static const List<Color> _colors = [
    Color(0xFFFF4D6D),
    Color(0xFFFFD60A),
    Color(0xFF4CC9F0),
    Color(0xFF80ED99),
    Color(0xFFB388FF),
    Color(0xFFFF9F1C),
  ];

  final Paint _bg = Paint()..color = const Color(0xB3000000);
  final Paint _paint = Paint();
  late final TextPainter _title;
  late final TextPainter _sub;

  @override
  Future<void> onLoad() async {
    size = game.size.clone();

    for (var i = 0; i < _count; i++) {
      final p = _Piece();
      _reset(p, initial: true);
      _pieces.add(p);
    }

    // _title = TextPainter(
    //   text: const TextSpan(
    //     text: 'Bravo !',
    //     style: TextStyle(
    //       color: Colors.white,
    //       fontSize: 48,
    //       fontWeight: FontWeight.bold,
    //     ),
    //   ),
    //   textDirection: TextDirection.ltr,
    // )..layout();

    // _sub = TextPainter(
    //   text: TextSpan(
    //     text: '$score bulles éclatées\nTouche l\'écran pour rejouer',
    //     style: const TextStyle(color: Colors.white70, fontSize: 20),
    //   ),
    //   textAlign: TextAlign.center,
    //   textDirection: TextDirection.ltr,
    // )..layout(maxWidth: size.x * 0.9);
  }

  void _reset(_Piece p, {bool initial = false}) {
    p.x = _rng.nextDouble() * size.x;
    // au début: réparti au-dessus de l'écran pour étaler la chute
    p.y = initial ? -_rng.nextDouble() * size.y : -20;
    p.vx = (_rng.nextDouble() - 0.5) * 80;
    p.vy = 120 + _rng.nextDouble() * 180;
    p.rot = _rng.nextDouble() * pi * 2;
    p.vr = (_rng.nextDouble() - 0.5) * 10;
    p.w = 6 + _rng.nextDouble() * 6;
    p.h = 3 + _rng.nextDouble() * 4;
    p.color = _colors[_rng.nextInt(_colors.length)];
  }

  @override
  void update(double dt) {
    for (final p in _pieces) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
      if (p.y > size.y + 20) _reset(p);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Offset.zero & Size(size.x, size.y), _bg);

    for (final p in _pieces) {
      _paint.color = p.color;
      canvas
        ..save()
        ..translate(p.x, p.y)
        ..rotate(p.rot)
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          _paint,
        )
        ..restore();
    }

    // _title.paint(
    //   canvas,
    //   Offset((size.x - _title.width) / 2, size.y * 0.35),
    // );
    // _sub.paint(
    //   canvas,
    //   Offset((size.x - _sub.width) / 2, size.y * 0.35 + _title.height + 16),
    // );
  }

  @override
  void onTapDown(TapDownEvent event) => game.restart();
}