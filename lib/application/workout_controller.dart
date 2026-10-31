import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/interval_engine.dart';
import '../domain/workout_config.dart';
import '../domain/workout_event.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import 'providers.dart';

enum WorkoutStatus { idle, running, paused, completed }

class WorkoutState {
  const WorkoutState({
    required this.status,
    required this.config,
    required this.snapshot,
  });

  final WorkoutStatus status;
  final WorkoutConfig config;
  final WorkoutSnapshot snapshot;

  bool get isActive =>
      status == WorkoutStatus.running || status == WorkoutStatus.paused;

  WorkoutState copyWith({WorkoutStatus? status, WorkoutSnapshot? snapshot}) =>
      WorkoutState(
        status: status ?? this.status,
        config: config,
        snapshot: snapshot ?? this.snapshot,
      );
}

final workoutControllerProvider =
    NotifierProvider<WorkoutController, WorkoutState>(WorkoutController.new);

/// Drives a workout from a monotonic clock.
///
/// The periodic ticker only decides *when* to look at the clock; what is
/// shown and which cues fire is always derived from real elapsed time, so
/// late or skipped polls never cause drift or lost events.
class WorkoutController extends Notifier<WorkoutState> {
  static const pollInterval = Duration(milliseconds: 100);

  /// Countdown ticks older than this (e.g. after the OS suspended us) are
  /// dropped instead of buzzing in a burst.
  static const tickGrace = Duration(milliseconds: 1500);

  /// A missed phase switch is still announced if it is at most this old.
  static const switchGrace = Duration(seconds: 5);

  late IntervalEngine _engine;
  Timer? _ticker;
  Duration _accumulated = Duration.zero;
  Duration? _runningSince;
  Duration _lastElapsed = Duration.zero;

  @override
  WorkoutState build() {
    ref.onDispose(_stopTicker);
    _resetTime();
    return _idleState(ref.read(settingsRepositoryProvider).load());
  }

  void start() {
    if (state.isActive) return;
    _resetTime();
    _runningSince = ref.read(clockProvider).monotonic;
    state = _idleState(state.config).copyWith(status: WorkoutStatus.running);

    _startTicker();
    unawaited(ref.read(backgroundKeeperProvider).start(state.snapshot));
    _showLiveActivity();
    if (state.config.keepScreenOn) {
      unawaited(ref.read(wakeLockServiceProvider).enable());
    }
  }

  void pause() {
    if (state.status != WorkoutStatus.running) return;
    tick();
    if (state.status != WorkoutStatus.running) return; // completed on flush
    _accumulated = _elapsed();
    _runningSince = null;
    _stopTicker();
    state = state.copyWith(status: WorkoutStatus.paused);
    _showLiveActivity();
  }

  void resume() {
    if (state.status != WorkoutStatus.paused) return;
    _runningSince = ref.read(clockProvider).monotonic;
    state = state.copyWith(status: WorkoutStatus.running);
    _startTicker();
    _showLiveActivity();
  }

  void reset() {
    _teardown();
    _resetTime();
    state = _idleState(state.config);
  }

  /// Ignored while a workout is active.
  void updateConfig(WorkoutConfig config) {
    if (state.isActive) return;
    unawaited(ref.read(settingsRepositoryProvider).save(config));
    state = _idleState(config);
  }

  /// Re-syncs immediately when the app returns to the foreground.
  void onAppResumed() => tick();

  /// Samples the clock, fires any cues that came due, and updates state.
  void tick() {
    if (state.status != WorkoutStatus.running) return;

    final elapsed = _elapsed();
    final events = _engine.eventsBetween(_lastElapsed, elapsed);
    _lastElapsed = elapsed;
    _dispatch(events, elapsed);

    final previous = state.snapshot;
    final snapshot = _engine.snapshotAt(elapsed);
    if (snapshot.isComplete) {
      _teardown();
      state = state.copyWith(
        status: WorkoutStatus.completed,
        snapshot: snapshot,
      );
      return;
    }
    state = state.copyWith(snapshot: snapshot);
    if (snapshot.phase != previous.phase || snapshot.round != previous.round) {
      unawaited(ref.read(backgroundKeeperProvider).update(snapshot));
      _showLiveActivity();
    }
  }

  void _showLiveActivity() {
    final snapshot = state.snapshot;
    final endsAt = state.status == WorkoutStatus.running
        ? ref.read(clockProvider).wall.add(snapshot.remaining)
        : null;
    unawaited(
      ref.read(liveActivityServiceProvider).show(snapshot, phaseEndsAt: endsAt),
    );
  }

  void _dispatch(List<WorkoutEvent> events, Duration now) {
    final latestSwitch = events.whereType<PhaseSwitch>().lastOrNull;
    for (final event in events) {
      final age = now - event.at;
      switch (event) {
        case CountdownTick() when age <= tickGrace:
          _cue((h) => h.countdownTick(), (s) => s.countdownTick());
        case PhaseSwitch()
            when identical(event, latestSwitch) && age <= switchGrace:
          _cue((h) => h.phaseSwitch(), (s) => s.phaseSwitch());
        case WorkoutComplete():
          _cue((h) => h.workoutComplete(), (s) => s.workoutComplete());
        default:
          break;
      }
    }
  }

  void _cue(
    Future<void> Function(HapticService haptics) haptic,
    Future<void> Function(SoundService sound) sound,
  ) {
    final config = state.config;
    if (config.vibrationEnabled) {
      unawaited(haptic(ref.read(hapticServiceProvider)));
    }
    if (config.soundEnabled) {
      unawaited(sound(ref.read(soundServiceProvider)));
    }
  }

  void _teardown() {
    _stopTicker();
    unawaited(ref.read(backgroundKeeperProvider).stop());
    unawaited(ref.read(liveActivityServiceProvider).end());
    unawaited(ref.read(wakeLockServiceProvider).disable());
  }

  WorkoutState _idleState(WorkoutConfig config) {
    _engine = IntervalEngine(config);
    return WorkoutState(
      status: WorkoutStatus.idle,
      config: config,
      snapshot: _engine.snapshotAt(Duration.zero),
    );
  }

  Duration _elapsed() {
    final since = _runningSince;
    if (since == null) return _accumulated;
    return _accumulated + (ref.read(clockProvider).monotonic - since);
  }

  void _resetTime() {
    _accumulated = Duration.zero;
    _runningSince = null;
    _lastElapsed = Duration.zero;
  }

  void _startTicker() {
    _stopTicker();
    _ticker = ref.read(periodicSchedulerProvider)(pollInterval, (_) => tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}
