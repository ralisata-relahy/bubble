// import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_recognition_result.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:string_similarity/string_similarity.dart';

// class SpeechTestApp extends StatelessWidget {
//   const SpeechTestApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: SpeechTestPage(),
//     );
//   }
// }

// class SpeechTestPage extends StatefulWidget {
//   const SpeechTestPage({super.key});

//   @override
//   State<SpeechTestPage> createState() => _SpeechTestPageState();
// }

// class _SpeechTestPageState extends State<SpeechTestPage> {
//   /// Reponse attendue (a comparer avec ce que l'utilisateur dit ou tape).
//   static const String _expected = 'hello';

//   /// Score minimum (0.0 a 1.0) pour considerer la reponse comme bonne.
//   static const double _threshold = 0.7;

//   final SpeechToText _speech = SpeechToText();
//   final TextEditingController _typedController = TextEditingController();

//   bool _speechEnabled = false;
//   String? _localeId;
//   String _words = '';
//   double _score = 0;

//   @override
//   void initState() {
//     super.initState();
//     _initSpeech();
//   }

//   @override
//   void dispose() {
//     _speech.cancel();
//     _typedController.dispose();
//     super.dispose();
//   }

//   /// A appeler une seule fois : demande les permissions et prepare le moteur.
//   Future<void> _initSpeech() async {
//     final enabled = await _speech.initialize(
//       onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
//       onStatus: (status) {
//         debugPrint('Speech status: $status');
//         if (mounted) setState(() {});
//       },
//     );

//     // Cherche une locale francaise, sinon laisse la locale par defaut.
//     String? frLocale;
//     if (enabled) {
//       final locales = await _speech.locales();
//       for (final l in locales) {
//         if (l.localeId.toLowerCase().startsWith('en')) {
//           frLocale = l.localeId;
//           break;
//         }
//       }
//     }

//     if (!mounted) return;
//     setState(() {
//       _speechEnabled = enabled;
//       _localeId = frLocale;
//     });
//   }

//   Future<void> _startListening() async {
//     setState(() {
//       _words = '';
//       _score = 0;
//     });
//     await _speech.listen(
//       onResult: _onSpeechResult,
//       localeId: _localeId,
//       listenFor: const Duration(seconds: 10),
//       pauseFor: const Duration(seconds: 3),
//     );
//     if (mounted) setState(() {});
//   }

//   Future<void> _stopListening() async {
//     await _speech.stop();
//     if (mounted) setState(() {});
//   }

//   void _onSpeechResult(SpeechRecognitionResult result) {
//     setState(() {
//       _words = result.recognizedWords;
//       _score = _bestScore(_words);
//     });
//   }

//   /// Minuscules, sans accents ni ponctuation, pour une comparaison equitable.
//   String _normalize(String input) {
//     const from = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿ';
//     const to = 'aaaaaceeeeiiiinooooouuuuyy';
//     var s = input.toLowerCase().trim();
//     for (var i = 0; i < from.length; i++) {
//       s = s.replaceAll(from[i], to[i]);
//     }
//     return s.replaceAll(RegExp(r'[^a-z0-9\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
//   }

//   /// Compare la reponse attendue a la phrase entiere ET a chaque mot,
//   /// et garde le meilleur score (ex: "euh bonjour" doit quand meme passer).
//   double _bestScore(String spoken) {
//     final expected = _normalize(_expected);
//     final cleaned = _normalize(spoken);
//     if (cleaned.isEmpty) return 0;

//     final candidates = <String>[cleaned, ...cleaned.split(' ')];
//     var best = 0.0;
//     for (final c in candidates) {
//       final score = expected.similarityTo(c);
//       if (score > best) best = score;
//     }
//     return best;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final passed = _score >= _threshold;
//     final listening = _speech.isListening;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Speech + similarity test')),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const Text(
//               "What does 'hello' mean in French?",
//               textAlign: TextAlign.center,
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Expected: "$_expected"   |   Locale: ${_localeId ?? 'default'}',
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.grey),
//             ),
//             const SizedBox(height: 24),

//             // Texte reconnu
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey.shade400),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 _words.isNotEmpty
//                     ? _words
//                     : listening
//                         ? 'Listening...'
//                         : _speechEnabled
//                             ? 'Tap the microphone and say your answer'
//                             : 'Speech not available (check permissions)',
//                 style: const TextStyle(fontSize: 18),
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Score
//             Text(
//               'Similarity: ${(_score * 100).toStringAsFixed(0)}%',
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//             ),
//             const SizedBox(height: 8),
//             LinearProgressIndicator(
//               value: _score,
//               minHeight: 12,
//               borderRadius: BorderRadius.circular(6),
//               color: passed ? Colors.green : Colors.orange,
//               backgroundColor: Colors.grey.shade300,
//             ),
//             const SizedBox(height: 12),
//             if (_words.isNotEmpty)
//               Text(
//                 passed ? 'Correct!' : 'Try again',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                   color: passed ? Colors.green : Colors.red,
//                 ),
//               ),

//             const Spacer(),

//             // Test de string_similarity seul, sans micro
//             TextField(
//               controller: _typedController,
//               decoration: const InputDecoration(
//                 labelText: 'Or type an answer to test similarity only',
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: (value) => setState(() {
//                 _words = value;
//                 _score = _bestScore(value);
//               }),
//             ),
//             const SizedBox(height: 80),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: !_speechEnabled
//             ? null
//             : (_speech.isNotListening ? _startListening : _stopListening),
//         tooltip: 'Listen',
//         child: Icon(_speech.isNotListening ? Icons.mic_off : Icons.mic),
//       ),
//     );
//   }
// }