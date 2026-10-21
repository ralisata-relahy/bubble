// import 'package:flutter/material.dart';

// /// Résultat de la partie affiché au-dessus du jeu en pause.
// class GameResultOverlay extends StatelessWidget {
//   /// Affiche le bon état et appelle [onRestart] à la demande du joueur.
//   const GameResultOverlay({
//     required this.didWin,
//     required this.onRestart,
//     super.key,
//   });

//   /// Indique si la bonne réponse a été trouvée avant la fin du compte à rebours.
//   final bool didWin;

//   /// Redémarre la partie après le toucher du bouton.
//   final VoidCallback onRestart;

//   @override
//   Widget build(BuildContext context) => ColoredBox(
//     color: const Color(0x99000000),
//     child: Center(
//       child: Card(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 didWin ? 'Victoire !' : 'Game over',
//                 style: Theme.of(context).textTheme.headlineMedium,
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 didWin
//                     ? 'Tu as trouvé la bonne bulle à temps.'
//                     : 'Le temps est écoulé.',
//               ),
//               const SizedBox(height: 20),
//               FilledButton(
//                 onPressed: onRestart,
//                 child: const Text('Rejouer'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     ),
//   );
// }
