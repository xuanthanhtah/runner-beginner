import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

abstract interface class HapticService {
  /// One incoming-call style buzz at each of T-3, T-2 and T-1.
  Future<void> countdownTick();

  /// Nothing extra at T-0: the three countdown buzzes already mark the end
  /// of the RUN or WALK interval.
  Future<void> phaseSwitch();

  /// Longer incoming-call style buzzing when the workout finishes.
  Future<void> workoutComplete();
}

class VibrationHapticService implements HapticService {
  // Android patterns alternate [wait, vibrate, wait, vibrate, ...] in
  // milliseconds, mimicking the ringer. A countdown buzz must fit in 1 s.
  static const _tickPattern = [0, 600];
  static const _completePattern = [
    0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, //
  ];

  // iOS: number of system ringer buzzes (see AppDelegate.swift). Unlike
  // Core Haptics these also play while the screen is locked.
  static const _tickRings = 1;
  static const _completeRings = 5;
  static const _ringer = MethodChannel('run_walk_timer/ringer');

  bool? _hasVibrator;

  Future<bool> _canVibrate() async =>
      _hasVibrator ??= await Vibration.hasVibrator();

  @override
  Future<void> countdownTick() => _ring(_tickRings, _tickPattern);

  @override
  Future<void> phaseSwitch() async {}

  @override
  Future<void> workoutComplete() => _ring(_completeRings, _completePattern);

  Future<void> _ring(int iosRings, List<int> androidPattern) {
    if (Platform.isIOS) {
      return _run(
        () => _ringer.invokeMethod<void>('ring', {'count': iosRings}),
        HapticFeedback.heavyImpact,
      );
    }
    return _run(
      () => Vibration.vibrate(pattern: androidPattern),
      HapticFeedback.heavyImpact,
    );
  }

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
