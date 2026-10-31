import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/interval_engine.dart';

/// Mirrors the running workout on the lock screen (and Dynamic Island) so it
/// can be followed without unlocking the phone.
abstract interface class LiveActivityService {
  /// Starts or updates the activity. [phaseEndsAt] is the wall-clock time the
  /// current interval ends; `null` means the workout is paused.
  Future<void> show(WorkoutSnapshot snapshot, {DateTime? phaseEndsAt});

  Future<void> end();
}

/// Android already shows an ongoing notification from the foreground service.
LiveActivityService createPlatformLiveActivityService() => Platform.isIOS
    ? MethodChannelLiveActivityService()
    : NoopLiveActivityService();

class NoopLiveActivityService implements LiveActivityService {
  @override
  Future<void> show(WorkoutSnapshot snapshot, {DateTime? phaseEndsAt}) async {}

  @override
  Future<void> end() async {}
}

/// iOS: an ActivityKit Live Activity, driven by `LiveActivityChannel.swift`.
///
/// The countdown is rendered natively from the interval's end date, so it
/// only needs updating when the phase changes or the workout pauses.
class MethodChannelLiveActivityService implements LiveActivityService {
  static const _channel = MethodChannel('run_walk_timer/live_activity');

  @override
  Future<void> show(WorkoutSnapshot snapshot, {DateTime? phaseEndsAt}) async {
    final endsAt = phaseEndsAt ?? DateTime.now().add(snapshot.remaining);
    final startedAt = endsAt.subtract(snapshot.intervalDuration);
    try {
      await _channel.invokeMethod<void>('show', {
        'phase': snapshot.phase.label,
        'round': snapshot.round,
        'totalRounds': snapshot.totalRounds,
        'phaseStartMs': startedAt.millisecondsSinceEpoch,
        'phaseEndMs': endsAt.millisecondsSinceEpoch,
        'pausedRemainingMs': phaseEndsAt == null
            ? snapshot.remaining.inMilliseconds
            : null,
      });
    } catch (e) {
      debugPrint('LiveActivity: show failed: $e');
    }
  }

  @override
  Future<void> end() async {
    try {
      await _channel.invokeMethod<void>('end');
    } catch (e) {
      debugPrint('LiveActivity: end failed: $e');
    }
  }
}
