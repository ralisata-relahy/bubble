import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/game/presentation/bubble_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleFonts.pendingFonts([GoogleFonts.poppins]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await FlameAudio.audioCache.loadAll([
    'bouble_pop.mp3',
    'false_pop.mp3',
    'e-ho.mp3'
  ]);
  runApp(GameWidget(game: BubbleGame()));
}
