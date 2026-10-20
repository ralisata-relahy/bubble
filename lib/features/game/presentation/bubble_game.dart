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
import '../../bubble/presentation/widgets/knowledge_bubble.dart';

class BubbleGame extends FlameGame with DragCallbacks {
  static const backgroundAsset = 'Bg_water.webp';
  static const int targetCount = 5;

  final _random = Random();

  late final SpriteComponent _background;
  late LaserBeam _laser;
  late final TextComponent _hud;
  static const List<Map<String, dynamic>> data = [
    {
      "question": "What does 'hello' mean in French?",
      "answer": "Bonjour",
      "displayed_choice": [
        "Bonjour",
        "Au revoir",
        "À très bientôt",
        "Oke",
        "Beaucoup",
      ],
      "knowledge":[
        "french",
        "English",
        "Pananme",
        "Beaugosse"
      ]
    },
    {
      "question": "What does 'goodbye' mean in French?",
      "answer": "Au revoir",
      "displayed_choice": [
        "Bonjour",
        "Merci",
        "Au revoir",
        "Bonsoir",
        "Beaucoup",
      ],
      "knowledge":[
        "french",
        "English",
        "Pananme",
        "Beaugosse"
      ]
    },
    {
      "question": "What does 'thank you' mean in French?",
      "answer": "Merci",
      "displayed_choice": [
        "Pardon",
        "Merci",
        "Bonjour",
        "Salut",
        "Beaucoup",
      ],
      "knowledge":[
        "french",
        "English",
        "Pananme",
        "Beaugosse"
      ]
    },
  ];

  WinOverlay? _overlay;
  int _popped = 0;
  bool _won = false;
  late String _currentAnswer;
  int _currentQuestionId = 0;
  bool isFrozen = false;
  double elapsedFreezeTime = 0.0;
  int _activeKnowledgeBubbles = 0;
  bool _waitingForKnowledgeBubblesToLeave = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (isFrozen) {
      elapsedFreezeTime += dt;
    }
    _handleBubbleCollisions();
  }

  void _handleBubbleCollisions() {
    final allBubbles = <PositionComponent>[
      ...children.whereType<Bubble>().where((b) => b.isCollisionActive),
      ...children.whereType<KnowledgeBubbleComponent>().where((k) => k.isCollisionActive),
    ];

    const double padding = 6.0;

    for (var i = 0; i < allBubbles.length; i++) {
      for (var j = i + 1; j < allBubbles.length; j++) {
        final a = allBubbles[i];
        final b = allBubbles[j];

        if (a is Bubble) {
          a.checkAndResolveCollision(b, padding: padding);
        } else if (a is KnowledgeBubbleComponent) {
          a.checkAndResolveCollision(b, padding: padding);
        }
      }
    }
  }

  void onKnowledgeBubbleRemoved() {
    if (!_waitingForKnowledgeBubblesToLeave) return;
    _activeKnowledgeBubbles--;
    if (_activeKnowledgeBubbles <= 0) {
      _waitingForKnowledgeBubblesToLeave = false;
      isFrozen = false;
      restart();
    }
  }

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
    final questionData = data[_currentQuestionId];
    final questionText = questionData["question"] as String;
    _currentAnswer = questionData["answer"] as String;

    _laser = LaserBeam(
      origin: Vector2(gameSize.x / 2, 700),
      targetPosition: Vector2(gameSize.x / 2, 600),
      label: questionText,
    );
    await add(_laser);
    final random = Random();

    for (final choice in data[_currentQuestionId]["displayed_choice"]) {
      final color = Colors.primaries[random.nextInt(Colors.primaries.length)];

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

  Future<void> _spawn(
    String text,
    BubbleDirection dir,
    double speed,
    BubbleShape shape,
    Size size,
    Color color,
  ) async {
    final pos = _randomPosition(size.width / 2, size.height / 2);
    return add(
      Bubble(
        position: pos,
        textColor: Colors.white,
        random: _random,

        // Définit si cette bulle peut éclater définitivement (si c'est la bonne réponse)
        canPop: (t) => t == _currentAnswer,

        // Appelée lorsque la bulle est touchée et éclate
        onTargetPopped: (popPos) {
          if (text == _currentAnswer) {
            _startFreezeOnWin(popPos);
          } else {
            onTrueBubblePopped();
          }
        },

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
  }

  void _startFreezeOnWin(Vector2 popPosition) {
    if (_won) return;

    _won = true;
    isFrozen = true;
    elapsedFreezeTime = 0.0;

    // 1) Génère les bulles de connaissances pour la question actuelle qui vient d'être résolue
    _spawnKnowledgePopBubbles(popPosition, _currentQuestionId);

    // 2) Avance à la question suivante pour la manche à venir
    _currentQuestionId = (_currentQuestionId + 1) % data.length;
    final nextQuestionData = data[_currentQuestionId];
    final nextQuestionText = nextQuestionData["question"] as String;
    _currentAnswer = nextQuestionData["answer"] as String;

    // 3) Met à jour le texte du laser immédiatement
    _laser.updateLabelText(nextQuestionText);
  }

  void _spawnKnowledgePopBubbles(Vector2 origin, int questionId) {
    final rawKnowledge = data[questionId]["knowledge"];
    final List<String> knowledgeList = rawKnowledge is List
        ? rawKnowledge.map((e) => e.toString()).toList()
        : ["knowledge"];

    _activeKnowledgeBubbles = knowledgeList.length;
    _waitingForKnowledgeBubblesToLeave = true;

    final random = Random();

    final style = BubbleStyle(
      shape: BubbleShape.sphere,
      size: Size(
        70 + random.nextInt(61).toDouble(), // 100 à 160
        70 + random.nextInt(41).toDouble(), // 100 à 140
      ),
      baseColor: Colors.purpleAccent,
    );

    for (var i = 0; i < knowledgeList.length; i++) {
      final angle = (i / knowledgeList.length) * 2 * pi;
      add(
        KnowledgeBubbleComponent(
          position: origin.clone(),
          textColor: Colors.white,
          random: _random,
          isBurstBubble: true,
          config: BubbleConfig(
            style: style,
            text: knowledgeList[i],
            speed: 50 + _random.nextDouble() * 30,
            customDirection: Vector2(cos(angle), sin(angle)),
            waveAmplitude: 0,
          ),
        ),
      );
    }
  }

  void restart() {
    _overlay?.removeFromParent();
    _overlay = null;

    for (final child in children.toList()) {
      if (child is Bubble || child is KnowledgeBubbleComponent) {
        child.removeFromParent();
      }
    }

    _laser.removeFromParent();

    _popped = 0;
    _won = false;
    isFrozen = false;
    elapsedFreezeTime = 0.0;
    _waitingForKnowledgeBubblesToLeave = false;
    _activeKnowledgeBubbles = 0;
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

    if (_won || isFrozen) return;

    _laser.updateTarget(event.localEndPosition);
  }
}