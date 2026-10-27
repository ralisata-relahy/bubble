import 'package:get/get.dart';

import '../controllers/smarty_controller.dart';

/// GetX binding registering the AI Buddy controller.
class SmartyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SmartyController>(() => SmartyController());
  }
}
