import 'package:get/get.dart';

import '../controllers/game_controller.dart';

/// GetX binding registering the session-scoped game controller and dependencies.
class GameBinding extends Bindings {
  GameBinding(this.controller);

  final GameController controller;

  @override
  void dependencies() {
    Get.put<GameController>(controller);
  }
}
