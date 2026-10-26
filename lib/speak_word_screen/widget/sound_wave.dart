import 'dart:math';

import 'package:flutter/material.dart';

class SoundWave extends AnimatedWidget {
  const SoundWave({super.key, required Animation animation})
    : super(listenable: animation);

  Animation get animation => listenable as Animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (index) {
          double h = 20 + 30 * sin(animation.value * pi * 2 + index);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: h.abs(),
            decoration: BoxDecoration(
              color: index.isEven ? Colors.cyan : Colors.purple,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }),
      ),
    );
  }
}
