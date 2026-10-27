import 'package:bubble/features/game/controllers/game_controller.dart';
import 'package:get/get.dart';


/// GetX binding registering the session-scoped game controller and dependencies.
class GameBinding extends Bindings {
  GameBinding(this.controller);

  final GameController controller;

  @override
  void dependencies() {
    Get.put<GameController>(controller);
  }
}
