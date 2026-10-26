import 'package:get/get.dart';

import '../controllers/bubble_controller.dart';

/// GetX binding registering the bubble presentation controller.
class BubbleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BubbleController>(() => BubbleController());
  }
}
