import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/bubble/presentation/components/knowledge_bubble.dart';

/// Replays an answer bubble, then presents and absorbs its associated knowledge.
class KnowledgeBubbleScatter extends Component
    with HasGameReference<FlameGame> {
  /// Creates a presentation sequence for [entries] and completes when it ends.
  KnowledgeBubbleScatter({
    required List<String> entries,
    required this.random,
    this.sourceBubbleText,
    this.floatSeconds = 3.0,
    this.suctionPoint,
    this.suctionDuration = 0.7,
    this.onFinished,
  }) : entries = List.unmodifiable(entries);

  final List<String> entries;
  final Random random;

  /// Answer bubble replayed before its knowledge is presented.
  final String? sourceBubbleText;
  final double floatSeconds;
  final Vector2? suctionPoint;
  final double suctionDuration;
  final VoidCallback? onFinished;

  static const _bubbleSize = Size(88, 88);
  static const _staggerDelay = 0.08;
  static const _suctionStagger = 0.05;
  static const _popDuration = 0.55;
  static const _sourceBubbleSize = Size(90, 90);
  static const _sourceEntranceDuration = 0.4;
  static const _sourceDisplayDuration = 0.8;
  static const _sourceExitDuration = 0.25;
  bool _isFinished = false;

  @override
  void onLoad() {
    super.onLoad();
    if (sourceBubbleText != null) {
      _showSourceBubble();
      return;
    }

    _showKnowledge();
  }

  void _showSourceBubble() {
    final gameSize = game.size.x > 0 ? game.size : Vector2(800, 600);
    final sourceBubble = Bubble(
      position: gameSize / 2,
      random: random,
      canPop: (_) => false,
      config: BubbleConfig(
        text: sourceBubbleText!,
        direction: BubbleDirection.bottomToTop,
        speed: 0,
        waveAmplitude: 0,
        style: const BubbleStyle(
          shape: BubbleShape.sphere,
          size: _sourceBubbleSize,
          baseColor: Colors.blue,
        ),
      ),
    )..scale = Vector2.zero();
    add(sourceBubble);

    sourceBubble.add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(
          duration: _sourceEntranceDuration,
          curve: Curves.elasticOut,
        ),
        onComplete: () => add(
          TimerComponent(
            period: _sourceDisplayDuration,
            removeOnFinish: true,
            onTick: () => _dismissSourceBubble(sourceBubble),
          ),
        ),
      ),
    );
  }

  void _dismissSourceBubble(Bubble sourceBubble) {
    if (!sourceBubble.isMounted || _isFinished) return;
    sourceBubble.add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: _sourceExitDuration, curve: Curves.easeIn),
        onComplete: () {
          sourceBubble.removeFromParent();
          _showKnowledge();
        },
      ),
    );
  }

  void _showKnowledge() {
    if (entries.isEmpty) {
      _finish();
      return;
    }
    _showBubbles();
  }

  void _finish() {
    if (_isFinished) return;
    _isFinished = true;
    onFinished?.call();
    removeFromParent();
  }

  void _showBubbles() {
    final gameSize = game.size.x > 0 ? game.size : Vector2(800, 600);
    final layout = KnowledgeBubbleScatterLayout.calculate(
      gameSize: gameSize,
      bubbleCount: entries.length,
    );
    final sinkPoint = suctionPoint ?? gameSize / 2;
    final scaledBubbleSize = Size(
      _bubbleSize.width * layout.scale,
      _bubbleSize.height * layout.scale,
    );
    // Start absorption after the last bubble has appeared and completed its float.
    final suctionStart =
        (entries.length - 1) * _staggerDelay + _popDuration + floatSeconds;
    var remaining = entries.length;

    for (var index = 0; index < entries.length; index++) {
      // Staggered entrance and suction keep the grid legible without delaying
      // the whole screen for each bubble in sequence.
      final config = BubbleConfig(
        text: entries[index],
        direction: BubbleDirection.bottomToTop,
        speed: 0,
        waveAmplitude: 0,
        style: BubbleStyle(
          shape: BubbleShape.sphere,
          size: scaledBubbleSize,
          baseColor: Colors.purple,
        ),
      );
      final bubble = KnowledgeBubbleComponent(
        position: layout.centers[index].clone(),
        config: config,
        isBurstBubble: false,
        random: random,
      )..scale = Vector2.zero();

      final startDelay = index * _staggerDelay;
      bubble.add(
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(
            duration: _popDuration,
            startDelay: startDelay,
            curve: Curves.elasticOut,
          ),
        ),
      );

      final floatEffect = MoveEffect.by(
        Vector2(0, -6 - random.nextDouble() * 4),
        EffectController(
          duration: 1.1 + random.nextDouble() * 0.8,
          startDelay: startDelay + _popDuration,
          alternate: true,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      );
      bubble.add(floatEffect);
      add(bubble);

      add(
        TimerComponent(
          period: suctionStart + index * _suctionStagger,
          removeOnFinish: true,
          onTick: () => _suckBubble(
            bubble,
            floatEffect,
            sinkPoint,
            onBubbleFinished: () {
              remaining--;
              if (remaining == 0) {
                // Restart only after every independently animated bubble is removed.
                _finish();
              }
            },
          ),
        ),
      );
    }
  }

  void _suckBubble(
    KnowledgeBubbleComponent bubble,
    MoveEffect floatEffect,
    Vector2 sinkPoint, {
    required VoidCallback onBubbleFinished,
  }) {
    if (!bubble.isMounted) return;
    floatEffect.removeFromParent();

    bubble.add(
      MoveEffect.to(
        sinkPoint.clone(),
        EffectController(duration: suctionDuration, curve: Curves.easeInCubic),
      ),
    );
    bubble.add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: suctionDuration, curve: Curves.easeIn),
        onComplete: () {
          bubble.removeFromParent();
          onBubbleFinished();
        },
      ),
    );
  }
}

