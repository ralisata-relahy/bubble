// import 'dart:math';

// import 'package:auto_size_text/auto_size_text.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:lingo_learner/data/db/word_datafetch.dart';
// import 'package:lingo_learner/data/models/word_model.dart';
// import 'package:lingo_learner/pad_audio/pad_audio_service.dart';
// import 'package:lingo_learner/res/assets/assets.dart';
// import 'package:lingo_learner/res/colors/app_color.dart';
// import 'package:lingo_learner/screens/games/controller/game_controller.dart';
// import 'package:lingo_learner/screens/games/speak_word_screen/controller/speak_word_controller.dart';
// import 'package:lingo_learner/screens/games/speak_word_screen/widget/bubble_background.dart';
// import 'package:lingo_learner/screens/games/turbo_fill_screen/utils/normalizer.dart';
// import 'package:lingo_learner/screens/games/widgets/circle_icon_widget.dart';
// import 'package:lingo_learner/screens/games/widgets/custom_progress_bar_widget.dart';
// import 'package:lingo_learner/screens/games/widgets/top_bar_widget.dart';
// import 'package:lingo_learner/services/storage_services.dart';
// import 'package:lingo_learner/utils/utils.dart';
// import 'package:voice_anim_kit/voice_anim_kit.dart';

// class SpeakWordScreen extends StatefulWidget {
//   const SpeakWordScreen({super.key});

//   @override
//   State<SpeakWordScreen> createState() => _SpeakWordScreenState();
// }

// class _SpeakWordScreenState extends State<SpeakWordScreen>
//     with TickerProviderStateMixin, RouteAware {
//   // bool isListening = false;

//   late AnimationController micController;
//   late AnimationController pulseController;
//   late AnimationController waveController;
//   var gameController = Get.find<GameController>();
//   final storage = Get.find<StorageServices>();
//   final controller = Get.find<SpeakWordController>();
//   // final SpeechService speechService = SpeechService();
//   late AudioPlayer _audioPlayer;
//   int? currentPlayingIndex;
//   double level = 0.0;
//   double minSoundLevel = 50000;
//   double maxSoundLevel = -50000;

//   final wordsDbHandler = WordsDbHandler();
//   final Rx<WordModel?> randomWord = Rx<WordModel?>(null);

//   Future<void> loadRandomWord() async {
//     final lang = gameController.keyCode ?? "en_US";
//     final word = await wordsDbHandler.getRandomWordWithSynonym(
//       targetLangCode: lang,
//     );
//     randomWord.value = word;
//   }

//   @override
//   void initState() {
//     gameController.initilize();
//     // controller.initSpeech();

//     _audioPlayer = AudioPlayer();
//     super.initState();

//     micController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 250),
//       lowerBound: 1,
//       upperBound: 1.1,
//     );

//     pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 1),
//     )..repeat(reverse: true);

//     waveController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat();

//     loadRandomWord();
//   }

//   void soundLevelListener(double level) {
//     minSoundLevel = min(minSoundLevel, level);
//     maxSoundLevel = max(maxSoundLevel, level);
//     setState(() {
//       this.level = level;
//     });
//   }

//   @override
//   void didPopNext() {
//     gameController.getData();
//     super.didPopNext();
//   }

//   Future<void> playWordAudio({
//     required int index,
//     required String audioUrl,
//     double speed = 1.0,
//   }) async {
//     try {
//       if (currentPlayingIndex == index) {
//         if (PlayerState.playing == _audioPlayer.state) {
//           await _audioPlayer.pause();
//           gameController.isPlaying.value = false;
//         } else if (PlayerState.paused == _audioPlayer.state) {
//           // Just resume — don't reload the file from scratch.
//           await _audioPlayer.resume();
//           gameController.isPlaying.value = true;
//         } else {
//           await playAudio(
//             gameController.keyCode!,
//             gameController.targetLang!,
//             audioUrl,
//             speed: speed,
//           );
//         }
//       } else {
//         await _audioPlayer.stop();
//         currentPlayingIndex = index;
//         await playAudio(
//           gameController.keyCode!,
//           gameController.targetLang!,
//           audioUrl,
//           speed: speed,
//         );
//       }
//       setState(() {});
//     } catch (e) {
//       debugPrint("Audio error: $e");
//     }
//   }

