import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_walk_timer/app.dart';
import 'package:run_walk_timer/application/clock.dart';
import 'package:run_walk_timer/application/providers.dart';
import 'package:run_walk_timer/application/workout_controller.dart';
import 'package:run_walk_timer/domain/interval_engine.dart';
import 'package:run_walk_timer/domain/workout_config.dart';
import 'package:run_walk_timer/services/background_keeper.dart';
import 'package:run_walk_timer/services/haptic_service.dart';
import 'package:run_walk_timer/services/notification_scheduler.dart';
import 'package:run_walk_timer/services/settings_repository.dart';
import 'package:run_walk_timer/services/sound_service.dart';
import 'package:run_walk_timer/services/wake_lock_service.dart';

class _Clock implements Clock {
  Duration now = Duration.zero;

  @override
  Duration get monotonic => now;

  @override
  DateTime get wall => DateTime.utc(2026).add(now);
}

class _Silent implements HapticService, SoundService {
  @override
  Future<void> countdownTick() async {}
  @override
  Future<void> phaseSwitch() async {}
  @override
  Future<void> workoutComplete() async {}
}

class _Background implements BackgroundKeeper {
  @override
  Future<void> start(WorkoutSnapshot snapshot) async {}
  @override
  Future<void> update(WorkoutSnapshot snapshot) async {}
  @override
  Future<void> stop() async {}
}

class _Notifications implements NotificationScheduler {
  @override
  Future<void> schedule(List<ScheduledCue> cues) async {}
  @override
  Future<void> cancelAll() async {}
}

class _WakeLock implements WakeLockService {
  @override
  Future<void> enable() async {}
  @override
  Future<void> disable() async {}
}

class _Settings implements SettingsRepository {
  WorkoutConfig config = WorkoutConfig.defaults;
  @override
  WorkoutConfig load() => config;
  @override
  Future<void> save(WorkoutConfig value) async => config = value;
}

class _NeverTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

void main() {
  late _Clock clock;
  late _Settings settings;
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    // A tall phone-sized surface so the settings sheet fits without scrolling.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    clock = _Clock();
    settings = _Settings();
    final silent = _Silent();
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock),
      hapticServiceProvider.overrideWithValue(silent),
      soundServiceProvider.overrideWithValue(silent),
      backgroundKeeperProvider.overrideWithValue(_Background()),
      notificationSchedulerProvider.overrideWithValue(_Notifications()),
      wakeLockServiceProvider.overrideWithValue(_WakeLock()),
      settingsRepositoryProvider.overrideWithValue(settings),
      periodicSchedulerProvider.overrideWithValue((_, _) => _NeverTimer()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const RunWalkApp(),
    ));
  }

  void advance(Duration d) {
    clock.now += d;
    container.read(workoutControllerProvider.notifier).tick();
  }

  testWidgets('idle screen shows phase, full countdown and round tracker',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('RUN'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('Round 1 / 8'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('start, pause, resume and stop drive the controller',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.text('PAUSE'), findsOneWidget);
    expect(find.text('STOP'), findsOneWidget);

    advance(const Duration(seconds: 15, milliseconds: 300));
    await tester.pump();
    expect(find.text('00:45'), findsOneWidget); // ceil(44.7s)

    await tester.tap(find.text('PAUSE'));
    await tester.pump();
    expect(find.text('RESUME'), findsOneWidget);
    expect(container.read(workoutControllerProvider).status,
        WorkoutStatus.paused);

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(find.text('PAUSE'), findsOneWidget);

    await tester.tap(find.text('STOP'));
    await tester.pump();
    expect(find.text('START'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);
  });

  testWidgets('shows WALK after the run interval', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('START'));
    advance(const Duration(seconds: 61));
    await tester.pump();
    expect(find.text('WALK'), findsOneWidget);
    expect(find.text('00:59'), findsOneWidget);
  });

  testWidgets('settings are locked while a workout is running',
      (tester) async {
    await pumpApp(tester);
    final settingsButton = find.widgetWithIcon(IconButton, Icons.tune_rounded);
    expect(tester.widget<IconButton>(settingsButton).onPressed, isNotNull);

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(tester.widget<IconButton>(settingsButton).onPressed, isNull);
  });

  testWidgets('settings sheet edits durations, rounds and toggles',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Workout settings'));
    await tester.pumpAndSettle();

    // Run 1:00 → 1:15 → 1:30.
    await tester.tap(find.byTooltip('Increase run'));
    await tester.tap(find.byTooltip('Increase run'));
    // Walk 1:00 → 0:45.
    await tester.tap(find.byTooltip('Decrease walk'));
    await tester.tap(find.byKey(const Key('infinite-switch')));
    await tester.tap(find.byKey(const Key('sound-switch')));
    await tester.pump();

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final config = container.read(workoutControllerProvider).config;
    expect(config.runDuration, const Duration(seconds: 90));
    expect(config.walkDuration, const Duration(seconds: 45));
    expect(config.rounds, isNull);
    expect(config.soundEnabled, isFalse);
    expect(settings.config, config);

    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('Round 1 · ∞'), findsOneWidget);
  });

  testWidgets('preset chip applies a run/walk ratio', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Workout settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2:00 / 1:00'));
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    final config = container.read(workoutControllerProvider).config;
    expect(config.runDuration, const Duration(minutes: 2));
    expect(config.walkDuration, const Duration(minutes: 1));
  });

  testWidgets('shows a completion state at the end', (tester) async {
    await pumpApp(tester);
    settings.config = const WorkoutConfig(
      runDuration: Duration(seconds: 5),
      walkDuration: Duration(seconds: 5),
      rounds: 1,
    );
    container.invalidate(workoutControllerProvider);
    await tester.pump();
    await tester.tap(find.text('START'));
    advance(const Duration(seconds: 11));
    await tester.pump();
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('AGAIN'), findsOneWidget);
  });
}
