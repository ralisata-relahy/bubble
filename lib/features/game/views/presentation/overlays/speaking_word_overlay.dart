// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:bubble/features/curio/controllers/curio_sound_controller.dart';
import 'package:bubble/features/game/controllers/game_controller.dart';
import 'package:bubble/features/game/data/game_questions.dart';
import 'package:bubble/features/game/views/presentation/bubble_game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:string_similarity/string_similarity.dart';

// -----------------------------------------------------------------------------
// Modèles
// -----------------------------------------------------------------------------

/// Étapes d'une tentative de prononciation.
enum _Phase {
  initializing,
  unavailable,
  idle,
  listening,
  correct,
  wrong,
  noSpeech,
}

/// État immuable : tout ce que l'écran affiche en découle.
@immutable
class _Attempt {
  const _Attempt({
    this.phase = _Phase.initializing,
    this.heard = '',
    this.score = 0,
  });

  final _Phase phase;
  final String heard;
  final double score;

  _Attempt copyWith({_Phase? phase, String? heard, double? score}) => _Attempt(
        phase: phase ?? this.phase,
        heard: heard ?? this.heard,
        score: score ?? this.score,
      );

  bool get isListening => phase == _Phase.listening;

  /// Le micro peut être (re)lancé dans ces phases.
  bool get canListen =>
      phase == _Phase.idle ||
      phase == _Phase.wrong ||
      phase == _Phase.noSpeech;

  String get message {
    switch (phase) {
      case _Phase.initializing:
        return 'Preparing the microphone...';
      case _Phase.unavailable:
        return 'Speech not available (check permissions)';
      case _Phase.idle:
        return 'Tap the microphone and say the word';
      case _Phase.listening:
        return heard.isEmpty ? 'Listening...' : heard;
      case _Phase.correct:
      case _Phase.wrong:
        return heard;
      case _Phase.noSpeech:
        return "I didn't catch that. Try again";
    }
  }

  /// Ligne de retour sous le texte (null = rien à afficher).
  String? get feedback {
    switch (phase) {
      case _Phase.correct:
        return 'Correct!';
      case _Phase.wrong:
        return 'Try again';
      default:
        return null;
    }
  }

  Color get feedbackColor =>
      phase == _Phase.correct ? Colors.greenAccent : Colors.redAccent;
}

/// Mot à prononcer et son audio américain.
@immutable
class _Target {
  const _Target(this.word, this.audioAsset);

  final String word;

  /// Chemin relatif à `assets/` (AssetSource ajoute le préfixe).
  final String audioAsset;
}

// -----------------------------------------------------------------------------
// Overlay
// -----------------------------------------------------------------------------

class SpeakingWordOverlay extends StatefulWidget {
  const SpeakingWordOverlay({
    super.key,
    required this.controller,
    required this.game,
  });

  final GameController controller;
  final BubbleGame game;

  @override
  State<SpeakingWordOverlay> createState() => _SpeakingWordOverlayState();
}

class _SpeakingWordOverlayState extends State<SpeakingWordOverlay> {
  static const double _threshold = 0.8;
  static const _correctDelay = Duration(milliseconds: 1000);
  static const _finishDelay = Duration(milliseconds: 1500);
  static const _retryDelay = Duration(milliseconds: 1200);

  /// Dossier des sons (relatif à `assets/`), déclaré dans pubspec.yaml.
  static const _audioDir = 'audio/american_english';

  final SpeechToText _speech = SpeechToText();
  final ValueNotifier<_Attempt> _attempt = ValueNotifier(const _Attempt());

  late final List<_Target> _targets = _buildTargets();
  String _localeId = 'en_US';
  Timer? _timer;

  GameController get _c => widget.controller;
  _Attempt get _state => _attempt.value;

  /// Cible courante : dépend du nombre de barreaux déjà retirés.
  _Target get _target {
    final done = GameController.initialBarCount - _c.barreCount.value;
    return _targets[done.clamp(0, _targets.length - 1)];
  }

  String get _expected => _target.word;

  CurioSoundController get _sound => Get.isRegistered<CurioSoundController>()
      ? Get.find<CurioSoundController>()
      : Get.put(CurioSoundController());

