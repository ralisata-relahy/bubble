import 'package:get/get.dart';

import '../controllers/curio_controller.dart';
import '../services/curio_audio_service.dart';

/// GetX binding registering the Curio controller and voice service.
class CurioBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CurioAudioService>(() => CurioAudioService());
    Get.lazyPut<CurioController>(
      () => CurioController(audioService: Get.find<CurioAudioService>()),
    );
  }
}
