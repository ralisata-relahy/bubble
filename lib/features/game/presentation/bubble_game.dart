import 'dart:async';
import 'dart:math';

import 'package:bubble/core/contracts/knowledge_bubble_host.dart';
import 'package:bubble/core/services/audio/sound_effect.dart';
import 'package:bubble/core/services/haptics_service.dart';
import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/bubble/presentation/components/knowledge_bubble.dart';
import 'package:bubble/features/curio/presentation/widgets/character_time_gauge.dart';
import 'package:bubble/features/game/application/contracts/game_command_port.dart';
import 'package:bubble/features/game/application/controllers/game_controller.dart';
import 'package:bubble/features/game/configuration/game_configuration.dart';
import 'package:bubble/features/game/data/game_questions.dart';
import 'package:bubble/features/game/domain/game_question_deck.dart';
import 'package:bubble/features/game/domain/rules/round_color_palette.dart';
import 'package:bubble/features/game/domain/services/bubble_pop_history.dart';
import 'package:bubble/features/game/presentation/components/aim_guide_component.dart';
import 'package:bubble/features/game/presentation/components/confetti_component.dart';
import 'package:bubble/features/game/presentation/components/knowledge_bubble_scatter.dart';
import 'package:bubble/features/game/presentation/components/laser_beam.dart';
import 'package:bubble/features/game/presentation/components/trajectory_calculator.dart';
import 'package:bubble/features/game/presentation/systems/bubble_collision_system.dart';
import 'package:bubble/features/game/services/game_audio_service.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Coordinates the primary Flame game loop, round progression, user input, and game entities.
class BubbleGame extends FlameGame
    with TapCallbacks, DragCallbacks
    implements KnowledgeBubbleHost, GameCommandPort {
  /// Creates the game with its session-scoped generated sound service.
  BubbleGame({required this.soundEffects, required this.gameController}) {
    gameController.attachGame(this);
  }

  static const _fallbackGameWidth = 800.0;
  static const _fallbackGameHeight = 600.0;

  // ---------------------------------------------------------------------------
  // Overlay Constants
  // ---------------------------------------------------------------------------

  /// Identifier for the Flutter overlay displaying Curio and the time gauge.
  static const curioOverlay = 'curio';

  /// Identifier for the acceleration button overlay during knowledge dispersal.
  static const accelerateOverlay = 'accelerate';

  /// Identifier for the game over overlay.
  static const gameOverOverlay = 'gameOver';

  /// Identifier for the victory winning overlay.
  static const winingOverlay = 'wining';

  // ---------------------------------------------------------------------------
  // State and Dependencies
  // ---------------------------------------------------------------------------

  /// Global key enabling the Flame engine to control the countdown timer.
  final gaugeKey = GlobalKey<CharacterTimeGaugeState>();
  final SoundEffects soundEffects;
  final GameController gameController;
  final HapticsService hapticsService = HapticsService();

  /// Pseudo-random number generator for positions and layout.
  final _random = Random();
  final _gameAudio = GameAudioService();
  final _collisionSystem = BubbleCollisionSystem();

  /// Palette rule managing distinct colors per round.
  late final _colorPalette = RoundColorPalette(random: _random);

  /// First-hit history preserves the order in which answer bubbles were popped.
  final BubblePopHistory _popHistory = BubblePopHistory();
  int _nextBubbleId = 0;
  int _collectionIndex = 0;
  int _collectionGeneration = 0;
  late final _questionDeck = GameQuestionDeck(
    questions: GameQuestions.all,
    random: _random,
  );

  /// Active laser beam and aiming guide.
  LaserBeam? _laser;
  late final AimGuideComponent _aimGuide;
  Vector2? _lastAimPosition;

  /// Distinguishes final knowledge presentation from a round victory pause.
  bool _endingGame = false;
  late String _currentAnswer;

  /// Real-time clock for the controls; it is not multiplied by simulation steps.
  double _knowledgeRealTime = 0.0;

  /// Extra Flame updates accelerate component motion after the player skips.
  int _timeSteps = 1;
  bool _accelerateVisible = false;

  /// Active simulation substeps, exposed to keep certain animations at
  /// real-time rate during accelerated knowledge dispersal.
  int get simulationTimeSteps => _timeSteps;

  @override
  bool isFrozen = false;

  @override
  double elapsedFreezeTime = 0.0;

  @override
  double get bubbleRespawnY => _laser?.bubbleRespawnY ?? size.y;

  Vector2 get _effectiveGameSize =>
      size.x > 0 ? size : Vector2(_fallbackGameWidth, _fallbackGameHeight);

  // ---------------------------------------------------------------------------
  // Flame Lifecycle
  // ---------------------------------------------------------------------------

  /// Maintains Flame canvas transparency so the Flutter background remains visible.
  @override
  Color backgroundColor() => Colors.transparent;

  /// Initializes overlays and launches the first game round.
  @override
  Future<void> onLoad() async {
    _aimGuide = AimGuideComponent();
    await add(_aimGuide);
    overlays.add(curioOverlay);
    _questionDeck.selectNext();
    await _startRound();
  }

  @override
  void onRemove() {
    // Flame's removal callback is synchronous; release external players without
    // blocking component-tree teardown.
    unawaited(_gameAudio.dispose());
    unawaited(soundEffects.dispose());
    gameController.detachGame(this);
    super.onRemove();
  }

  /// Adapts mascot and laser layout on viewport resize.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _laser?.fitToViewport(size);
  }

  /// Updates freeze duration, entities, and executes the collision resolution pass.
  @override
  void update(double dt) {
    // Clamp long frames so a pause or resumed tab cannot move bubbles through targets.
    final safeDt = dt.clamp(0.0, 1 / 20).toDouble();

    _updateKnowledgeControls(safeDt);

    // Keep Flame's normal lifecycle on the first pass; extra passes accelerate
    // the component simulation after the player skips the victory scatter.
    for (var i = 0; i < _timeSteps; i++) {
      super.update(safeDt);

      if (isFrozen) {
        elapsedFreezeTime += safeDt;

        // Each frozen state has a different completion condition: timed restart,
        // game-over pause, or the victory scatter finishing/leaving the screen.
        if (gameController.isGameOver) {
          return;
        } else if (gameController.isWon && !_endingGame) {
          final knowledgeBubbles = children
              .whereType<KnowledgeBubbleComponent>()
              .toList();

          // An empty list must not finish the celebration before its timeout.
          final hasActiveKnowledge = knowledgeBubbles.isNotEmpty;
          final allLeft =
              hasActiveKnowledge &&
              knowledgeBubbles.every((bubble) => bubble.hasLeftScreen);

          // Continue when every burst bubble exits, with a timeout for stragglers.
          if (allLeft ||
              elapsedFreezeTime >= GameConfiguration.winCelebrationDuration) {
            // Remove any stragglers left when the timeout wins the race.
            for (final kb in knowledgeBubbles) {
              kb.removeFromParent();
            }
            for (final confetti in children.whereType<ConfettiComponent>()) {
              confetti.removeFromParent();
            }
            nextRound();
            return;
          }
        }
      }
      // End-game bubbles are presentation-only and no longer participate in physics.
      if (!_endingGame) {
        _collisionSystem.update(children, isFrozen: isFrozen);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Knowledge Dispersal Controls
  // ---------------------------------------------------------------------------

  /// Manages acceleration button appearance based on elapsed real-time (not accelerated).
  void _updateKnowledgeControls(double realDt) {
    if (!gameController.isWon || gameController.isGameOver || _endingGame) {
      return;
    }

    _knowledgeRealTime += realDt;

    if (!_accelerateVisible &&
        _knowledgeRealTime >= GameConfiguration.accelerateButtonDelay) {
      _accelerateVisible = true;
      overlays.add(accelerateOverlay);
    }
  }

  /// Hides the button and resets simulation rate to normal.
  void _resetKnowledgeControls() {
    _timeSteps = 1;
    _knowledgeRealTime = 0.0;
    _accelerateVisible = false;
    overlays.remove(accelerateOverlay);
  }

  /// Accelerates knowledge bubble dispersal.
  @override
  void accelerateKnowledge() {
    if (!gameController.isWon || gameController.isGameOver) return;
    _timeSteps = GameConfiguration.accelerationFactor;
    _accelerateVisible = true; // prevents reopening
    overlays.remove(accelerateOverlay); // button dismisses after use
  }

  // ---------------------------------------------------------------------------
  // Round Setup and Entities
  // ---------------------------------------------------------------------------

  /// Initializes round entities: laser mascot and answer bubbles.
  Future<void> _startRound() async {
    final gameSize = _effectiveGameSize;
    final question = _questionDeck.current;
    _currentAnswer = question.answer;
    _colorPalette.startNextRound();

    final labelColor = _colorPalette.nextColor();
    // The previous round's laser is removed with its answer bubbles; create a
    // fresh one so the question label and viewport layout start in sync.
    final laser = LaserBeam(
      soundEffects: soundEffects,
      origin: Vector2(
        gameSize.x / 2,
        gameSize.y * GameConfiguration.bubbleSpawnHeightFraction,
      ),
      targetPosition: Vector2(
        gameSize.x / 2,
        gameSize.y * GameConfiguration.laserTargetHeightFraction,
      ),
      label: question.prompt,
      labelColor: labelColor,
    );
    _laser = laser;
    laser.fitToViewport(gameSize);
    await add(laser);

    for (final choice in question.choices) {
      await _spawn(choice, _colorPalette.nextColor());
    }
  }

  /// Spawns an answer bubble onto the game canvas.
  Future<void> _spawn(String text, Color color) async {
    const bubbleSize = Size(
      GameConfiguration.bubbleSize,
      GameConfiguration.bubbleSize,
    );
    final position = _randomPosition(bubbleSize);
    final bubbleId = _nextBubbleId++;
    return add(
      Bubble(
        position: position,
        textColor: Colors.white,
        random: _random,
        canPop: (value) => value == _currentAnswer,
        onTargetImpact: _startFreezeOnWin,
        onWrongImpact: _onWrongAnswer,
        onPopped: (content, wasTarget) =>
            _recordBubblePop(bubbleId, content, wasTarget),
        soundEffects: soundEffects,
        hapticsService: hapticsService,
        config: BubbleConfig(
          text: text,
          direction: BubbleDirection.bottomToTop,
          speed: GameConfiguration.bubbleSpeed,
          style: BubbleStyle(
            shape: BubbleShape.sphere,
            size: bubbleSize,
            baseColor: color,
          ),
        ),
      ),
    );
  }

  /// Stores the first impact before the bubble begins its removal animation.
  void _recordBubblePop(int bubbleId, String content, bool wasTarget) {
    _popHistory.record(
      id: bubbleId,
      content: content,
      knowledge: wasTarget ? _questionDeck.current.knowledge : const [],
    );
  }

  /// Computes a random spawn position within the allowed play boundary.
  Vector2 _randomPosition(Size bubbleSize) {
    final gameSize = _effectiveGameSize;
    final halfWidth = bubbleSize.width / 2;
    final halfHeight = bubbleSize.height / 2;
    final availableWidth = max(0.0, gameSize.x - bubbleSize.width);
    final availableHeight = max(0.0, bubbleRespawnY - bubbleSize.height);

    return Vector2(
      availableWidth == 0
          ? gameSize.x / 2
          : halfWidth + _random.nextDouble() * availableWidth,
      availableHeight == 0
          ? max(0.0, bubbleRespawnY - halfHeight)
          : halfHeight + _random.nextDouble() * availableHeight,
    );
  }

  /// Applies a time penalty on an incorrect answer.
  void _onWrongAnswer() {
    if (gameController.isWon || gameController.isGameOver) return;
    gaugeKey.currentState?.addTime(GameConfiguration.wrongAnswerTimePenalty);
  }

  /// Initiates round victory animation, freeze state, and celebration confetti.
  void _startFreezeOnWin(Vector2 popPosition) {
    if (!gameController.completeRound()) return;

    // Time bonus on correct answer (+10% of total duration).
    gaugeKey.currentState?.addTime(GameConfiguration.correctAnswerTimeBonus);
    // Pause the timer and ordinary round progression while burst knowledge exits.
    isFrozen = true;
    gameController.isTimerPausedNotifier.value = true;
    gaugeKey.currentState?.pause();
    _resetKnowledgeControls();

    // Solving the prompt cancels the remaining alternatives so no unresolved
    // answer bubble is carried into the next round.
    for (final bubble in children.whereType<Bubble>().toList()) {
      if (!bubble.isTarget) bubble.removeFromParent();
    }

    // Confetti burst from impact origin.
    add(
      ConfettiComponent(
        origin: popPosition.clone(),
        duration: GameConfiguration.confettiDuration,
        particleCount: GameConfiguration.confettiParticleCount,
      ),
    );

    // Keep the solved prompt active until the next round actually starts.
    unawaited(_gameAudio.playAnswer(_questionDeck.current));
  }

  // ---------------------------------------------------------------------------
  // Session Restart and Round Progression
  // ---------------------------------------------------------------------------

  /// Removes bubbles, knowledge components, confetti, and laser from the current round.
  void _clearRoundEntities() {
    // Remove from a snapshot because Flame applies tree mutations after the frame.
    for (final child in children.toList()) {
      if (child is Bubble ||
          child is KnowledgeBubbleComponent ||
          child is KnowledgeBubbleScatter ||
          child is ConfettiComponent) {
        child.removeFromParent();
      }
    }
    _laser?.removeFromParent();
    _laser = null;
  }

  /// Starts a new game session.
  @override
  void restartGame() {
    final previousQuestionIndex = _questionDeck.currentIndex;
    overlays.remove(gameOverOverlay);
    overlays.remove(winingOverlay);
    overlays.add(curioOverlay);
    _collectionGeneration++;
    _clearRoundEntities();
    _popHistory.clear();
    _collectionIndex = 0;
    _endingGame = false;
    _colorPalette.reset();
    gameController.reset();
    isFrozen = false;
    gameController.isCriticalNotifier.value = false;
    gameController.isTimerPausedNotifier.value = false;
    elapsedFreezeTime = 0.0;
    _questionDeck.selectNext(excludingIndex: previousQuestionIndex);
    gaugeKey.currentState?.restart(duration: GameConfiguration.gameDuration);
    _resetKnowledgeControls();
    resumeEngine();
    _startRound();
  }

  /// Cleans up current entities and starts the next round without resetting the timer gauge.
  void nextRound() {
    gameController.startNextRound();
    if (gameController.completedRounds.value >=
        GameConfiguration.roundsPerGame) {
      endGame();
      return;
    }

    _questionDeck.selectNext(excludingIndex: _questionDeck.currentIndex);

    // Preserve the timer between rounds, but clear the victory freeze and effects.
    _clearRoundEntities();
    isFrozen = false;
    gameController.isCriticalNotifier.value =
        (gaugeKey.currentState?.remaining ?? 1.0) <=
        GameConfiguration.criticalTimeThreshold;
    gameController.isTimerPausedNotifier.value = false;
    gaugeKey.currentState?.resume();
    elapsedFreezeTime = 0.0;
    _resetKnowledgeControls();
    resumeEngine();
    _startRound();
  }

  /// Hides gameplay entities, then presents every recorded bubble in order.
  void endGame() {
    _collectionGeneration++;
    _collectionIndex = 0;
    final generation = _collectionGeneration;
    _endingGame = true;
    gameController.finishGame();
    isFrozen = true;
    elapsedFreezeTime = 0.0;
    overlays.remove(curioOverlay);
    gameController.isTimerPausedNotifier.value = true;
    gaugeKey.currentState?.pause();
    _resetKnowledgeControls();

    // Keep the character visible but remove gameplay bubbles and its prompt.
    for (final bubble in children.whereType<Bubble>().toList()) {
      bubble.removeFromParent();
    }
    for (final bubble
        in children.whereType<KnowledgeBubbleComponent>().toList()) {
      bubble.removeFromParent();
    }
    for (final scatter
        in children.whereType<KnowledgeBubbleScatter>().toList()) {
      scatter.removeFromParent();
    }
    for (final confetti in children.whereType<ConfettiComponent>().toList()) {
      confetti.removeFromParent();
    }
    _laser?.hideLabel();
    _aimGuide.hide();
    _showNextPoppedBubble(generation);
  }

  /// Presents one popped bubble at a time and waits for its knowledge to be absorbed.
  void _showNextPoppedBubble(int generation) {
    if (generation != _collectionGeneration || !_endingGame) return;
    if (_collectionIndex >= _popHistory.length) {
      overlays.add(winingOverlay);
      return;
    }

    final record = _popHistory[_collectionIndex++];
    add(
      KnowledgeBubbleScatter(
        sourceBubbleText: record.content,
        entries: record.knowledge,
        random: _random,
        suctionPoint: _laser?.laserOriginPoint.clone(),
        onFinished: () => _showNextPoppedBubble(generation),
      ),
    );
  }

  /// Handles game over when the timer expires.
  void onTimeUp() {
    if (gameController.isWon || gameController.isGameOver) return;

    gameController.markGameOver();
    isFrozen = true;
    gameController.isTimerPausedNotifier.value = true;
    elapsedFreezeTime = 0.0;
    gaugeKey.currentState?.pause();
    _resetKnowledgeControls();
    overlays.add(gameOverOverlay);
  }

  // ---------------------------------------------------------------------------
  // Aiming and Shooting
  // ---------------------------------------------------------------------------

  void _updateAimTrajectory(Vector2 targetPos) {
    _lastAimPosition = targetPos.clone();
    final laser = _laser;
    if (gameController.isWon || isFrozen || laser == null) {
      _aimGuide.hide();
      return;
    }

    final origin = laser.laserOriginPoint;
    final toTarget = targetPos - origin;
    if (toTarget.length < 1e-4) return;

    final trajectory = TrajectoryCalculator.calculate(
      origin: origin,
      initialDirection: toTarget.normalized(),
      gameWidth: size.x,
      gameHeight: size.y,
      potentialTargets: children.whereType<PositionComponent>(),
      maxBounces: 2,
    );
    _aimGuide.updateTrajectory(trajectory);
  }

  void _cancelAim() {
    _aimGuide.hide();
    _lastAimPosition = null;
  }

  void _fireLaserAtLastAim() {
    final trajectory = _aimGuide.currentTrajectory;
    _aimGuide.hide();
    final targetPos = _lastAimPosition;
    final laser = _laser;
    _lastAimPosition = null;

    if (gameController.isWon || isFrozen || laser == null) return;

    // If a trajectory was actively shown by the aiming guide, follow it exactly.
    if (trajectory != null && trajectory.points.length >= 2) {
      laser.fireTrajectory(trajectory);
    } else if (targetPos != null) {
      laser.fireAt(targetPos);
    }
  }

  // ---------------------------------------------------------------------------
  // Touch and Drag Input Handling
  // ---------------------------------------------------------------------------

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _updateAimTrajectory(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _updateAimTrajectory(event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _fireLaserAtLastAim();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _cancelAim();
  }

  /// Activates aiming trajectory on initial tap without firing immediately.
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    _updateAimTrajectory(event.localPosition);
  }

  /// Fires the laser beam upon tap release.
  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    _lastAimPosition = event.localPosition.clone();
    _fireLaserAtLastAim();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    _cancelAim();
  }
}
