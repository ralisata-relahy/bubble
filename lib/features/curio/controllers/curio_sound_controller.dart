import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CurioSoundController extends GetxController {
  final AudioPlayer _player = AudioPlayer();
  final RxString soundAsset = ''.obs;

  @override
  void onInit() {
    super.onInit();
    ever(soundAsset, (value) {
      if (value.isNotEmpty) play();
    });
  }

  Future<void> play([String? asset]) async {
  final target = asset ?? soundAsset.value;
  debugPrint('Playing: $target');
  if (target.isEmpty) return;
  try {
    await _player.stop();
    await _player.play(AssetSource(target));
  } catch (e) {
    debugPrint('Audio error: $e');
  }
}

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }
}
