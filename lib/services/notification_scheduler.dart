import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// A future OS notification for a phase switch or workout completion.
@immutable
class ScheduledCue {
  const ScheduledCue({required this.at, required this.title, this.body});

  final DateTime at;
  final String title;
  final String? body;
}

/// Pre-schedules OS notifications for upcoming transitions, as a fallback in
/// case the OS suspends the app and in-app cues stop firing.
abstract interface class NotificationScheduler {
  /// iOS allows 64 pending notifications per app; keep headroom.
  static const maxPending = 60;

  /// Replaces any previously scheduled cues.
  Future<void> schedule(List<ScheduledCue> cues);

  Future<void> cancelAll();
}

/// Android keeps the process alive with a foreground service, so only iOS
/// needs the notification fallback.
NotificationScheduler createPlatformNotificationScheduler() =>
    Platform.isIOS ? LocalNotificationScheduler() : NoopNotificationScheduler();

class NoopNotificationScheduler implements NotificationScheduler {
  @override
  Future<void> schedule(List<ScheduledCue> cues) async {}

  @override
  Future<void> cancelAll() async {}
}

class LocalNotificationScheduler implements NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  // Not shown while the app is in the foreground: in-app cues cover that.
  static const _details = NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: false,
      presentBanner: false,
      presentList: false,
      presentSound: false,
      presentBadge: false,
      interruptionLevel: InterruptionLevel.active,
    ),
  );

  Future<bool> _init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    return granted ?? false;
  }

  @override
  Future<void> schedule(List<ScheduledCue> cues) async {
    try {
      if (!await (_ready ??= _init())) return;
      await _plugin.cancelAll();
      final now = DateTime.now();
      var id = 0;
      for (final cue in cues.take(NotificationScheduler.maxPending)) {
        if (!cue.at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: tz.TZDateTime.from(cue.at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: cue.title,
          body: cue.body,
        );
      }
    } catch (e) {
      debugPrint('NotificationScheduler: schedule failed: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      if (_ready == null) return;
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationScheduler: cancel failed: $e');
    }
  }
}
