import 'package:bubble/core/services/audio/sound_effect.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/game/presentation/bubble_game.dart';

/// Point d'entree principal de l'application.
/// Initialise les liaisons systeme, les effets audio et lance l'ecran de jeu.
/// Creates shared audio services before handing ownership to the game instance.
Future<void> main() async {
  // Garantit l'initialisation correcte du moteur Flutter avant tout appel asynchrone.
  WidgetsFlutterBinding.ensureInitialized();

  // Active le mode plein ecran immersif pour masquer la barre de statut et la barre de navigation.
  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Initialise les effets sonores proceduraux via audioplayers.
  final soundEffects = SoundEffects();
  await soundEffects.init();

  // Instance unique du jeu coordonnant la boucle Flame, la physique et les entites.
  final game = BubbleGame(soundEffects: soundEffects);

  // Lance l'application (voir app.dart).
  runApp(BubbleApp(game: game));
}