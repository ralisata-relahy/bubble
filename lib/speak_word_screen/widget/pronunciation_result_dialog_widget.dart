// import 'dart:math';
// import 'dart:ui';
// import 'package:auto_size_text/auto_size_text.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:lingo_learner/res/assets/assets.dart';
// import 'package:lingo_learner/res/colors/app_color.dart';
// import 'package:lingo_learner/res/components/custom_button.dart';
// import 'package:responsive_sizer/responsive_sizer.dart';

// class PronunciationResultDialogWidget extends StatefulWidget {
//   final String result;
//   final double similarity;
//   final String spokenWord;
//   final List<bool> matches;
//   final VoidCallback onOk;
//   final VoidCallback onNext;
//   const PronunciationResultDialogWidget({
//     super.key,
//     required this.result,
//     required this.spokenWord,
//     required this.matches,
//     required this.similarity,
//     required this.onOk,
//     required this.onNext,
//   });

//   @override
//   State<PronunciationResultDialogWidget> createState() =>
//       _PronunciationResultDialogWidgetState();
// }

// class _PronunciationResultDialogWidgetState
//     extends State<PronunciationResultDialogWidget>
//     with TickerProviderStateMixin {
//   final moods = [
//     Assets.eyeHappy,
//     Assets.eyeVeryHappy,
//     Assets.eyeAngry,
//     Assets.eyeSad,
//     Assets.eyeSus,
//   ];

//   int currentMood = 0;

//   late AnimationController blinkController;

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();

//     blinkController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 120),
//     );

//     autoBlink();
//   }

//   @override
//   void dispose() {
//     // TODO: implement dispose
//     super.dispose();
//     blinkController.dispose();
//   }

//   // Future<void> autoBlink() async {
//   //   while (mounted) {
//   //     await Future.delayed(
//   //       Duration(milliseconds: 2000 + Random().nextInt(3000)),
//   //     );

//   //     await blinkController.forward();
//   //     await blinkController.reverse();
//   //   }
//   // }

//   Future<void> autoBlink() async {
//     while (mounted) {
//       await Future.delayed(
//         Duration(milliseconds: 2000 + Random().nextInt(3000)),
//       );

//       if (!mounted) return;

//       await blinkController.forward();

//       if (!mounted) return;

//       await blinkController.reverse();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: Colors.transparent,
//       child: Container(
//         width: 100.w,
//         // height: 40.h,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(25),
//           gradient: const LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [Color(0xff1ED6FF), Color(0xff00A8E8), Color(0xff35CFFF)],
//           ),
//           border: Border.all(color: Colors.white.withOpacity(.6), width: 3),
//           boxShadow: [
//             BoxShadow(color: Colors.black, blurRadius: 5, spreadRadius: 3),
//           ],
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             /// Bubble Effect
//             // ..._bubbles(),
//             Stack(
//               children: [
//                 Column(
//                   children: [
//                     // const SizedBox(height: 25),

//                     /// Top Score Section
//                     Padding(
//                       padding: EdgeInsets.symmetric(
//                         horizontal: Adaptive.w(4),
//                         vertical: Adaptive.h(2),
//                       ),
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           /// Circular Score
//                           Stack(
//                             alignment: Alignment.center,
//                             children: [
//                               SizedBox(
//                                 height: 21.w,
//                                 width: 21.w,
//                                 child: CircularProgressIndicator(
//                                   value: widget.similarity,
//                                   strokeWidth: Adaptive.w(2),
//                                   backgroundColor: Colors.white24,
//                                   valueColor: AlwaysStoppedAnimation(
//                                     getColor(),
//                                   ),
//                                 ),
//                               ),
//                               Column(
//                                 mainAxisSize: MainAxisSize.min,
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     "${(widget.similarity * 100).toInt()}%",
//                                     style: TextStyle(
//                                       fontSize: 18.sp,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                   Text(
//                                     "SCORE",
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 14.sp,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),

