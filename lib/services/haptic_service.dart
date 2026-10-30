import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

abstract interface class HapticService {
  /// Short single pulse for T-3, T-2 and T-1.
  Future<void> countdownTick();

  /// Strong burst of three pulses when RUN ↔ WALK switches.
  Future<void> phaseSwitch();

  /// Long, extended pattern when the workout finishes.
  Future<void> workoutComplete();
}

class VibrationHapticService implements HapticService {
  // Patterns alternate [wait, vibrate, wait, vibrate, ...] in milliseconds.
  static const _switchPattern = [0, 250, 120, 250, 120, 250];
  static const _switchIntensities = [0, 255, 0, 255, 0, 255];
  static const _completePattern = [0, 600, 150, 600, 150, 1200];
  static const _completeIntensities = [0, 255, 0, 255, 0, 255];

  bool? _hasVibrator;

  Future<bool> _canVibrate() async =>
      _hasVibrator ??= await Vibration.hasVibrator();

  @override
  Future<void> countdownTick() => _run(
        () => Vibration.vibrate(duration: 80, amplitude: 160),
        HapticFeedback.mediumImpact,
      );

  @override
  Future<void> phaseSwitch() => _run(
        () => Vibration.vibrate(
          pattern: _switchPattern,
          intensities: _switchIntensities,
        ),
        HapticFeedback.heavyImpact,
      );

  @override
  Future<void> workoutComplete() => _run(
        () => Vibration.vibrate(
          pattern: _completePattern,
          intensities: _completeIntensities,
        ),
        HapticFeedback.heavyImpact,
      );

  /// Haptics are best-effort: a failure must never break the timer.
  Future<void> _run(
    Future<void> Function() vibrate,
    Future<void> Function() fallback,
  ) async {
    try {
      if (await _canVibrate()) {
        await vibrate();
      } else {
        await fallback();
      }
    } catch (e) {
      debugPrint('HapticService: vibration failed: $e');
    }
  }
}
