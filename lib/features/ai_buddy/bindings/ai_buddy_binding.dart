import 'package:get/get.dart';

import '../controllers/ai_buddy_controller.dart';

/// GetX binding registering the AI Buddy controller.
class AiBuddyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AiBuddyController>(() => AiBuddyController());
  }
}
