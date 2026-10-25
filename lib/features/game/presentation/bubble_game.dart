import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:bubble/core/contracts/knowledge_bubble_host.dart';
import 'package:bubble/core/physics/bubble_collision_resolver.dart';
import 'package:bubble/features/bubble/models/bubble_config.dart';
import 'package:bubble/features/bubble/models/bubble_style.dart';
import 'package:bubble/features/bubble/presentation/components/bubble.dart';
import 'package:bubble/features/bubble/presentation/widgets/knowledge_bubble.dart';
import 'package:bubble/features/curio/presentation/widgets/character_time_gauge.dart';
import 'package:bubble/features/game/data/game_questions.dart';
import 'package:bubble/features/game/presentation/components/aim_guide_component.dart';
import 'package:bubble/features/game/presentation/components/confetti_component.dart';
import 'package:bubble/features/game/presentation/components/laser_beam.dart';
import 'package:bubble/features/game/presentation/components/trajectory_calculator.dart';

/// Coordonne la boucle principale, la progression des manches et les entites Flame.
class BubbleGame extends FlameGame
    with TapCallbacks, DragCallbacks
    implements KnowledgeBubbleHost {
  // ---------------------------------------------------------------------------
  // Constantes
  // ---------------------------------------------------------------------------

  /// Duree de la celebration de victoire (confettis + freeze) avant la manche suivante.
  static const winCelebrationDuration = 2.5;

  /// Duree maximale de dispersion des notions avant redemarrage automatique.
  static const knowledgeScatterDuration = 6;

  /// Identifiant de l'overlay Flutter affichant Curio et sa jauge de temps.
  static const curioOverlay = 'curio';

  /// Identifiant de l'overlay du bouton d'acceleration pendant la dispersion du savoir.
  static const accelerateOverlay = 'accelerate';

  /// Delai (en secondes reelles) avant l'apparition du bouton d'acceleration.
  static const _accelerateButtonDelay = 2.0;

  /// Facteur d'acceleration applique pendant la dispersion (nombre de sous-pas).
  static const _accelerationFactor = 5;

  /// Duree d'affichage du Game Over avant le redemarrage automatique.
  static const _gameOverFreezeDuration = 2.0;

  /// Nombre de manches avant le redemarrage complet de la partie.
  static const _roundsPerGame = 4;

  /// Espacement minimal entre deux bulles lors des collisions.
  static const _collisionPadding = 6.0;

  /// Variation de la jauge de temps (fraction de la duree totale).
  static const _wrongAnswerPenalty = -0.05;
  static const _correctAnswerBonus = 0.1;

  /// Seuil de la jauge en dessous duquel le mode critique est actif.
  static const _criticalThreshold = 0.3;

  // ---------------------------------------------------------------------------
  // Etat
  // ---------------------------------------------------------------------------

  /// Cle globale permettant de piloter le compte a rebours depuis le moteur Flame.
  final gaugeKey = GlobalKey<CharacterTimeGaugeState>();
  final isCriticalNotifier = ValueNotifier<bool>(false);
  final isTimerPausedNotifier = ValueNotifier<bool>(false);

  /// Generateur de nombres pseudo-aleatoires pour les positions et couleurs.
  final _random = Random();
  final _audioPlayer = AudioPlayer();

  Set<Color> _previousRoundColors = {};
  final Set<Color> _roundColors = {};

  /// Faisceau laser actif et guide de visee.
  LaserBeam? _laser;
  late final AimGuideComponent _aimGuide;
  Vector2? _lastAimPosition;

  /// Etats de manche.
  bool _won = false;
  bool _gameOver = false;
  int _completedRounds = 0;
  late String _currentAnswer;
  late int _currentQuestionId;

  /// Etat des controles affiches pendant la dispersion du savoir.
  double _knowledgeRealTime = 0.0;
  int _timeSteps = 1;
  bool _accelerateVisible = false;

  /// Nombre de sous-pas actifs, expose pour garder certaines animations au
  /// rythme reel lorsque la simulation des bulles est acceleree.
  int get simulationTimeSteps => _timeSteps;

  @override
  bool isFrozen = false;

  @override
  double elapsedFreezeTime = 0.0;

  @override
  double get bubbleRespawnY => _laser?.bubbleRespawnY ?? size.y;

  // ---------------------------------------------------------------------------
  // Cycle de vie Flame
  // ---------------------------------------------------------------------------

  /// Conserve la transparence du canvas Flame pour laisser apparaitre le fond Flutter.
  @override
  Color backgroundColor() => Colors.transparent;

  /// Initialise l'overlay et lance la premiere manche de jeu.
  @override
  Future<void> onLoad() async {
    _aimGuide = AimGuideComponent();
    await add(_aimGuide);
    overlays.add(curioOverlay);
    _selectRandomQuestion();
    await _startRound();
  }

  /// Adapte la disposition de la mascotte lors d'un redimensionnement de fenetre.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _laser?.fitToViewport(size);
  }

  /// Met a jour le temps de freeze, les entites et declenche la resolution des collisions.
  @override
  void update(double dt) {
    // Evite les gros dt (lag, retour d'onglet) qui casseraient la physique.
    final safeDt = dt.clamp(0.0, 1 / 20).toDouble();

    _updateKnowledgeControls(safeDt);

    for (var i = 0; i < _timeSteps; i++) {
      if (i == 0) {
        super.update(safeDt);
      } else {
        _step(safeDt);
      }

      if (isFrozen) {
        elapsedFreezeTime += safeDt;

        if (_gameOver) {
          // Sur un Game Over (temps ecoule), on laisse observer le statut avant de redemarrer.
          if (elapsedFreezeTime >= _gameOverFreezeDuration) {
            restartGame();
            return;
          }
        } else if (_won) {
          final knowledgeBubbles =
          children.whereType<KnowledgeBubbleComponent>().toList();

          // Attendre que les bulles soient bien instanciees avant de verifier la sortie.
          final hasActiveKnowledge = knowledgeBubbles.isNotEmpty;
          final allLeft = hasActiveKnowledge &&
              knowledgeBubbles.every((bubble) => bubble.hasLeftScreen);

          if (allLeft || elapsedFreezeTime >= winCelebrationDuration) {
            // Supprime les bulles de savoir et confettis restants avant la manche suivante.
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
      _handleBubbleCollisions();
    }
  }

  /// Un pas de simulation supplementaire pour accelerer tous les composants Flame.
  void _step(double dt) => super.update(dt);

  // ---------------------------------------------------------------------------
  // Controles de dispersion du savoir
  // ---------------------------------------------------------------------------

  /// Gere l'apparition du bouton selon le temps REEL ecoule (jamais accelere).
  void _updateKnowledgeControls(double realDt) {
    if (!_won || _gameOver) return;

    _knowledgeRealTime += realDt;

    if (!_accelerateVisible && _knowledgeRealTime >= _accelerateButtonDelay) {
      _accelerateVisible = true;
      overlays.add(accelerateOverlay);
    }
  }

  /// Masque le bouton et remet le temps a la normale.
  void _resetKnowledgeControls() {
    _timeSteps = 1;
    _knowledgeRealTime = 0.0;
    _accelerateVisible = false;
    overlays.remove(accelerateOverlay);
  }

  /// Accelere la dispersion des bulles de savoir.
  void accelerateKnowledge() {
    if (!_won || _gameOver) return;
    _timeSteps = _accelerationFactor;
    _accelerateVisible = true; // evite une re-ouverture
    overlays.remove(accelerateOverlay); // le bouton disparait apres usage
  }

  // ---------------------------------------------------------------------------
  // Collisions
  // ---------------------------------------------------------------------------

  /// Detecte et resout les collisions physiques entre toutes les bulles actives.
  void _handleBubbleCollisions() {
    final activeBubbles = children
        .whereType<BubblePhysicsBody>()
        .where((bubble) => bubble.isCollisionActive)
        .toList();

    for (var i = 0; i < activeBubbles.length; i++) {
      for (var j = i + 1; j < activeBubbles.length; j++) {
        final bodyA = activeBubbles[i];
        final bodyB = activeBubbles[j];

        // Pendant la phase de freeze (dispersion), si une bulle de savoir heurte
        // une bulle classique, on applique uniquement un leger ecartement
        // (nudge) sans rebond complet.
        if (isFrozen && _isKnowledgeVsRegular(bodyA, bodyB)) {
          _nudgeRegularBubble(bodyA, bodyB);
        } else {
          BubbleCollisionResolver.resolve(
            bodyA,
            bodyB,
            padding: _collisionPadding,
          );
        }
      }
    }

    // Maintient les bulles dans leurs limites apres les corrections de collision.
    for (final bubble in children.whereType<Bubble>()) {
      bubble.keepWithinBounds();
    }
  }

  bool _isKnowledgeVsRegular(BubblePhysicsBody a, BubblePhysicsBody b) =>
      (a is KnowledgeBubbleComponent && b is Bubble) ||
          (a is Bubble && b is KnowledgeBubbleComponent);

  /// Ecarte legerement la bulle classique de la bulle de savoir.
  void _nudgeRegularBubble(BubblePhysicsBody a, BubblePhysicsBody b) {
    final regularBubble = (a is Bubble ? a : b) as Bubble;
    final knowledgeBubble =
    (a is KnowledgeBubbleComponent ? a : b) as KnowledgeBubbleComponent;

    final delta = regularBubble.position - knowledgeBubble.position;
    final dist = delta.length;
    final minDist = regularBubble.collisionRadius +
        knowledgeBubble.collisionRadius +
        _collisionPadding;

    if (dist < minDist && dist > 0.001) {
      final overlap = minDist - dist;
      final nudge = (delta / dist) * (overlap * 0.4);
      regularBubble.position.add(nudge);
      regularBubble.centerBase.add(nudge);
    }
  }

  // ---------------------------------------------------------------------------
  // Couleurs et questions
  // ---------------------------------------------------------------------------

  /// Selectionne une teinte primaire vive non repetee dans la meme manche.
  Color _nextRoundColor() {
    var availableColors = Colors.primaries
        .where(
          (color) =>
      !_previousRoundColors.contains(color) &&
          !_roundColors.contains(color),
    )
        .toList();
    if (availableColors.isEmpty) {
      availableColors = Colors.primaries
          .where((color) => !_roundColors.contains(color))
          .toList();
    }

    final color = availableColors[_random.nextInt(availableColors.length)];
    _roundColors.add(color);
    return color;
  }

  /// Tire une question au hasard dans le catalogue en evitant une repetition immediate.
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

  // ---------------------------------------------------------------------------
  // Manches
  // ---------------------------------------------------------------------------

  /// Initialise les entites de la manche : mascotte laser et bulles de reponse.
  Future<void> _startRound({bool reuseLaser = false}) async {
    final gameSize = size.x > 0 ? size : Vector2(800, 600);
    final question = GameQuestions.all[_currentQuestionId];
    _currentAnswer = question.answer;
    _previousRoundColors = Set<Color>.of(_roundColors);
    _roundColors.clear();

    final labelColor = _nextRoundColor();
    final laser = _laser;
    if (reuseLaser && laser != null) {
      for (final bubble in children.whereType<Bubble>().toList()) {
        bubble.removeFromParent();
      }
      laser.updateLabel(question.prompt, labelColor);
      laser.fitToViewport(gameSize);
    } else {
      final newLaser = LaserBeam(
        origin: Vector2(gameSize.x / 2, gameSize.y * 0.76),
        targetPosition: Vector2(gameSize.x / 2, gameSize.y * 0.58),
        label: question.prompt,
        labelColor: labelColor,
      );
      _laser = newLaser;
      newLaser.fitToViewport(gameSize);
      await add(newLaser);
    }

    for (final choice in question.choices) {
      await _spawn(
        choice,
        BubbleDirection.bottomToTop,
        15,
        BubbleShape.sphere,
        const Size(90, 90),
        _nextRoundColor(),
      );
    }
  }

  /// Genere une bulle de reponse sur le canvas.
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
        onWrongImpact: _onWrongAnswer,
        config: BubbleConfig(
          text: text,
          direction: direction,
          speed: speed,
          style: BubbleStyle(shape: shape, size: bubbleSize, baseColor: color),
        ),
      ),
    );
  }

  /// Calcule une position initiale aleatoire dans la zone autorisee.
  Vector2 _randomPosition(double halfWidth, double halfHeight) {
    final gameSize = size.x > 0 ? size : Vector2(800, 600);
    final availableWidth = max(0.0, gameSize.x - 2 * halfWidth);
    final availableHeight = max(0.0, bubbleRespawnY - 2 * halfHeight);

    return Vector2(
      availableWidth == 0
          ? gameSize.x / 2
          : halfWidth + _random.nextDouble() * availableWidth,
      availableHeight == 0
          ? max(0.0, bubbleRespawnY - halfHeight)
          : halfHeight + _random.nextDouble() * availableHeight,
    );
  }

  /// Applique un malus de temps lors d'une mauvaise reponse (-5% de la duree totale).
  void _onWrongAnswer() {
    if (_won || _gameOver) return;
    gaugeKey.currentState?.addTime(_wrongAnswerPenalty);
  }

  /// Declenche l'animation de reussite et l'ejection des bulles de savoir.
  void _startFreezeOnWin(Vector2 popPosition) {
    if (_won || _gameOver) return;

    // Bonus de temps pour bonne reponse (+10% de la duree totale).
    gaugeKey.currentState?.addTime(_correctAnswerBonus);
    _won = true;
    isFrozen = true;
    isTimerPausedNotifier.value = true;
    gaugeKey.currentState?.pause();
    _resetKnowledgeControls();

    // Gerbe de confettis depuis le point d'impact.
    add(
      ConfettiComponent(
        origin: popPosition.clone(),
        duration: 3,
        particleCount: 90,
      ),
    );

    final previousQuestionId = _currentQuestionId;
    _playAnswerAudio(GameQuestions.all[previousQuestionId]);

    _selectRandomQuestion(excluding: previousQuestionId);
    final nextQuestion = GameQuestions.all[_currentQuestionId];
    _laser?.updateLabel(nextQuestion.prompt, _nextRoundColor());
  }

  /// Joue l'audio de la reponse si disponible (ex: bonjour.mp3, aurevoir.mp3).
  void _playAnswerAudio(dynamic question) {
    final audioName = question.nameAudio;
    if (audioName == null || audioName.isEmpty) return;

    final isInFrench = question.answer == 'Merci';
    final audioPath = isInFrench ? 'audio/french/$audioName' : 'audio/$audioName';

    try {
      _audioPlayer.stop();
      _audioPlayer.setVolume(1.0);
      _audioPlayer.play(AssetSource(audioPath));
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Redemarrage et manche suivante
  // ---------------------------------------------------------------------------

  /// Supprime bulles, bulles de savoir, confettis et laser de la manche courante.
  void _clearRoundEntities() {
    for (final child in children.toList()) {
      if (child is Bubble ||
          child is KnowledgeBubbleComponent ||
          child is ConfettiComponent) {
        child.removeFromParent();
      }
    }
    _laser?.removeFromParent();
    _laser = null;
  }

  /// Demarre une nouvelle partie.
  void restartGame() {
    final previousQuestionId = _currentQuestionId;

    _clearRoundEntities();
    _won = false;
    _gameOver = false;
    _completedRounds = 0;
    isFrozen = false;
    isCriticalNotifier.value = false;
    isTimerPausedNotifier.value = false;
    elapsedFreezeTime = 0.0;
    _selectRandomQuestion(excluding: previousQuestionId);
    gaugeKey.currentState?.restart();
    _resetKnowledgeControls();
    resumeEngine();
    _startRound();
  }

  /// Nettoie les composants en place et relance une nouvelle manche sans
  /// reinitialiser la jauge de temps.
  void nextRound() {
    _completedRounds++;
    if (_completedRounds >= _roundsPerGame) {
      restartGame();
      return;
    }

    _clearRoundEntities();
    _won = false;
    _gameOver = false;
    isFrozen = false;
    isCriticalNotifier.value =
        (gaugeKey.currentState?.remaining ?? 1.0) <= _criticalThreshold;
    isTimerPausedNotifier.value = false;
    gaugeKey.currentState?.resume();
    elapsedFreezeTime = 0.0;
    _resetKnowledgeControls();
    resumeEngine();
    _startRound();
  }

  /// Declenche l'arret de jeu lorsque le temps imparti est ecoule.
  void onTimeUp() {
    if (_won || _gameOver) return;

    _gameOver = true;
    isFrozen = true;
    isTimerPausedNotifier.value = true;
    elapsedFreezeTime = 0.0;
    gaugeKey.currentState?.pause();
    _resetKnowledgeControls();
  }

  /// Alias publics.
  void restart() => restartGame();
  void next() => nextRound();

  // ---------------------------------------------------------------------------
  // Visee et tir
  // ---------------------------------------------------------------------------

  void _updateAimTrajectory(Vector2 targetPos) {
    _lastAimPosition = targetPos.clone();
    final laser = _laser;
    if (_won || isFrozen || laser == null) {
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

    if (_won || isFrozen || laser == null) return;

    // Si une trajectoire etait activement affichee par le viseur, on la suit a 100%.
    if (trajectory != null && trajectory.points.length >= 2) {
      laser.fireTrajectory(trajectory);
    } else if (targetPos != null) {
      laser.fireAt(targetPos);
    }
  }

  // ---------------------------------------------------------------------------
  // Entrees tactiles
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

  /// Active la visee au premier contact sans declencher le tir immediatement.
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    _updateAimTrajectory(event.localPosition);
  }

  /// Declenche le tir laser au relachement du doigt apres ajustement.
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