//   /// ▶ Play Audio
//   Future<void> playAudio(
//     String keyCode,
//     String language,
//     String fileName, {
//     double speed = 1.0,
//   }) async {
//     var nameProcessed = Utils.getStringSpaceRemoved(
//       gameController.targetLang!,
//     ).trim();
//     var capitalizedName = Utils.toCapitalized(nameProcessed);
//     final packName = 'audio$capitalizedName';
//     final folderName = nameProcessed.toLowerCase(); // ✅ canonical form

//     final path = await PadAudioService.getUnifiedPath(
//       packName: packName,
//       languageName: folderName, // ✅ always lowercase
//       fileName: fileName,
//       buildNumber: storage.buildNumber!,
//     );

//     // TEMP DEBUG — remove after we confirm the naming issue
//     if (path == null) {
//       await PadAudioService.debugSearchFile(
//         packName: packName,
//         languageName: folderName,
//         buildNumber: storage.buildNumber!,
//         searchTerm: "elect",
//       );
//     }
//     debugPrint("Verified Path: $path");
//     // Utils.snackBar("Verified", "Audio files are accessible. $path");

//     if (path != null) {
//       // await _audioPlayer.play(DeviceFileSource(path));
//       await _audioPlayer.setSourceDeviceFile(path);

//       /// set speed
//       await _audioPlayer.setPlaybackRate(speed);
//       await _audioPlayer.resume();
//     }

//     //------------------------------Audio Method channel calling end--------------------------------
//     // await _audioPlayer.play(AssetSource(path));
//     setState(() => gameController.isPlaying.value = true);
//   }

//   /// ⏸ Pause Audio
//   Future<void> pauseAudio() async {
//     await _audioPlayer.pause();
//     setState(() => gameController.isPlaying.value = false);
//   }

//   /// ⏹ Stop Audio
//   Future<void> stopAudio() async {
//     await _audioPlayer.stop();
//     setState(() => gameController.isPlaying.value = false);
//   }

//   void startListeningAnimation() {
//     // setState(() => isListening = true);
//     micController.forward().then((_) => micController.reverse());
//   }

//   // void stopListeningAnimation() {
//   //   setState(() => isListening = false);
//   // }

//   @override
//   void dispose() {
//     micController.dispose();
//     pulseController.dispose();
//     waveController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Obx(
//         () => gameController.isLoading.isTrue
//             ? Center(child: CircularProgressIndicator())
//             : Container(
//                 width: double.infinity,
//                 height: double.infinity,
//                 decoration: const BoxDecoration(
//                   image: DecorationImage(
//                     image: AssetImage("assets/images/Bg_fish.png"),
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//                 child: Stack(
//                   children: [
//                     const BubbleBackground(),

//                     SafeArea(
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           const SizedBox(height: 10),
//                           topBar(),
//                           const SizedBox(height: 15),

//                           levelBar(),

//                           const SizedBox(height: 10),

//                           /// FISH CONTAINER
//                           Container(
//                             width: MediaQuery.of(context).size.width * 0.7,
//                             height: 50,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withValues(alpha: .2),
//                               borderRadius: BorderRadius.circular(50),
//                               border: Border.all(color: Colors.white54),
//                             ),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                               children: [
//                                 ColorFiltered(
//                                   colorFilter: ColorFilter.mode(
//                                     AppColor.yellowColor,
//                                     BlendMode.modulate,
//                                   ),
//                                   child: Image(
//                                     image: AssetImage(Assets.fishButton),
//                                     width: 50,
//                                     height: 50,
//                                   ),
//                                 ),
//                                 ColorFiltered(
//                                   colorFilter: ColorFilter.mode(
//                                     AppColor.yellowColor,
//                                     BlendMode.modulate,
//                                   ),
//                                   child: Image(
//                                     image: AssetImage(Assets.fishButton),
//                                     width: 50,
//                                     height: 50,
//                                   ),
//                                 ),
//                                 Image(
//                                   image: AssetImage(Assets.fishButton),
//                                   width: 50,
//                                   height: 50,
//                                 ),
//                               ],
//                             ),
//                           ),

//                           const SizedBox(height: 10),

//                           Obx(() {
//                             final word = randomWord.value;
//                             if (word == null) {
//                               return Container(
//                                 width: 260,
//                                 height: 220,
//                                 alignment: Alignment.center,
//                                 decoration: BoxDecoration(
//                                   color: Colors.white.withValues(alpha: .95),
//                                   borderRadius: BorderRadius.circular(30),
//                                 ),
//                                 child: const CircularProgressIndicator(),
//                               );
//                             }

