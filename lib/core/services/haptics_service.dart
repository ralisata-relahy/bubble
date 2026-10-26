import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vibration/vibration.dart';

/// Small adapter around the optional device vibration integration.
class HapticsService {
  Future<bool>? _supportsVibration;

  /// Vibrates for [duration] milliseconds when the device supports haptics.
  /// Unsupported devices and plugin errors leave gameplay unaffected.
  Future<void> vibrate({required int duration}) async {
    try {
      final supportsVibration = await (_supportsVibration ??=
          Vibration.hasVibrator());
      if (supportsVibration) {
        await Vibration.vibrate(duration: duration);
      }
    } catch (error) {
      debugPrint('Haptic feedback failed: $error');
    }
  }
}
