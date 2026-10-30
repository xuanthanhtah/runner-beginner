import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../domain/interval_engine.dart';

/// Keeps the app process (and therefore the Dart timer) alive while a
/// workout runs with the screen locked or the app minimised.
abstract interface class BackgroundKeeper {
  Future<void> start(WorkoutSnapshot snapshot);
  Future<void> update(WorkoutSnapshot snapshot);
  Future<void> stop();
}

BackgroundKeeper createPlatformBackgroundKeeper() {
  if (Platform.isAndroid) return AndroidForegroundServiceKeeper();
  if (Platform.isIOS) return IosAudioSessionKeeper();
  return NoopBackgroundKeeper();
}

class NoopBackgroundKeeper implements BackgroundKeeper {
  @override
  Future<void> start(WorkoutSnapshot snapshot) async {}

  @override
  Future<void> update(WorkoutSnapshot snapshot) async {}

  @override
  Future<void> stop() async {}
}

String _title(WorkoutSnapshot s) => '${s.phase.label} in progress';

String _text(WorkoutSnapshot s) => s.totalRounds == null
    ? 'Round ${s.round} · tap to open'
    : 'Round ${s.round} / ${s.totalRounds} · tap to open';

/// Android: a foreground service with an ongoing notification plus a CPU wake
/// lock, so the OS neither kills the process nor lets the CPU sleep.
class AndroidForegroundServiceKeeper implements BackgroundKeeper {
  AndroidForegroundServiceKeeper() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'workout_session',
        channelName: 'Workout in progress',
        channelDescription: 'Shown while an interval workout is running.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowAutoRestart: false,
      ),
    );
  }

  static const _serviceId = 4210;

  @override
  Future<void> start(WorkoutSnapshot snapshot) async {
    try {
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      final result = await FlutterForegroundTask.isRunningService
          ? await FlutterForegroundTask.updateService(
              notificationTitle: _title(snapshot),
              notificationText: _text(snapshot),
            )
          : await FlutterForegroundTask.startService(
              serviceId: _serviceId,
              serviceTypes: [ForegroundServiceTypes.specialUse],
              notificationTitle: _title(snapshot),
              notificationText: _text(snapshot),
              callback: startWorkoutTaskCallback,
            );
      if (result is ServiceRequestFailure) {
        debugPrint('BackgroundKeeper: start failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('BackgroundKeeper: start failed: $e');
    }
  }

  @override
  Future<void> update(WorkoutSnapshot snapshot) async {
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: _title(snapshot),
        notificationText: _text(snapshot),
      );
    } catch (e) {
      debugPrint('BackgroundKeeper: update failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('BackgroundKeeper: stop failed: $e');
    }
  }
}

/// The service only exists to keep the process alive; the timer itself runs
/// in the main isolate, so the task handler does nothing.
@pragma('vm:entry-point')
void startWorkoutTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}

/// iOS: with the `audio` background mode, an active audio session keeps the
/// app running after the screen locks. A silent loop holds the session open
/// and mixes with the user's music.
class IosAudioSessionKeeper implements BackgroundKeeper {
  AudioPlayer? _player;

  @override
  Future<void> start(WorkoutSnapshot snapshot) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.setAudioContext(AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build());
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('sounds/silence.wav'));
    } catch (e) {
      debugPrint('BackgroundKeeper: iOS keep-alive failed: $e');
    }
  }

  @override
  Future<void> update(WorkoutSnapshot snapshot) async {}

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('BackgroundKeeper: iOS keep-alive stop failed: $e');
    }
  }
}
