import 'dart:math';

import 'package:bubble/core/contracts/knowledge_bubble_host.dart';
import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_text_helper.dart';
import 'package:bubble/features/bubble/presentation/widgets/knowledge_bubble.dart';
import 'package:bubble/features/curio/presentation/widgets/character_time_gauge.dart';
import 'package:bubble/features/game/data/game_questions.dart';
import 'package:bubble/features/game/presentation/components/laser_beam.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Coordonne les règles d'une partie et les composants Flame qui la composent.
class BubbleGame extends FlameGame
    with TapCallbacks
    implements KnowledgeBubbleHost {
  /// Durée maximale de dispersion des bulles après une bonne réponse.
  static const knowledgeScatterDuration = 4.0;

  /// Nom de l'overlay Flutter contenant le personnage et sa jauge.
  static const curioOverlay = 'curio';
  static const victoryOverlay = 'victory';
  static const gameOverOverlay = 'game_over';

  /// Donne à l'overlay un moyen de contrôler le compte à rebours.
  final gaugeKey = GlobalKey<CharacterTimeGaugeState>();

  /// Source aléatoire partagée pour les positions, couleurs et trajectoires.
  final _random = Random();

  /// Faisceau actif, remplacé au début de chaque manche.
  LaserBeam? _laser;

  /// État de progression de la question et des bulles de connaissance.
  bool _won = false;
  bool _gameOver = false;
  bool _victoryOverlayShown = false;
  late String _currentAnswer;
  late int _currentQuestionId;
  @override
  bool isFrozen = false;
  @override
  double elapsedFreezeTime = 0.0;

  @override
  double get bubbleRespawnY => _laser?.bubbleRespawnY ?? size.y;

  /// Met à jour les durées de gel puis résout les collisions des bulles.
  @override
  void update(double dt) {
    super.update(dt);
    if (isFrozen) {
      elapsedFreezeTime += dt;
      if (_won && elapsedFreezeTime >= knowledgeScatterDuration) {
        _showVictoryOverlay();
      }
    }
    _handleBubbleCollisions();
  }

  /// Vérifie chaque paire de bulles visibles et leur applique une collision.
  void _handleBubbleCollisions() {
    final allBubbles = <PositionComponent>[
      ...children.whereType<Bubble>().where(
        (bubble) => bubble.isCollisionActive,
      ),
      ...children.whereType<KnowledgeBubbleComponent>().where(
        (bubble) => bubble.isCollisionActive,
      ),
    ];

    const padding = 6.0;
    for (var first = 0; first < allBubbles.length; first++) {
      for (var second = first + 1; second < allBubbles.length; second++) {
        final bubble = allBubbles[first];
        final other = allBubbles[second];

        if (bubble is Bubble) {
          bubble.checkAndResolveCollision(other, padding: padding);
        } else if (bubble is KnowledgeBubbleComponent) {
          bubble.checkAndResolveCollision(other, padding: padding);
        }
      }
    }
  }

  /// Affiche l'échec uniquement si la bonne bulle n'a pas déjà été touchée.
  void onTimeUp() {
    if (_won || _gameOver) return;

    _gameOver = true;
    overlays.add(gameOverOverlay);
    pauseEngine();
  }

  /// Affiche une seule fois le résultat quand le délai de dispersion est écoulé.
  void _showVictoryOverlay() {
    if (_victoryOverlayShown || _gameOver) return;

    _victoryOverlayShown = true;
    overlays.add(victoryOverlay);
    pauseEngine();
  }

  /// Laisse le fond Flutter visible derrière le canvas du jeu.
  @override
  Color backgroundColor() => Colors.transparent;

  /// Active l'overlay Flutter et prépare la première question.
  @override
  Future<void> onLoad() async {
    overlays.add(curioOverlay);
    _selectRandomQuestion();
    await _startRound();
  }

  /// Choisit une question aléatoire, en excluant la précédente si possible.
  void _selectRandomQuestion({int? excluding}) {
    final questionCount = GameQuestions.all.length;
    if (questionCount <= 1) {
      _currentQuestionId = 0;
      return;
    }

    final candidates = List<int>.generate(questionCount, (index) => index)
      ..remove(excluding);
    _currentQuestionId = candidates[_random.nextInt(candidates.length)];
  }

  /// Installe le laser et génère les bulles de réponse de la question courante.
  Future<void> _startRound() async {
    final gameSize = size.x > 0 ? size : Vector2(800, 600);
    final question = GameQuestions.all[_currentQuestionId];
    _currentAnswer = question.answer;

    final laser = LaserBeam(
      origin: Vector2(gameSize.x / 2, gameSize.y * 0.76),
      targetPosition: Vector2(gameSize.x / 2, gameSize.y * 0.58),
      label: question.prompt,
      labelColor: Colors.primaries[_random.nextInt(Colors.primaries.length)],
    );
    _laser = laser;
    laser.fitToViewport(gameSize);
    await add(laser);

    for (final choice in question.choices) {
      final color = Colors.primaries[_random.nextInt(Colors.primaries.length)];
      await _spawn(
        choice,
        BubbleDirection.bottomToTop,
        15,
        BubbleShape.sphere,
        const Size(110, 110),
        color,
      );
    }
  }

  /// Crée une bulle et la relie à la réponse attendue pour cette manche.
  Future<void> _spawn(
    String text,
    BubbleDirection direction,
    double speed,
    BubbleShape shape,
    Size bubbleSize,
    Color color,
  ) async {
    final position = _randomPosition(
      bubbleSize.width / 2,
      bubbleSize.height / 2,
    );
    return add(
      Bubble(
        position: position,
        textColor: Colors.white,
        random: _random,
        canPop: (value) => value == _currentAnswer,
        onTargetImpact: _startFreezeOnWin,
        config: BubbleConfig(
          text: text,
          direction: direction,
          speed: speed,
          style: BubbleStyle(shape: shape, size: bubbleSize, baseColor: color),
        ),
      ),
    );
  }

  /// Choisit une position aléatoire en gardant toute la bulle dans le canvas.
  Vector2 _randomPosition(double halfWidth, double halfHeight) {
    final gameSize = size.x > 0 ? size : Vector2(800, 600);
    final availableWidth = max(0.0, gameSize.x - 2 * halfWidth);
    final availableHeight = max(0.0, gameSize.y - 2 * halfHeight);

    return Vector2(
      availableWidth == 0
          ? gameSize.x / 2
          : halfWidth + _random.nextDouble() * availableWidth,
      availableHeight == 0
          ? gameSize.y / 2
          : halfHeight + _random.nextDouble() * availableHeight,
    );
  }

  /// Arrête le compte à rebours et lance l'animation de victoire.
  void _startFreezeOnWin(Vector2 popPosition) {
    if (_won || _gameOver) return;

    _won = true;
    isFrozen = true;
    _victoryOverlayShown = false;
    elapsedFreezeTime = 0.0;
    gaugeKey.currentState?.pause();
    _spawnKnowledgeBubbles(
      popPosition,
      GameQuestions.all[_currentQuestionId].knowledge,
    );
  }

  /// Fait partir radialement les notions liées à la question qui vient d'être résolue.
  void _spawnKnowledgeBubbles(Vector2 origin, List<String> knowledge) {
    for (var index = 0; index < knowledge.length; index++) {
      final angle = (index / knowledge.length) * 2 * pi;
      final bubbleSize = BubbleTextHelper.bubbleSizeForText(
        text: knowledge[index],
        maxWidth: (size.x > 0 ? size.x * 0.4 : 320)
            .clamp(110.0, 320.0)
            .toDouble(),
      );
      add(
        KnowledgeBubbleComponent(
          position: origin.clone(),
          textColor: Colors.white,
          random: _random,
          isBurstBubble: true,
          config: BubbleConfig(
            style: BubbleStyle(
              shape: BubbleShape.ellipsoid,
              size: bubbleSize,
              baseColor: Colors.white,
            ),
            text: knowledge[index],
            speed: 50 + _random.nextDouble() * 30,
            customDirection: Vector2(cos(angle), sin(angle)),
            waveAmplitude: 0,
          ),
        ),
      );
    }
  }

  /// Supprime les entités de la manche précédente et installe la suivante.
  void restart() {
    final previousQuestionId = _currentQuestionId;
    overlays.remove(victoryOverlay);
    overlays.remove(gameOverOverlay);

    for (final child in children.toList()) {
      if (child is Bubble || child is KnowledgeBubbleComponent) {
        child.removeFromParent();
      }
    }

    _laser?.removeFromParent();
    _laser = null;
    _won = false;
    _gameOver = false;
    _victoryOverlayShown = false;
    isFrozen = false;
    elapsedFreezeTime = 0.0;
    _selectRandomQuestion(excluding: previousQuestionId);
    gaugeKey.currentState?.restart();
    resumeEngine();
    _startRound();
  }

  /// Replace le laser lorsque l'écran change de taille.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _laser?.fitToViewport(size);
  }

  /// Tire vers le point touché, sauf pendant une transition de manche.
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final laser = _laser;
    if (_won || isFrozen || laser == null) return;

    laser.fireAt(event.localPosition);
  }
}
