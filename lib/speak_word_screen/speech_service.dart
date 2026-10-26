// // import 'package:flutter/foundation.dart';
// // import 'package:lingo_learner/screens/games/speak_word_screen/controller/speak_word_controller.dart';
// // import 'package:speech_to_text/speech_to_text.dart';

// // class SpeechService {
// //   SpeechService(this.controller);
// //   final SpeakWordController controller;

// //   final SpeechToText speech = SpeechToText();

// //   String recognizedText = "";

// //   Future<void> startListening(String keyCode) async {
// //     bool available = await speech.initialize(
// //       onStatus: (status) {
// //         if (kDebugMode) {
// //           print("Status: $status");
// //         }
// //       },
// //       onError: (error) {
// //         if (kDebugMode) {
// //           print("Error: ${error.errorMsg}");
// //         }
// //       },
// //     );

// //     if (kDebugMode) {
// //       print("Available: $available");
// //     }

// //     if (!available) return;

// //     // speech.listen(
// //     //   localeId: keyCode,

// //     //   partialResults: true,

// //     //   onResult: (result) {
// //     //     recognizedText = result.recognizedWords;
// //     //   },
// //     // );
// //     await speech.listen(
// //       listenOptions: SpeechListenOptions(
// //         localeId: keyCode,
// //         listenMode: ListenMode.confirmation,
// //         partialResults: true,
// //         cancelOnError: true,
// //         listenFor: const Duration(seconds: 5),
// //         pauseFor: const Duration(seconds: 2),
// //       ),

// //       onResult: (result) {
// //         recognizedText = result.recognizedWords;
// //         controller.recognizedText.value = recognizedText;
// //         controller.confidenceValue.value = result.confidence.toStringAsFixed(2);
// //         print(result.recognizedWords);
// //         print(result.confidence);
// //       },
// //     );
// //   }

// //   // Future<String> stopListening() async {
// //   //   await speech.stop();

// //   //   return recognizedText;
// //   // }
// //   Future<String> stopListening() async {
// //     await speech.stop();

// //     // Wait for final callback
// //     await Future.delayed(const Duration(milliseconds: 400));

// //     controller.recognizedText.value = recognizedText;

// //     return recognizedText;
// //   }
// // }

// import 'dart:async';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:lingo_learner/screens/games/speak_word_screen/controller/speak_word_controller.dart';
// import 'package:speech_to_text/speech_to_text.dart';

// class SpeechService {
//   SpeechService(this.controller);

//   final SpeakWordController controller;
//   final SpeechToText speech = SpeechToText();

//   String recognizedText = "";
//   bool speechEnabled = false;

//   /// Initialize speech recognition once.
//   Future<void> initSpeech() async {
//     speechEnabled = await speech.initialize(
//       onStatus: (status) {
//         debugPrint("Status: $status");
//       },
//       onError: (error) {
//         debugPrint("Error: ${error.errorMsg}");
//       },
//     );

//     setState(() {});
//   }

//   Future<void> startListening(String localeId) async {
//     recognizedText = "";
//     _speechCompleter = Completer<String>();

//     bool available = await speech.initialize(
//       onStatus: (status) {
//         if (kDebugMode) {
//           print("Status : $status");
//         }
//       },
//       onError: (error) {
//         if (kDebugMode) {
//           print("Error : ${error.errorMsg}");
//         }

//         if (!(_speechCompleter?.isCompleted ?? true)) {
//           _speechCompleter?.complete("");
//         }
//       },
//     );

//     if (!available) {
//       await speech.listen(
//         listenOptions: SpeechListenOptions(
//           localeId: localeId,
//           partialResults: true,
//           listenMode: ListenMode.deviceDefault,
//           // cancelOnError: true,
//           // listenFor: const Duration(seconds: 10),
//           // pauseFor: const Duration(seconds: 4),
//         ),
//         onResult: (result) {
//           print("Result : ${result.recognizedWords}");
//           recognizedText = result.recognizedWords;

//           controller.recognizedText.value = recognizedText;
//           controller.confidenceValue.value = result.confidence.toStringAsFixed(
//             2,
//           );

//           // controller.matchword(controller.targetWord.value, recognizedText);

//           debugPrint("Word : ${result.recognizedWords}");
//           debugPrint("Final : ${result.finalResult}");

//           if (result.finalResult && !(_speechCompleter?.isCompleted ?? true)) {
//             _speechCompleter!.complete(recognizedText);
//           }
//           stopListening();
//         },
//       );
//     }
//   }

//   Future<String> stopListening() async {
//     await speech.stop();

//     // if (_speechCompleter == null) {
//     // }
//     controller.matchword(controller.targetWord.value, recognizedText);
//     return recognizedText;
//     // var asd = await _speechCompleter!.future;
//     // print("stopListening result : $asd");

//     // return await _speechCompleter!.future;
//   }
// }

// class CheckingPronunciationDialog extends StatelessWidget {
//   const CheckingPronunciationDialog({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: const [
//           SizedBox(
//             width: 55,
//             height: 55,
//             child: CircularProgressIndicator(strokeWidth: 4),
//           ),
//           SizedBox(height: 20),
//           Text(
//             "Checking pronunciation...",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }
// }