//                             return Container(
//                               width: 260,
//                               padding: const EdgeInsets.all(24),
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withValues(alpha: .95),
//                                 borderRadius: BorderRadius.circular(30),
//                               ),
//                               child: Column(
//                                 children: [
//                                   const Text(
//                                     "SPEAK THE WORD",
//                                     style: TextStyle(
//                                       color: Colors.blue,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                     word.originWord.toUpperCase(),
//                                     style: const TextStyle(
//                                       color: Colors.grey,
//                                       fontWeight: FontWeight.w600,
//                                       fontSize: 11,
//                                       letterSpacing: 1.1,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 5),
//                                   ShaderMask(
//                                     shaderCallback: (bounds) {
//                                       return const LinearGradient(
//                                         colors: [Colors.blue, Colors.purple],
//                                       ).createShader(bounds);
//                                     },
//                                     child: AutoSizeText(
//                                       displayWord(word.meaning),
//                                       maxLines: 1,
//                                       minFontSize: 16,
//                                       style: const TextStyle(
//                                         fontSize: 38,
//                                         fontWeight: FontWeight.w900,
//                                         color: Colors.white,
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(height: 5),
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       circleButton(
//                                         Icons.pets,
//                                         40,
//                                         gradient: LinearGradient(
//                                           colors: [
//                                             Colors.deepPurple,
//                                             Colors.purple,
//                                           ],
//                                         ),
//                                         onTap: () {
//                                           final audioUrl = word.audio;
//                                           if (audioUrl.isNotEmpty) {
//                                             playWordAudio(
//                                               index: 0,
//                                               audioUrl: audioUrl,
//                                               speed: 0.5,
//                                             );
//                                           }
//                                         },
//                                       ),
//                                       const SizedBox(width: 20),
//                                       circleButton(
//                                         Icons.volume_up,
//                                         55,
//                                         onTap: () {
//                                           final audioUrl = word.audio;
//                                           if (audioUrl.isNotEmpty) {
//                                             playWordAudio(
//                                               index: 0,
//                                               audioUrl: audioUrl,
//                                             );
//                                           }
//                                         },
//                                       ),
//                                       const SizedBox(width: 20),
//                                       circleButton(
//                                         Icons.flash_on,
//                                         40,
//                                         gradient: LinearGradient(
//                                           colors: [
//                                             Colors.deepPurple,
//                                             Colors.purple,
//                                           ],
//                                         ),
//                                         onTap: () {
//                                           final audioUrl = word.audio;
//                                           if (audioUrl.isNotEmpty) {
//                                             playWordAudio(
//                                               index: 0,
//                                               audioUrl: audioUrl,
//                                               speed: 1.5,
//                                             );
//                                           }
//                                         },
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 5),
//                                   Text(
//                                     word.phonetic,
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       color: Colors.deepPurple,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 10),
//                                   Container(
//                                     width: double.infinity,
//                                     padding: const EdgeInsets.all(8),
//                                     decoration: BoxDecoration(
//                                       color: Colors.blue.shade50,
//                                       borderRadius: BorderRadius.circular(20),
//                                     ),
//                                     child: Column(
//                                       children: [
//                                         const Text(
//                                           "WORD BUDDIES",
//                                           style: TextStyle(
//                                             color: Colors.blue,
//                                             fontWeight: FontWeight.bold,
//                                             fontSize: 12,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 5),
//                                         Text(
//                                           word.displaySynonym.isNotEmpty
//                                               ? word.displaySynonym
//                                               : "-",
//                                           style: TextStyle(
//                                             fontSize: 14,
//                                             color: Colors.deepPurple,
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           }),
//                           const SizedBox(height: 10),

//                           if (controller.isListening.value)
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.6,
//                               child: WaveVisualizer(
//                                 isRecording: true, // true or false
//                                 amplitude: 1.0, // 0.0 to 1.0
//                                 color: Colors
//                                     .blueAccent, // optional: defaults to Theme.primaryColor
//                                 height: 30.0, // optional
//                               ),
//                             ),
//                           (controller.isListening.value)
//                               ? const SizedBox(height: 4)
//                               : const SizedBox(height: 20),

