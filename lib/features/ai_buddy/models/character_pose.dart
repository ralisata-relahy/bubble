import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EdutainerEmotion {
  normal(speed: 1.0),
  angry(speed: 1.5),
  love(speed: 0.5),
  sad(speed: 0.6);

  const EdutainerEmotion({required this.speed});
  final double speed;
}

@immutable
class EdutainerPose {
  const EdutainerPose({
    this.time = 0,
    this.bob = 0,
    this.squash = 0,
    this.tilt = 0,
    this.waveArm = 0,
    this.downArm = 0,
    this.stepLeft = 0.8,
    this.stepRight = 0,
    this.look = Offset.zero,
    this.blink = 0,
    this.mouthOpen = 0.6,
    this.tongueOut = 0.6,
    this.symbolSet = 0,
    this.laser = 1,
    this.mischief = 1,
    this.heart = 0, // 0..1 iris turns into a heart
    this.sadness = 0, // 0..1 droopy lid, big pupil, frown
    this.targets = const [],
    this.labels = const [],
  });

  final double time, bob, squash, tilt, waveArm, downArm;
  final double stepLeft, stepRight, blink, mouthOpen, tongueOut;
  final double laser, mischief, heart, sadness;
  final Offset look;
  final int symbolSet;
  final List<Offset> targets;
  final List<String> labels;

  EdutainerPose copyWith({
    double? time,
    double? bob,
    double? squash,
    double? tilt,
    double? waveArm,
    double? downArm,
    double? stepLeft,
    double? stepRight,
    Offset? look,
    double? blink,
    double? mouthOpen,
    double? tongueOut,
    int? symbolSet,
    double? laser,
    double? mischief,
    double? heart,
    double? sadness,
    List<Offset>? targets,
    List<String>? labels,
  }) => EdutainerPose(
    time: time ?? this.time,
    bob: bob ?? this.bob,
    squash: squash ?? this.squash,
    tilt: tilt ?? this.tilt,
    waveArm: waveArm ?? this.waveArm,
    downArm: downArm ?? this.downArm,
    stepLeft: stepLeft ?? this.stepLeft,
    stepRight: stepRight ?? this.stepRight,
    look: look ?? this.look,
    blink: blink ?? this.blink,
    mouthOpen: mouthOpen ?? this.mouthOpen,
    tongueOut: tongueOut ?? this.tongueOut,
    symbolSet: symbolSet ?? this.symbolSet,
    laser: laser ?? this.laser,
    mischief: mischief ?? this.mischief,
    heart: heart ?? this.heart,
    sadness: sadness ?? this.sadness,
    targets: targets ?? this.targets,
    labels: labels ?? this.labels,
  );

  /// Overrides the face fields according to [e].
  EdutainerPose withEmotion(EdutainerEmotion e) {
    switch (e) {
      case EdutainerEmotion.normal:
        return copyWith(mischief: 0, heart: 0, sadness: 0); // calm: no V, no mark
      case EdutainerEmotion.angry:
        return copyWith(mischief: 1, heart: 0, sadness: 0);
      case EdutainerEmotion.love:
        return copyWith(mischief: 0, heart: 1, sadness: 0);
      case EdutainerEmotion.sad:
        return copyWith(
          mischief: 0,
          heart: 0,
          sadness: 1,
          look: const Offset(0, 0.6),
          mouthOpen: 0,
          tongueOut: 0,
        );
    }
  }

  factory EdutainerPose.idle(
    double t, {
    List<Offset> targets = const [],
    List<String> labels = const [],
  }) {
    final bounce = math.sin(t * 5).abs();
    final ph = t % 3.4;
    final blink = ph > 3.2 ? math.sin((ph - 3.2) / 0.2 * math.pi) : 0.0;
    var look = Offset.zero;
    if (targets.isNotEmpty) {
      final tg = targets[(t / 2.2).floor() % targets.length];
      final d = tg - const Offset(205, 272);
      if (d.distance > 0) look = d / d.distance;
    }
    return EdutainerPose(
      time: t,
      bob: bounce,
      squash: 0.5 - bounce,
      tilt: math.sin(t * 2.5) * 0.05,
      waveArm: math.sin(t * 6),
      downArm: math.sin(t * 5 + math.pi) * 0.7,
      stepLeft: 0.75 + 0.25 * math.sin(t * 5 + 1),
      stepRight: 0,
      look: look,
      blink: blink,
      mouthOpen: 0.65 + 0.15 * math.sin(t * 3),
      tongueOut: 0.5 + 0.5 * math.sin(t * 1.7),
      symbolSet: (t / 1.8).floor(),
      laser: 1,
      mischief: 1,
      targets: targets,
      labels: labels,
    );
  }
}