//                           SizedBox(
//                             width: 45.w,
//                             height: 14.h,
//                             child: Stack(
//                               alignment: Alignment.topRight,
//                               children: [
//                                 Positioned(
//                                   top: Adaptive.h(2.5),
//                                   right: 10,
//                                   child: Container(
//                                     width: 42.w,
//                                     height: 11.h,
//                                     // margin: EdgeInsets.only(left: Adaptive.w(5)),
//                                     padding: EdgeInsets.all(Adaptive.w(2)),
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(10),
//                                       color: Colors.black26,
//                                       border: Border.all(color: Colors.white24),
//                                     ),
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         AutoSizeText(
//                                           widget.result,
//                                           style: TextStyle(
//                                             color: Color(0xffFFD21F),
//                                             fontSize: 15.sp,
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                           maxLines: 2,
//                                         ),

//                                         // SizedBox(height: 10),
//                                         AutoSizeText(
//                                           getcotent((widget.similarity * 100)),
//                                           style: TextStyle(
//                                             color: Colors.white,
//                                             fontSize: 14.sp,
//                                           ),
//                                           maxLines: 2,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 CircleAvatar(
//                                   radius: Adaptive.w(5),
//                                   backgroundColor: Colors.white24,
//                                   child: Text(
//                                     "🎯",
//                                     style: TextStyle(fontSize: 20.sp),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     /// Word Card
//                     Container(
//                       width: 90.w,
//                       // height: 14.h,
//                       margin: EdgeInsets.symmetric(
//                         horizontal: Adaptive.w(4),
//                         // vertical: Adaptive.h(2),
//                       ),
//                       padding: EdgeInsets.symmetric(
//                         horizontal: Adaptive.w(4),
//                         vertical: Adaptive.h(2),
//                       ),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(Adaptive.w(2)),
//                         color: Colors.white.withOpacity(.63),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.white.withOpacity(.5),
//                             blurRadius: 20,
//                           ),
//                         ],
//                       ),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           buildComparison(widget.spokenWord, widget.matches),

//                           // Row(
//                           //   mainAxisAlignment: MainAxisAlignment.center,
//                           //   children: List.generate(
//                           //     matches.length,
//                           //     (index) => Container(
//                           //       width: Adaptive.w(2),
//                           //       height: Adaptive.w(1),
//                           //       margin: const EdgeInsets.symmetric(horizontal: 4),
//                           //       decoration: BoxDecoration(
//                           //         borderRadius: BorderRadius.circular(3),
//                           //         color: matches[index] ? Colors.green : Colors.red,
//                           //       ),
//                           //     ),
//                           //   ),
//                           // ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 Positioned(
//                   bottom: 12.w,
//                   child: Image(
//                     image: AssetImage(Assets.buddyCatBase),
//                     width: Adaptive.w(15),
//                     height: Adaptive.w(15),
//                   ),
//                 ),
//                 Positioned(
//                   left: 3.8.w,
//                   bottom: 17.2.w,
//                   child: AnimatedBuilder(
//                     animation: Listenable.merge([blinkController]),
//                     builder: (_, __) {
//                       final blinkScale = 1 - (blinkController.value * 0.95);

//                       return Transform.scale(
//                         scaleY: blinkScale,
//                         child: AnimatedSwitcher(
//                           duration: const Duration(milliseconds: 400),
//                           transitionBuilder: (child, animation) {
//                             return FadeTransition(
//                               opacity: animation,
//                               child: ScaleTransition(
//                                 scale: animation,
//                                 child: child,
//                               ),
//                             );
//                           },
//                           // child: Image.asset(
//                           //   moods[currentMood],
//                           //   key: ValueKey(moods[currentMood]),
//                           //   width: 170,
//                           // ),
//                           child: Image(
//                             image: AssetImage(getMood()),
//                             key: ValueKey(getMood()),
//                             width: Adaptive.w(7),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//             // SizedBox(height: Adaptive.h(3)),

//             /// Buttons
//             Padding(
//               padding: EdgeInsets.all(Adaptive.w(4)),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   Expanded(
//                     child: CustomButton(
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: Adaptive.h(1.2),
//                       ),
//                       buttonText: "OK",
//                       onTap: widget.onOk,
//                       gradienColor: AppColor.authButtonGradient,
//                     ),
//                   ),
//                   SizedBox(width: Adaptive.w(4)),
//                   Expanded(
//                     child: CustomButton(
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: Adaptive.h(1.2),
//                       ),
//                       buttonText: "Next",
//                       onTap: widget.onNext,
//                       gradienColor: AppColor.aiButtonGradient2,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             // SizedBox(height: Adaptive.h(3)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildComparison(String spoken, List<bool> matches) {
//     return RichText(
//       text: TextSpan(
//         children: List.generate(spoken.length, (index) {
//           return TextSpan(
//             text: spoken[index],
//             style: TextStyle(
//               color: matches[index] ? Colors.green : getColor(),
//               fontSize: 22.sp,
//               fontWeight: FontWeight.bold,
//             ),
//           );
//         }),
//       ),
//     );
//   }

//   String getcotent(double similarity) {
//     if (similarity >= 90.0) {
//       return "Perfect pronunciation";
//     } else if ((similarity >= 80.0) && (similarity < 90.0)) {
//       return "A few sounds need improvement";
//     } else if ((similarity >= 60.0) && (similarity < 80.0)) {
//       return "You're getting better!";
//     } else if (similarity < 60.0) {
//       return "Practice makes perfect!";
//     } else {
//       return "Something went wrong";
//     }
//   }

//   Color getColor() {
//     if (widget.similarity > 0.90) {
//       return const Color.fromARGB(255, 96, 250, 0);
//     } else if (widget.similarity > 0.80) {
//       return Colors.orange;
//     } else if (widget.similarity > 0.60) {
//       return Colors.red;
//     } else {
//       return Colors.red;
//     }
//   }

//   String getMood() {
//     if (widget.similarity > 0.90) {
//       return Assets.eyeVeryHappy;
//     } else if (widget.similarity > 0.80) {
//       return Assets.eyeHappy;
//     } else if (widget.similarity > 0.60) {
//       return Assets.eyeSad;
//     } else {
//       return Assets.eyeSad;
//     }
//   }
// }
