import 'package:bubble/features/curio/controllers/curio_controller.dart';
import 'package:bubble/features/curio/domain/models/mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CurioController', () {
    test('initializes with excited mood', () {
      final controller = CurioController();
      expect(controller.currentMood.value, Mood.excited);
      controller.onClose();
    });

    test('updates mood reactively', () {
      final controller = CurioController();
      controller.updateMood(Mood.sad);
      expect(controller.currentMood.value, Mood.sad);

      controller.updateMood(Mood.angry);
      expect(controller.currentMood.value, Mood.angry);
      controller.onClose();
    });
  });
}