  // ---------------------------------------------------------------------------
  // Cycle de vie
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _announceWord();
    _initSpeech();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.cancel();
    _attempt.dispose();
    super.dispose();
  }

  /// Seules les questions avec `nameAudioEn` sont utilisables ici.
  List<_Target> _buildTargets() {
    final targets = <_Target>[];
    for (final q in GameQuestions.all) {
      final file = q.nameAudioEn;
      if (file == null || file.isEmpty) continue;

      final match = RegExp(r"'([^']+)'").firstMatch(q.prompt);
      if (match == null) continue;

      // "sorry / excuse me" -> "sorry"
      final word = match.group(1)!.split('/').first.trim();
      targets.add(_Target(word, '$_audioDir/$file'));

      if (targets.length == GameController.initialBarCount) break;
    }
    assert(targets.isNotEmpty, 'No question with nameAudioEn found.');
    return targets;
  }

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------

  void _set(_Attempt next) {
    if (!mounted) return;
    _attempt.value = next;
  }

  void _later(Duration delay, VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (mounted) action();
    });
  }

  /// Affiche le mot sur le label du laser et prépare le son du bouton.
  void _announceWord() {
    widget.game.updateLaserLabel('Say the word: $_expected!', Colors.white);
    _selectWordSound();
  }

  /// Le bouton du personnage rejoue `soundAsset`. Changer l'asset le fait
  /// jouer une fois (via `ever` dans le controller). Si l'asset est identique,
  /// on le rejoue à la main.
  void _selectWordSound() {
    final sound = _sound;
    final asset = _target.audioAsset;
    if (sound.soundAsset.value == asset) {
      unawaited(sound.play());
    } else {
      sound.soundAsset.value = asset;
    }
  }

  // ---------------------------------------------------------------------------
  // Reconnaissance vocale
  // ---------------------------------------------------------------------------

  Future<void> _initSpeech() async {
    final enabled = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );

    if (enabled) {
      final locales = await _speech.locales(); // seulement après initialize()
      _localeId = _pickEnglishLocale(locales) ?? _localeId;
      debugPrint('Selected locale: $_localeId');
    }

    _set(_Attempt(phase: enabled ? _Phase.idle : _Phase.unavailable));
  }

  /// American English first, then British, then any English locale.
  String? _pickEnglishLocale(List<LocaleName> locales) {
    const preferred = ['en_us', 'en_gb'];
    final ids = {
      for (final l in locales)
        l.localeId.toLowerCase().replaceAll('-', '_'): l.localeId,
    };

    for (final p in preferred) {
      if (ids.containsKey(p)) return ids[p];
    }
    for (final e in ids.entries) {
      if (e.key.startsWith('en')) return e.value;
    }
    return null;
  }

  Future<void> _startListening() async {
    if (!_state.canListen) return;
    _timer?.cancel();
    _set(const _Attempt(phase: _Phase.listening));

    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: _localeId,
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  /// Arrête le micro : le résultat final déclenche ensuite l'évaluation.
  Future<void> _stopListening() => _speech.stop();

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_state.isListening) return;

    if (result.finalResult) {
      _evaluate(
        result.recognizedWords,
        alternates: result.alternates.map((a) => a.recognizedWords),
      );
    } else {
      // Résultat partiel : on affiche seulement, on ne valide jamais.
      _set(_state.copyWith(heard: result.recognizedWords));
    }
  }

  /// Filet de sécurité : l'écoute s'est arrêtée sans résultat final.
  void _onSpeechStatus(String status) {
    debugPrint('Speech status: $status');
    final ended = status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus;
    if (!ended || !_state.isListening) return;

    if (_state.heard.isEmpty) {
      _set(const _Attempt(phase: _Phase.noSpeech));
    } else {
      _evaluate(_state.heard);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('Speech error: ${error.errorMsg}');
    if (_state.isListening) _set(const _Attempt(phase: _Phase.noSpeech));
  }

  // ---------------------------------------------------------------------------
  // Correction
  // ---------------------------------------------------------------------------

  /// Évalue une tentative une seule fois (la phase `listening` sert de garde).
  void _evaluate(String heard, {Iterable<String> alternates = const []}) {
    if (!_state.isListening) return;

    if (heard.trim().isEmpty) {
      _set(const _Attempt(phase: _Phase.noSpeech));
      return;
    }

    final score = [heard, ...alternates]
        .map(_bestScore)
        .reduce((a, b) => a > b ? a : b);
    final passed = score >= _threshold;

    _set(_Attempt(
      phase: passed ? _Phase.correct : _Phase.wrong,
      heard: heard,
      score: score,
    ));

    if (passed) {
      _onCorrect();
    } else {
      _later(_retryDelay, () => _set(const _Attempt(phase: _Phase.idle)));
    }
  }

  void _onCorrect() {
    _c.decrementeBarCount();

    if (_c.barreCount.value <= 0) {
      _c.isCaged.value = false; // la cage se défait
      _later(_finishDelay, _c.finishSpeakingWord);
      return;
    }

    _later(_correctDelay, () {
      _announceWord();
      _set(const _Attempt(phase: _Phase.idle));
    });
  }

  String _normalize(String input) {
    const from = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿ';
    const to = 'aaaaaceeeeiiiinooooouuuuyy';
    var s = input.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Compare le mot attendu à la phrase entière ET à chaque mot.
  double _bestScore(String spoken) {
    final expected = _normalize(_expected);
    final cleaned = _normalize(spoken);
    if (cleaned.isEmpty) return 0;

    var best = 0.0;
    for (final candidate in <String>{cleaned, ...cleaned.split(' ')}) {
      final score = expected.similarityTo(candidate);
      if (score > best) best = score;
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final panelWidth = (screenWidth * 0.8).clamp(260.0, 420.0);

  return SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 200, 16, 16),
        child: SizedBox(
          width: panelWidth - 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTargetWord(),
              const SizedBox(height: 8),
              ValueListenableBuilder<_Attempt>(
                valueListenable: _attempt,
                builder: (_, attempt, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMessageBox(attempt),
                    const SizedBox(height: 8),
                    _buildFeedback(attempt),
                    Row(
                      children: [
                        _HelpButton(
                          listening: attempt.isListening,
                          enabled: attempt.canListen || attempt.isListening,
                          onPressed: attempt.isListening
                              ? _stopListening
                              : _startListening,
                        ),
                        _HelpButton(
                          listening: attempt.isListening,
                          enabled: attempt.canListen || attempt.isListening,
                          onPressed: attempt.isListening
                              ? _stopListening
                              : _startListening,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildTargetWord() => Obx(() {
        _c.barreCount.value; // reconstruit quand le mot change
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _expected.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      });

  Widget _buildMessageBox(_Attempt attempt) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          attempt.message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      );

  /// Hauteur fixe pour que la mise en page ne saute pas.
  Widget _buildFeedback(_Attempt attempt) => SizedBox(
        height: 30,
        child: attempt.feedback == null
            ? null
            : Text(
                attempt.feedback!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: attempt.feedbackColor,
                ),
              ),
      );
}

// -----------------------------------------------------------------------------
// Bouton micro
// -----------------------------------------------------------------------------

class _HelpButton extends StatefulWidget {
  const _HelpButton({
    required this.listening,
    required this.enabled,
    required this.onPressed,
  });

  final bool listening;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  State<_HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<_HelpButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didUpdateWidget(covariant _HelpButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.listening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final colors = widget.listening
        ? const [Color(0xFFFF5F6D), Color(0xFFFFC371)]
        : const [Color(0xFF7F5AF0), Color(0xFF2CB1FF)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 1.8,
          height: size * 1.8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Anneau pulsant pendant l'écoute
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) {
                  final t = _pulse.value;
                  return Opacity(
                    opacity: widget.listening ? (1 - t) * 0.5 : 0,
                    child: Container(
                      width: size * (1 + t * 0.8),
                      height: size * (1 + t * 0.8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.first,
                      ),
                    ),
                  );
                },
              ),
              // Bouton principal
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.enabled ? 1 : 0.4,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.enabled ? widget.onPressed : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.first.withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.listening
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.listening ? 'Tap to stop' : 'Tap to speak',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}