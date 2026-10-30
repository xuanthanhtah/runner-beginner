import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:run_walk_timer/application/clock.dart';
import 'package:run_walk_timer/application/providers.dart';
import 'package:run_walk_timer/application/workout_controller.dart';
import 'package:run_walk_timer/domain/interval_engine.dart';
import 'package:run_walk_timer/domain/interval_phase.dart';
import 'package:run_walk_timer/domain/workout_config.dart';
import 'package:run_walk_timer/services/background_keeper.dart';
import 'package:run_walk_timer/services/haptic_service.dart';
import 'package:run_walk_timer/services/notification_scheduler.dart';
import 'package:run_walk_timer/services/settings_repository.dart';
import 'package:run_walk_timer/services/sound_service.dart';
import 'package:run_walk_timer/services/wake_lock_service.dart';

class MockHaptics extends Mock implements HapticService {}

class MockSound extends Mock implements SoundService {}

class MockBackground extends Mock implements BackgroundKeeper {}

class MockNotifications extends Mock implements NotificationScheduler {}

class MockWakeLock extends Mock implements WakeLockService {}

class FakeClock implements Clock {
  Duration _now = Duration.zero;
  final DateTime _wallStart = DateTime.utc(2026, 1, 1, 7);

  @override
  Duration get monotonic => _now;

  @override
  DateTime get wall => _wallStart.add(_now);

  void advance(Duration d) => _now += d;
}

class FakeTimer implements Timer {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

class InMemorySettings implements SettingsRepository {
  InMemorySettings(this.config);

  WorkoutConfig config;

  @override
  WorkoutConfig load() => config;

