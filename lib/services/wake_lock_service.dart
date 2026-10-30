import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on during a workout when the user opts in.
abstract interface class WakeLockService {
  Future<void> enable();
  Future<void> disable();
}

class WakelockPlusService implements WakeLockService {
  @override
  Future<void> enable() => _guard(WakelockPlus.enable);

  @override
  Future<void> disable() => _guard(WakelockPlus.disable);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('WakeLockService: $e');
    }
  }
}