//                           micWidget(),
//                           const Spacer(),
//                           bottomBar(gameController),
//                           const SizedBox(height: 20),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//       ),
//     );
//   }

//   Widget circleButton(
//     IconData icon,
//     double size, {
//     VoidCallback? onTap,
//     Gradient? gradient,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         width: size,
//         height: size,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           gradient:
//               gradient ?? LinearGradient(colors: [Colors.cyan, Colors.blue]),
//         ),
//         child: Icon(icon, color: Colors.white),
//       ),
//     );
//   }

//   Widget micWidget() {
//     return Column(
//       children: [
//         GestureDetector(
//           onTap: () {
//             print("Tap Down");
//             final word = randomWord.value;
//             controller.targetWord.value = word?.meaning ?? "";
//             controller.startListening(gameController.keyCode ?? "en_US");
//             startListeningAnimation();
//           },

//           child: AnimatedBuilder(
//             animation: Listenable.merge([micController, pulseController]),
//             builder: (_, _) {
//               double pulse = controller.isListening.isTrue
//                   ? 1 + pulseController.value * .15
//                   : 1;

//               return Transform.scale(
//                 scale: micController.value,
//                 child: Container(
//                   width: 70 * pulse,
//                   height: 70 * pulse,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     boxShadow: controller.isListening.isTrue
//                         ? [
//                             BoxShadow(
//                               color: Colors.blue.withValues(alpha: .5),
//                               blurRadius: 35,
//                               spreadRadius: 10,
//                             ),
//                           ]
//                         : [],
//                     gradient: const LinearGradient(
//                       colors: [Color(0xff57D7FF), Color(0xff005DFF)],
//                     ),
//                   ),
//                   child: Container(
//                     margin: const EdgeInsets.all(8),
//                     decoration: const BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.white,
//                     ),
//                     child: const Icon(Icons.mic, size: 40, color: Colors.blue),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),

//         const SizedBox(height: 10),
//         Text(
//           "Tap to Speak",
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 12,
//             shadows: [
//               Shadow(color: Colors.blue, blurRadius: 2, offset: Offset(0, 1)),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget levelBar() {
//     return
//     /// LEVEL BAR
//     Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: Row(
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: const BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white,
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Text(
//                   "12",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.blue,
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     shadows: [
//                       Shadow(
//                         color: AppColor.blackColor,
//                         blurRadius: 2,
//                         offset: Offset(0, 1),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Text(
//                   "LEVEL",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.blue,
//                     fontSize: 8,
//                     fontWeight: FontWeight.bold,
//                     shadows: [
//                       Shadow(
//                         color: AppColor.blackColor,
//                         blurRadius: 1,
//                         offset: Offset(0, 1),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: CustomProgressBar(
//               currentPoints: 60,
//               milestones: const [1, 2, 3],
//               labels: ["1", "2", "3"],
//               completedIcon: Image.asset(Assets.coin, width: 24, height: 24),
//               pendingIcon: Image.asset(Assets.coin, width: 24, height: 24),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Text(
//             "12/20",
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//               shadows: [
//                 Shadow(
//                   color: AppColor.blackColor,
//                   blurRadius: 1,
//                   offset: Offset(0, 1),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget bottomBar(GameController controller) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: SizedBox(
//         height: 60,
//         child: Stack(
//           alignment: Alignment.center,
//           children: [
//             // Left and Right Buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     loadRandomWord();
//                   },
//                   child: Container(
//                     width: 90,
//                     height: 60,
//                     decoration: BoxDecoration(
//                       image: DecorationImage(
//                         image: AssetImage(Assets.plantGreenButton),
//                         fit: BoxFit.fill,
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(
//                           Icons.fast_forward,
//                           color: Colors.white,
//                           size: 20,
//                         ),
//                         Text(
//                           "Skip",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 12,
//                             shadows: [
//                               Shadow(
//                                 color: AppColor.blackColor,
//                                 blurRadius: 1,
//                                 offset: Offset(0, 1),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 circleIconWidget(
//                   Icons.emoji_objects_outlined,
//                   size: 50,
//                   color: Colors.yellow.shade700,
//                   iconColor: Colors.white,
//                   onTap: () {},
//                 ),
//               ],
//             ),

//             // Center Home Button
//             circleIconWidget(
//               Icons.home,
//               size: 50,
//               color: Colors.blue.shade700,
//               iconColor: Colors.white,
//               onTap: () {
//                 Get.back();
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
