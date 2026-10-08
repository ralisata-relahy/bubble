import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show Color, Colors, Size, TextStyle, FontWeight;

import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/game/presentation/components/laser_beam.dart';

import '../../../components/win/win_overlay.dart';

class BubbleGame extends FlameGame with DragCallbacks {
  static const backgroundAsset = 'Bg_water.webp';
  static const int targetCount = 5;

  final _random = Random();

  late final SpriteComponent _background;
  late LaserBeam _laser;
  late final TextComponent _hud;

  WinOverlay? _overlay;

  int _popped = 0;
  bool _won = false;

  @override
  Color backgroundColor() => const Color(0xFF1E1E1E);

  @override
  Future<void> onLoad() async {
    final gameSize = size.x > 0 ? size : Vector2(800, 600);

    _background = SpriteComponent(
      sprite: await loadSprite(backgroundAsset),
      size: gameSize,
      priority: -1,
    );
    await add(_background);

    _hud = TextComponent(
      text: '0 / $targetCount',
      position: Vector2(16, 40),
      priority: 50,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(_hud);

    await _startRound();
  }

  Future<void> _startRound() async {
    final gameSize = size.x > 0 ? size : Vector2(800, 600);
    _laser = LaserBeam(
      origin: Vector2(gameSize.x / 2, 700),
      targetPosition: Vector2(gameSize.x / 2, 600),
    );
    await add(_laser);

    await _spawn(
      'Vrai',
      BubbleDirection.leftToRight,
      15,
      BubbleShape.sphere,
      const Size(110, 110),
      Colors.lightBlueAccent,
    );

    await _spawn(
      'Faux',
      BubbleDirection.rightToLeft,
      18,
      BubbleShape.sphere,
      const Size(120, 120),
      Colors.purpleAccent,
    );

    await _spawn(
      'Vrai',
      BubbleDirection.bottomToTop,
      20,
      BubbleShape.ellipsoid,
      const Size(180, 110),
      Colors.tealAccent,
    );

    await _spawn(
      'Faux',
      BubbleDirection.topToBottom,
      14,
      BubbleShape.sphere,
      const Size(120, 120),
      Colors.amber,
    );

    await _spawn(
      'Vrai',
      BubbleDirection.bottomToTop,
      22,
      BubbleShape.sphere,
      const Size(130, 130),
      Colors.pinkAccent,
    );
  }

  Future<void> _spawn(
    String text,
    BubbleDirection dir,
    double speed,
    BubbleShape shape,
    Size size,
    Color color,
  ) async {
    return add(
      Bubble(
        position: _randomPosition(size.width / 2, size.height / 2),
        textColor: Colors.white,
        random: _random,

        // Permet à Bubble de notifier le jeu lorsqu'une vraie
        // bulle est correctement touchée.
        onTargetPopped: onTrueBubblePopped,

        config: BubbleConfig(
          text: text,
          direction: dir,
          speed: speed,
          style: BubbleStyle(
            shape: shape,
            size: size,
            baseColor: color,
          ),
        ),
      ),
    );
  }

  Vector2 _randomPosition(double halfW, double halfH) {
    final gameSize = size.x > 0 ? size : Vector2(800, 600);
    final availableWidth = max(0.0, gameSize.x - 2 * halfW);
    final availableHeight = max(0.0, gameSize.y - 2 * halfH);

    return Vector2(
      availableWidth == 0
          ? gameSize.x / 2
          : halfW + _random.nextDouble() * availableWidth,
      availableHeight == 0
          ? gameSize.y / 2
          : halfH + _random.nextDouble() * availableHeight,
    );
  }

  /// Appelée par une vraie bulle au moment où elle éclate.
  void onTrueBubblePopped() {
    if (_won) return;

    _popped++;
    _hud.text = '$_popped / $targetCount';

    if (_popped >= targetCount) {
      _win();
      return;
    }

    // Remplace la bulle vraie supprimée.
    _spawn(
      'Vrai',
      BubbleDirection.values[
        _random.nextInt(BubbleDirection.values.length)
      ],
      14 + _random.nextInt(10).toDouble(),
      BubbleShape.sphere,
      const Size(120, 120),
      Colors.lightBlueAccent,
    );
  }

  void _win() {
    if (_won) return;

    _won = true;
    _laser.removeFromParent();

    _overlay = WinOverlay(score: _popped);
    add(_overlay!);
  }

  void restart() {
    _overlay?.removeFromParent();
    _overlay = null;

    for (final bubble in children.whereType<Bubble>().toList()) {
      bubble.removeFromParent();
    }

    _popped = 0;
    _won = false;
    _hud.text = '0 / $targetCount';

    _startRound();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    if (isLoaded) {
      _background.size = size;
      _laser.position.x = size.x / 2;
      _laser.updateTarget(Vector2(size.x / 2, 600));
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    if (_won) return;

    _laser.updateTarget(event.localEndPosition);
  }
}