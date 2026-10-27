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
import 'package:bubble/features/game/configuration/game_configuration.dart';
import 'package:bubble/features/game/contracts/game_command_port.dart';
import 'package:bubble/features/game/controllers/game_controller.dart';
import 'package:bubble/features/game/data/game_questions.dart';
import 'package:bubble/features/game/domain/game_question_deck.dart';
import 'package:bubble/features/game/domain/rules/round_color_palette.dart';
import 'package:bubble/features/game/domain/services/bubble_pop_history.dart';
import 'package:bubble/features/game/services/game_audio_service.dart';
import 'package:bubble/features/game/views/presentation/components/aim_guide_component.dart';
import 'package:bubble/features/game/views/presentation/components/confetti_component.dart';
import 'package:bubble/features/game/views/presentation/components/knowledge_bubble_scatter.dart';
import 'package:bubble/features/game/views/presentation/components/laser_beam.dart';
import 'package:bubble/features/game/views/presentation/components/trajectory_calculator.dart';
import 'package:bubble/features/game/views/presentation/systems/bubble_collision_system.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Coordinates the primary Flame game loop, round progression, user input,
/// and game entities.
class BubbleGame extends FlameGame
    with TapCallbacks, DragCallbacks
    implements KnowledgeBubbleHost, GameCommandPort {
  /// Creates the game with its session-scoped generated sound service.
  BubbleGame({required this.soundEffects, required this.gameController}) {
    gameController.attachGame(this);
  }

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const _fallbackGameWidth = 800.0;
  static const _fallbackGameHeight = 600.0;

  /// Longest frame time simulated in one step (1/20 s).
  static const _maxFrameTime = 1 / 20;

  /// Overlay displaying Curio and the time gauge.
  static const curioOverlay = 'curio';

  /// Overlay with the acceleration button shown during knowledge dispersal.
  static const accelerateOverlay = 'accelerate';

  /// Overlay shown when time runs out.
  static const gameOverOverlay = 'gameOver';

  /// Overlay shown on final victory.
  static const winingOverlay = 'wining';

  /// Overlay where the player pronounces words to open the cage.
  static const speakingWordOverlay = 'speakingwordoverlay';

  // ---------------------------------------------------------------------------
  // State and Dependencies
  // ---------------------------------------------------------------------------

  /// Key enabling the Flame engine to control the countdown timer.
  final gaugeKey = GlobalKey<CharacterTimeGaugeState>();
  final SoundEffects soundEffects;
  final GameController gameController;
  final HapticsService hapticsService = HapticsService();

  final _random = Random();
  final _gameAudio = GameAudioService();
  final _collisionSystem = BubbleCollisionSystem();

  /// Palette rule managing distinct colors per round.
  late final _colorPalette = RoundColorPalette(random: _random);

  /// Preserves the order in which answer bubbles were first popped.
  final _popHistory = BubblePopHistory();

  late final _questionDeck = GameQuestionDeck(
    questions: GameQuestions.all,
    random: _random,
  );

  int _nextBubbleId = 0;
  int _collectionIndex = 0;
  int _collectionGeneration = 0;

  /// Active laser beam and aiming guide.
  LaserBeam? _laser;
  late final AimGuideComponent _aimGuide;
  Vector2? _lastAimPosition;

  /// Distinguishes the final knowledge presentation from a round victory pause.
  bool _endingGame = false;
  late String _currentAnswer;

  /// Real-time clock for the controls; not multiplied by simulation steps.
  double _knowledgeRealTime = 0.0;

  /// Extra Flame updates accelerate motion after the player skips.
  int _timeSteps = 1;
  bool _accelerateVisible = false;

  /// Active simulation substeps, exposed so some animations can stay at
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

  /// Keeps the canvas transparent so the Flutter background remains visible.
  @override
  Color backgroundColor() => Colors.transparent;

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
    // Flame's removal callback is synchronous; release players without blocking.
    unawaited(_gameAudio.dispose());
    unawaited(soundEffects.dispose());
    gameController.detachGame(this);
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _laser?.fitToViewport(size);
  }

  @override
  void update(double dt) {
    // Clamp long frames so a pause cannot move bubbles through targets.
    final safeDt = dt.clamp(0.0, _maxFrameTime).toDouble();

    _updateKnowledgeControls(safeDt);

    // Extra passes accelerate the simulation after the player skips the scatter.
    for (var i = 0; i < _timeSteps; i++) {
      super.update(safeDt);

      if (isFrozen) {
        elapsedFreezeTime += safeDt;
        if (_updateFrozenState()) return;
      }

      // End-game bubbles are presentation-only and skip physics.
      if (!_endingGame) {
        _collisionSystem.update(children, isFrozen: isFrozen);
      }
    }
  }

  /// Checks the completion condition of the current frozen state.
  ///
  /// Returns true when the update loop must stop for this frame.
  bool _updateFrozenState() {
    if (gameController.isGameOver) return true;
    if (!gameController.isWon || _endingGame) return false;

    final knowledgeBubbles =
        children.whereType<KnowledgeBubbleComponent>().toList();

    // An empty list must not finish the celebration before its timeout.
    final allLeft = knowledgeBubbles.isNotEmpty &&
        knowledgeBubbles.every((bubble) => bubble.hasLeftScreen);
    final timedOut =
        elapsedFreezeTime >= GameConfiguration.winCelebrationDuration;

    if (!allLeft && !timedOut) return false;

    // Remove stragglers left when the timeout wins the race.
    _removeAll<KnowledgeBubbleComponent>();
    _removeAll<ConfettiComponent>();
    nextRound();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Knowledge Dispersal Controls
  // ---------------------------------------------------------------------------

  /// Shows the acceleration button after a real-time delay.
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

  /// Hides the button and resets the simulation rate to normal.
  void _resetKnowledgeControls() {
    _timeSteps = 1;
    _knowledgeRealTime = 0.0;
    _accelerateVisible = false;
    overlays.remove(accelerateOverlay);
  }

  @override
  void accelerateKnowledge() {
    if (!gameController.isWon || gameController.isGameOver) return;
    _timeSteps = GameConfiguration.accelerationFactor;
    _accelerateVisible = true; // prevents the button from reopening
    overlays.remove(accelerateOverlay);
  }

  // ---------------------------------------------------------------------------
  // Round Setup and Entities
  // ---------------------------------------------------------------------------

  /// Updates the question label displayed by the laser.
  void updateLaserLabel(String text, Color color) =>
      _laser?.updateLabel(text, color);

  /// Creates the round's laser mascot and answer bubbles.
  Future<void> _startRound() async {
    final gameSize = _effectiveGameSize;
    final question = _questionDeck.current;
    _currentAnswer = question.answer;
    _colorPalette.startNextRound();

    // The previous laser is removed with its bubbles; create a fresh one so the
    // label and viewport layout start in sync.
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
      labelColor: _colorPalette.nextColor(),
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
    final bubbleId = _nextBubbleId++;

    return add(
      Bubble(
        position: _randomPosition(bubbleSize),
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

  /// Starts the round victory: time bonus, freeze, confetti and answer audio.
  void _startFreezeOnWin(Vector2 popPosition) {
    if (!gameController.completeRound()) return;

    gaugeKey.currentState?.addTime(GameConfiguration.correctAnswerTimeBonus);
    _freezeAndPauseTimer();

    // Solving the prompt cancels the remaining alternatives.
    for (final bubble in children.whereType<Bubble>().toList()) {
      if (!bubble.isTarget) bubble.removeFromParent();
    }

    add(
      ConfettiComponent(
        origin: popPosition.clone(),
        duration: GameConfiguration.confettiDuration,
        particleCount: GameConfiguration.confettiParticleCount,
      ),
    );

    unawaited(_gameAudio.playAnswer(_questionDeck.current));
  }

  // ---------------------------------------------------------------------------
  // Entity and State Helpers
  // ---------------------------------------------------------------------------

  /// Removes every child of type [T] (from a snapshot, since Flame applies
  /// tree mutations after the frame).
  void _removeAll<T extends Component>() {
    for (final component in children.whereType<T>().toList()) {
      component.removeFromParent();
    }
  }

  /// Removes bubbles, knowledge components, scatters and confetti.
  /// The laser is kept.
  void _removeGameplayEntities() {
    _removeAll<Bubble>();
    _removeAll<KnowledgeBubbleComponent>();
    _removeAll<KnowledgeBubbleScatter>();
    _removeAll<ConfettiComponent>();
  }

  /// Removes all round entities, including the laser.
  void _clearRoundEntities() {
    _removeGameplayEntities();
    _laser?.removeFromParent();
    _laser = null;
  }

  /// Freezes the world, pauses the timer and resets the knowledge controls.
  void _freezeAndPauseTimer() {
    isFrozen = true;
    elapsedFreezeTime = 0.0;
    gameController.isTimerPausedNotifier.value = true;
    gaugeKey.currentState?.pause();
    _resetKnowledgeControls();
  }

  /// Unfreezes the world and resumes the timer.
  void _unfreezeAndResumeTimer() {
    isFrozen = false;
    elapsedFreezeTime = 0.0;
    gameController.isTimerPausedNotifier.value = false;
    gaugeKey.currentState?.resume();
    _resetKnowledgeControls();
    resumeEngine();
  }

  // ---------------------------------------------------------------------------
  // Session Restart and Round Progression
  // ---------------------------------------------------------------------------

  /// Starts a new game session.
  @override
  void restartGame() {
    final previousQuestionIndex = _questionDeck.currentIndex;

    overlays
      ..remove(gameOverOverlay)
      ..remove(winingOverlay)
      ..remove(speakingWordOverlay)
      ..add(curioOverlay);

    _collectionGeneration++;
    _collectionIndex = 0;
    _endingGame = false;
    _clearRoundEntities();
    _popHistory.clear();
    _colorPalette.reset();
    gameController.reset(); // also resets cage and bar count

    isFrozen = false;
    elapsedFreezeTime = 0.0;
    gameController.isCriticalNotifier.value = false;
    gameController.isTimerPausedNotifier.value = false;
    _questionDeck.selectNext(excludingIndex: previousQuestionIndex);
    gaugeKey.currentState?.restart(duration: GameConfiguration.gameDuration);
    _resetKnowledgeControls();
    resumeEngine();
    unawaited(_startRound());
  }

  /// Starts the next round without resetting the timer gauge.
  void nextRound() {
    gameController.startNextRound();
    if (gameController.completedRounds.value >=
        GameConfiguration.roundsPerGame) {
      endGame();
      return;
    }

    _questionDeck.selectNext(excludingIndex: _questionDeck.currentIndex);
    _clearRoundEntities();

    gameController.isCriticalNotifier.value =
        (gaugeKey.currentState?.remaining ?? 1.0) <=
        GameConfiguration.criticalTimeThreshold;
    _unfreezeAndResumeTimer();
    unawaited(_startRound());
  }

  /// Hides gameplay entities, then presents every recorded bubble in order.
  void endGame() {
    _collectionGeneration++;
    _collectionIndex = 0;
    _endingGame = true;
    gameController.finishGame();
    overlays.remove(curioOverlay);
    _freezeAndPauseTimer();

    // Keep the character visible but remove gameplay bubbles.
    _removeGameplayEntities();
    
    _aimGuide.hide();
    _showNextPoppedBubble(_collectionGeneration);
  }

  /// Presents one popped bubble at a time and waits for its knowledge to be
  /// absorbed. Once all are shown, moves on to the speaking-word screen.
  void _showNextPoppedBubble(int generation) {
    if (generation != _collectionGeneration || !_endingGame) return;
    if (_collectionIndex >= _popHistory.length) {
      overlays.add(curioOverlay);
      speakWordScreen();
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
    _freezeAndPauseTimer();
    overlays.add(gameOverOverlay);
  }

  // ---------------------------------------------------------------------------
  // Speaking Word Screen
  // ---------------------------------------------------------------------------

  /// Shows the "speak the word" screen at the end of the game, before victory.
  @override
  void speakWordScreen() {
    // Guards against a double call (e.g. a callback fired twice).
    if (overlays.isActive(speakingWordOverlay)) return;

    _aimGuide.hide();
    _lastAimPosition = null;
    _removeGameplayEntities(); // the laser stays visible on this screen

    overlays
      ..remove(accelerateOverlay)
      ..remove(gameOverOverlay)
      ..remove(winingOverlay);

    _freezeAndPauseTimer();

    gameController.barreCount.value = GameController.initialBarCount;
    gameController.isCaged.value = true;

    overlays.add(speakingWordOverlay);
  }

  /// Called once the player has pronounced every word.
  ///
  /// The timer stays paused: the game is over.
  @override
  void finishSpeakingWord() {
    overlays.remove(speakingWordOverlay);
    overlays.remove(curioOverlay);
    gameController.isCaged.value = false;
    overlays.add(winingOverlay);
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
    final targetPos = _lastAimPosition;
    final laser = _laser;
    _cancelAim();

    if (gameController.isWon || isFrozen || laser == null) return;

    // Follow the trajectory shown by the aiming guide exactly, if any.
    if (trajectory != null && trajectory.points.length >= 2) {
      laser.fireTrajectory(trajectory);
    } else if (targetPos != null) {
      laser.fireAt(targetPos);
    }
  }

  // ---------------------------------------------------------------------------
  // Touch and Drag Input
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

  /// Shows the aiming trajectory on touch down without firing.
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    _updateAimTrajectory(event.localPosition);
  }

  /// Fires the laser beam on tap release.
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