  @override
  Future<void> save(WorkoutConfig value) async => config = value;
}

Duration s(num seconds) => Duration(microseconds: (seconds * 1e6).round());

void main() {
  setUpAll(() {
    registerFallbackValue(<ScheduledCue>[]);
    registerFallbackValue(const IntervalEngine(WorkoutConfig.defaults)
        .snapshotAt(Duration.zero));
  });

  late FakeClock clock;
  late MockHaptics haptics;
  late MockSound sound;
  late MockBackground background;
  late MockNotifications notifications;
  late MockWakeLock wakeLock;
  late InMemorySettings settings;
  late List<FakeTimer> timers;
  late ProviderContainer container;

  const config = WorkoutConfig(
    runDuration: Duration(seconds: 10),
    walkDuration: Duration(seconds: 5),
    rounds: 2,
  );

  WorkoutController controller() =>
      container.read(workoutControllerProvider.notifier);
  WorkoutState state() => container.read(workoutControllerProvider);

  /// Advances the fake clock and polls the controller at 100 ms steps,
  /// mimicking the real periodic ticker.
  void runFor(Duration d, {Duration step = const Duration(milliseconds: 100)}) {
    var left = d;
    while (left > Duration.zero) {
      final inc = left < step ? left : step;
      clock.advance(inc);
      controller().tick();
      left -= inc;
    }
  }

  setUp(() {
    clock = FakeClock();
    haptics = MockHaptics();
    sound = MockSound();
    background = MockBackground();
    notifications = MockNotifications();
    wakeLock = MockWakeLock();
    settings = InMemorySettings(config);
    timers = [];

    for (final f in <Future<void> Function()>[
      haptics.countdownTick,
      haptics.phaseSwitch,
      haptics.workoutComplete,
      sound.countdownTick,
      sound.phaseSwitch,
      sound.workoutComplete,
      background.stop,
      notifications.cancelAll,
      wakeLock.disable,
      wakeLock.enable,
    ]) {
      when(f).thenAnswer((_) async {});
    }
    when(() => background.start(any())).thenAnswer((_) async {});
    when(() => background.update(any())).thenAnswer((_) async {});
    when(() => notifications.schedule(any())).thenAnswer((_) async {});

    container = ProviderContainer.test(overrides: [
      clockProvider.overrideWithValue(clock),
      hapticServiceProvider.overrideWithValue(haptics),
      soundServiceProvider.overrideWithValue(sound),
      backgroundKeeperProvider.overrideWithValue(background),
      notificationSchedulerProvider.overrideWithValue(notifications),
      wakeLockServiceProvider.overrideWithValue(wakeLock),
      settingsRepositoryProvider.overrideWithValue(settings),
      periodicSchedulerProvider.overrideWithValue((interval, callback) {
        final t = FakeTimer();
        timers.add(t);
        return t;
      }),
    ]);
  });

  group('lifecycle', () {
    test('starts idle with the persisted config', () {
      expect(state().status, WorkoutStatus.idle);
      expect(state().config, config);
      expect(state().snapshot.remaining, s(10));
    });

    test('start → running, starts ticker, background service and wake lock',
        () {
      controller().start();
      expect(state().status, WorkoutStatus.running);
      expect(timers, hasLength(1));
      verify(() => background.start(any())).called(1);
      verify(wakeLock.enable).called(1);
      verify(() => notifications.schedule(any())).called(1);
    });

    test('does not enable wake lock when keepScreenOn is off', () {
      settings.config = config.copyWith(keepScreenOn: false);
      container.invalidate(workoutControllerProvider);
      controller().start();
      verifyNever(wakeLock.enable);
    });

    test('elapsed time follows the clock, not the number of ticks', () {
      controller().start();
      clock.advance(s(3.4)); // one late poll instead of 34 regular ones
      controller().tick();
      expect(state().snapshot.remaining, s(6.6));
    });

    test('pause freezes time and fires nothing; resume continues', () {
      controller().start();
      runFor(s(4));
      controller().pause();
      expect(state().status, WorkoutStatus.paused);
      expect(timers.single.cancelled, isTrue);
      verify(notifications.cancelAll).called(1);

      clock.advance(s(60)); // time passes while paused
      controller().tick();
      expect(state().snapshot.remaining, s(6));
      verifyNever(haptics.countdownTick);

      controller().resume();
      expect(state().status, WorkoutStatus.running);
      expect(timers, hasLength(2));
      runFor(s(3));
      expect(state().snapshot.remaining, s(3));
      verify(haptics.countdownTick).called(1); // T-3 at elapsed 7
    });

    test('reset returns to idle and tears everything down', () {
      controller().start();
      runFor(s(12));
      controller().reset();
      expect(state().status, WorkoutStatus.idle);
      expect(state().snapshot.phase, IntervalPhase.run);
      expect(state().snapshot.remaining, s(10));
      expect(timers.last.cancelled, isTrue);
      verify(background.stop).called(1);
      verify(wakeLock.disable).called(1);
      verify(notifications.cancelAll).called(greaterThanOrEqualTo(1));
    });

    test('completes after the final WALK and stops the ticker', () {
      controller().start();
      runFor(s(31));
      expect(state().status, WorkoutStatus.completed);
      expect(state().snapshot.isComplete, isTrue);
      expect(timers.single.cancelled, isTrue);
      verify(background.stop).called(1);
      verify(wakeLock.disable).called(1);
    });

    test('updateConfig persists and is ignored while running', () {
      const next = WorkoutConfig(
        runDuration: Duration(seconds: 30),
        walkDuration: Duration(seconds: 20),
        rounds: null,
      );
      controller().updateConfig(next);
      expect(state().config, next);
      expect(settings.config, next);
      expect(state().snapshot.remaining, s(30));

      controller().start();
      controller().updateConfig(config);
      expect(state().config, next);
    });
  });

  group('haptic cues at T-3, T-2, T-1, T-0', () {
    test('ticks fire exactly at 7, 8 and 9 seconds, switch at 10', () {
      controller().start();

      runFor(s(6.9));
      verifyNever(haptics.countdownTick);

      runFor(s(0.1)); // elapsed 7.0 → T-3
      verify(haptics.countdownTick).called(1);
      runFor(s(1)); // T-2
      verify(haptics.countdownTick).called(1);
      runFor(s(1)); // T-1
      verify(haptics.countdownTick).called(1);
      verifyNever(haptics.phaseSwitch);

      runFor(s(1)); // T-0 → strong switch pattern, no extra tick
      verify(haptics.phaseSwitch).called(1);
      verifyNever(haptics.countdownTick);
      expect(state().snapshot.phase, IntervalPhase.walk);
      verify(() => background.update(any())).called(1);
    });

    test('final interval fires workoutComplete instead of a switch', () {
      controller().start();
      runFor(s(29));
      clearInteractions(haptics);
      runFor(s(1));
      verify(haptics.workoutComplete).called(1);
      verifyNever(haptics.phaseSwitch);
      verifyNever(haptics.countdownTick);
    });

    test('full workout fires 12 ticks, 3 switches and 1 completion', () {
      controller().start();
      runFor(s(40));
      verify(haptics.countdownTick).called(12);
      verify(haptics.phaseSwitch).called(3);
      verify(haptics.workoutComplete).called(1);
    });

    test('sound cues mirror haptics when sound is enabled', () {
      controller().start();
      runFor(s(10));
      verify(sound.countdownTick).called(3);
      verify(sound.phaseSwitch).called(1);
    });

    test('toggles suppress haptics and sound independently', () {
      settings.config =
          config.copyWith(vibrationEnabled: false, soundEnabled: false);
      container.invalidate(workoutControllerProvider);
      controller().start();
      runFor(s(30));
      verifyZeroInteractions(haptics);
      verifyNever(sound.countdownTick);
      verifyNever(sound.phaseSwitch);
      verifyNever(sound.workoutComplete);
    });
  });

  group('background catch-up', () {
    test('drops stale countdown ticks after a long gap but keeps the switch',
        () {
      controller().start();
      runFor(s(6));
      clock.advance(s(4.7)); // suspended through T-3..T-0, resumes at 10.7
      controller().onAppResumed();
      verifyNever(haptics.countdownTick);
      verify(haptics.phaseSwitch).called(1);
      expect(state().snapshot.phase, IntervalPhase.walk);
    });

    test('collapses multiple missed switches into the latest one', () {
      controller().start();
      runFor(s(1));
      clock.advance(s(14.7)); // elapsed 15.7: switches at 10 and 15 crossed
      controller().tick();
      verify(haptics.phaseSwitch).called(1);
      verifyNever(haptics.countdownTick); // all ticks > 1.5s old
    });

    test('completion is always reported, stale switches are not replayed', () {
      controller().start();
      runFor(s(1));
      clock.advance(s(15)); // elapsed 16: switch at 15 is 1s old → fired
      controller().tick();
      verify(haptics.phaseSwitch).called(1);
      clock.advance(s(8)); // elapsed 24 → nothing crossed but ticks
      controller().tick();
      clock.advance(s(20)); // elapsed 44: switch at 25 is 19s old → dropped
      controller().tick();
      verifyNever(haptics.phaseSwitch);
      verify(haptics.workoutComplete).called(1);
      expect(state().status, WorkoutStatus.completed);
    });
  });

  group('notification fallback', () {
    test('schedules upcoming switches and completion with wall-clock times',
        () {
      controller().start();
      final cues = verify(() => notifications.schedule(captureAny()))
          .captured
          .single as List<ScheduledCue>;
      expect(cues.map((c) => c.at).toList(), [
        clock.wall.add(s(10)),
        clock.wall.add(s(15)),
        clock.wall.add(s(25)),
        clock.wall.add(s(30)),
      ]);
      expect(cues.first.title, 'WALK');
      expect(cues.last.title, 'Workout complete');
    });

    test('caps scheduled notifications in infinite mode', () {
      settings.config = config.copyWith(rounds: () => null);
      container.invalidate(workoutControllerProvider);
      controller().start();
      final cues = verify(() => notifications.schedule(captureAny()))
          .captured
          .single as List<ScheduledCue>;
      expect(cues, hasLength(NotificationScheduler.maxPending));
    });

    test('reschedules from the paused position on resume', () {
      controller().start();
      runFor(s(12));
      controller().pause();
      clock.advance(s(100));
      clearInteractions(notifications);
      controller().resume();
      final cues = verify(() => notifications.schedule(captureAny()))
          .captured
          .single as List<ScheduledCue>;
      // Elapsed is 12 → next switch at 15 is 3s from now.
      expect(cues.first.at, clock.wall.add(s(3)));
    });
  });
}
