// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:lingo_learner/screens/games/controller/game_controller.dart';
// import 'package:lingo_learner/screens/games/speak_word_screen/widget/pronunciation_result_dialog_widget.dart';
// import 'package:speech_to_text/speech_recognition_result.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:string_similarity/string_similarity.dart';

// class SpeakWordController extends GetxController {
//   final SpeechToText speechToText = SpeechToText();
//   RxBool speechEnabled = false.obs;
//   RxString recognizedText = ''.obs;
//   RxBool isListening = false.obs;

//   RxString confidenceValue = ''.obs;
//   RxString targetWord = ''.obs;
//   final GameController gameController = Get.find<GameController>();
//   VoidCallback? onWordCompleted;

//   @override
//   void onInit() {
//     super.onInit();
//     print("SpeakWordController initialized");
//     initSpeech();
//   }

//   // Speech to Text
//   Future<void> initSpeech() async {
//     speechEnabled.value = await speechToText.initialize(
//       onStatus: (status) {
//         debugPrint("Status: $status");

//         if (status == 'listening') {
//           isListening.value = true;
//         } else if (status == 'notListening') {
//           isListening.value = false;
//         } else if (status == 'done') {
//           isListening.value = false;
//         }
//       },
//       onError: (error) {
//         debugPrint("Error: ${error.errorMsg}");
//         isListening.value = false;

//         showDialog(
//           context: Get.context!,
//           barrierDismissible: false,
//           builder: (_) {
//             return AlertDialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     "Error",
//                     style: const TextStyle(
//                       fontSize: 30,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),

//                   const SizedBox(height: 25),
//                   Text(
//                     "Error: ${error.errorMsg}",
//                     style: const TextStyle(fontSize: 14),
//                   ),

//                   const SizedBox(height: 30),

//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       ElevatedButton(
//                         onPressed: () {
//                           Get.back();
//                           startListening(gameController.keyCode ?? "en_US");
//                         },
//                         child: const Text("Retry"),
//                       ),
//                       ElevatedButton(
//                         onPressed: () {
//                           Get.back();
//                         },
//                         child: const Text("Cancel"),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Future<void> startListening(String localeId) async {
//     if (!speechEnabled.value) {
//       debugPrint("Speech not initialized");
//       return;
//     }

//     if (speechToText.isListening) return;

//     await speechToText.listen(
//       onResult: onSpeechResult,
//       listenOptions: SpeechListenOptions(
//         localeId: localeId,
//         listenMode: ListenMode.confirmation,
//         partialResults: true,
//         cancelOnError: true,
//         listenFor: const Duration(seconds: 30),
//         pauseFor: const Duration(seconds: 3),
//       ),
//     );

//     isListening.value = true;
//   }

//   Future<void> stopListening() async {
//     await speechToText.stop();
//     isListening.value = false;
//   }

//   void onSpeechResult(SpeechRecognitionResult result) {
//     recognizedText.value = result.recognizedWords;

//     debugPrint("Words: ${result.recognizedWords}");
//     debugPrint("Final Result: ${result.finalResult}");
//     if (result.finalResult) {
//       matchword(targetWord.value, recognizedText);
//     }
//   }

//   // Match Word
//   void matchword(String expectedWord, RxString recognizedText) async {
//     var result = '';
//     String spokenWord = recognizedText.value.trim();
//     expectedWord = expectedWord.trim();
//     print("Spoken Word: $spokenWord");
//     print("Expected Word: $expectedWord");

//     double similarity = StringSimilarity.compareTwoStrings(
//       spokenWord.toLowerCase(),
//       expectedWord.toLowerCase(),
//     );

//     print(similarity);

//     if (similarity > 0.90) {
//       print("🌟 Flawless!");
//       result = "🌟 Flawless!";
//     } else if (similarity > 0.80) {
//       print("🎯 So Close!");
//       result = "🎯 So Close!";
//     } else if (similarity > 0.60) {
//       print("🚀 Almost There!");
//       result = "🚀 Almost There!";
//     } else {
//       print("🔁 Give It Another Shot!");
//       result = "🔁 Give It Another Shot!";
//     }
//     List<bool> matches = compareCharacters(expectedWord, spokenWord);
//     showDialog(
//       context: Get.context!,
//       barrierDismissible: false,
//       builder: (_) {
//         return PronunciationResultDialogWidget(
//           result: result,
//           spokenWord: spokenWord,
//           matches: matches,
//           similarity: similarity,
//           onOk: () => Get.back(),
//           onNext: () {
//             Get.back();
//             onWordCompleted?.call();
//           },
//         );
//       },
//     );
//   }

//   List<bool> compareCharacters(String expected, String spoken) {
//     expected = expected.toLowerCase();
//     spoken = spoken.toLowerCase();

//     List<bool> result = [];

//     int maxLength = spoken.length;

//     for (int i = 0; i < maxLength; i++) {
//       if (i < expected.length && expected[i] == spoken[i]) {
//         result.add(true);
//       } else {
//         result.add(false);
//       }
//     }

//     return result;
//   }

//   Widget buildComparison(String spoken, List<bool> matches) {
//     return RichText(
//       text: TextSpan(
//         children: List.generate(spoken.length, (index) {
//           return TextSpan(
//             text: spoken[index],
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: matches[index] ? Colors.green : Colors.red,
//             ),
//           );
//         }),
//       ),
//     );
//   }
// }