/// Calculates non-overlapping, centered positions for a responsive bubble grid.
class KnowledgeBubbleScatterLayout {
  const KnowledgeBubbleScatterLayout._({
    required this.centers,
    required this.scale,
    required this.diameter,
  });

  final List<Vector2> centers;
  final double scale;
  final double diameter;

  static const _columnsPerRow = 4;
  static const _baseDiameter = 88.0 * 0.8;
  static const _bubbleGap = 12.0;
  static const _maxGridSpacing = 100.0;
  static const _screenMargin = 12.0;

  /// Creates grid centers that fit within [gameSize] without bubble overlap.
  static KnowledgeBubbleScatterLayout calculate({
    required Vector2 gameSize,
    required int bubbleCount,
  }) {
    if (bubbleCount < 0) {
      throw ArgumentError.value(
        bubbleCount,
        'bubbleCount',
        'Must not be negative',
      );
    }
    if (bubbleCount == 0) {
      return const KnowledgeBubbleScatterLayout._(
        centers: [],
        scale: 1,
        diameter: 0,
      );
    }

    final availableWidth = max(_baseDiameter, gameSize.x - _screenMargin * 2);
    final availableHeight = max(_baseDiameter, gameSize.y - _screenMargin * 2);
    final maxColumns = max(
      1,
      ((availableWidth + _bubbleGap) / (_baseDiameter + _bubbleGap)).floor(),
    );
    final columns = min(_columnsPerRow, min(bubbleCount, maxColumns));
    final rows = (bubbleCount / columns).ceil();
    final scale = min(
      1.0,
      min(
        availableWidth / (columns * _baseDiameter + (columns - 1) * _bubbleGap),
        availableHeight / (rows * _baseDiameter + (rows - 1) * _bubbleGap),
      ),
    );
    // Shrink the whole grid uniformly when its rows would exceed the viewport.
    final diameter = _baseDiameter * scale;
    final columnSpacing = columns > 1
        ? min(_maxGridSpacing, (availableWidth - diameter) / (columns - 1))
        : 0.0;
    final rowSpacing = rows > 1
        ? min(_maxGridSpacing, (availableHeight - diameter) / (rows - 1))
        : 0.0;
    final center = gameSize / 2;
    final centers = <Vector2>[];

    for (var row = 0; row < rows; row++) {
      final itemsInRow = min(columns, bubbleCount - row * columns);
      for (var column = 0; column < itemsInRow; column++) {
        centers.add(
          Vector2(
            center.x + (column - (itemsInRow - 1) / 2) * columnSpacing,
            center.y + (row - (rows - 1) / 2) * rowSpacing,
          ),
        );
      }
    }

    return KnowledgeBubbleScatterLayout._(
      centers: List.unmodifiable(centers),
      scale: scale,
      diameter: diameter,
    );
  }
}
