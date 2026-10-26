import 'package:get/get.dart';

import '../controllers/game_controller.dart';

/// Registers the session-scoped game controller for the app route.
class GameBinding extends Bindings {
  GameBinding(this.controller);

  final GameController controller;

  @override
  void dependencies() {
    Get.put<GameController>(controller);
  }
}
