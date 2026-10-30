import 'interval_phase.dart';
import 'workout_config.dart';
import 'workout_event.dart';

/// Immutable view of the workout at a given elapsed time.
class WorkoutSnapshot {
  const WorkoutSnapshot({
    required this.phase,
    required this.round,
    required this.totalRounds,
    required this.remaining,
    required this.intervalDuration,
    required this.isComplete,
  });

  final IntervalPhase phase;
  final int round;
  final int? totalRounds;
  final Duration remaining;
  final Duration intervalDuration;
  final bool isComplete;

  /// Fraction of the current interval that has elapsed, 0.0 → 1.0.
  double get progress => intervalDuration == Duration.zero
      ? 1
      : 1 - remaining.inMicroseconds / intervalDuration.inMicroseconds;
}

/// Pure, stateless interval maths.
///
/// Everything is derived from elapsed time, so callers can poll at any rate
/// (or jump forward after being suspended) without drift or dropped events.
class IntervalEngine {
  const IntervalEngine(this.config);

  static const countdownSeconds = 3;

  final WorkoutConfig config;

  WorkoutSnapshot snapshotAt(Duration elapsed) {
    if (elapsed < Duration.zero) elapsed = Duration.zero;

    final total = config.totalDuration;
    if (total != null && elapsed >= total) {
      return WorkoutSnapshot(
        phase: IntervalPhase.walk,
        round: config.rounds!,
        totalRounds: config.rounds,
        remaining: Duration.zero,
        intervalDuration: config.walkDuration,
        isComplete: true,
      );
    }

    final cycleUs = config.cycleDuration.inMicroseconds;
    final cycleIndex = elapsed.inMicroseconds ~/ cycleUs;
    final offset =
        Duration(microseconds: elapsed.inMicroseconds - cycleIndex * cycleUs);
    final inRun = offset < config.runDuration;

    return WorkoutSnapshot(
      phase: inRun ? IntervalPhase.run : IntervalPhase.walk,
      round: cycleIndex + 1,
      totalRounds: config.rounds,
      remaining: inRun
          ? config.runDuration - offset
          : config.cycleDuration - offset,
      intervalDuration: inRun ? config.runDuration : config.walkDuration,
      isComplete: false,
    );
  }

  /// All events due in the half-open range `(from, to]`, in time order.
  ///
  /// Consecutive polls with `from` = previous `to` deliver every event exactly
  /// once, however irregular the polling.
  List<WorkoutEvent> eventsBetween(Duration from, Duration to) {
    if (to <= from) return const [];

    final total = config.totalDuration;
    final intervalCount = config.rounds == null ? null : config.rounds! * 2;
    final events = <WorkoutEvent>[];

    // Start from the interval containing `from` and walk forward.
    var index = _intervalIndexAt(from);
    while (intervalCount == null || index < intervalCount) {
      final start = _intervalStart(index);
      if (start > to) break;

      final length = index.isEven ? config.runDuration : config.walkDuration;
      final end = start + length;

      for (var n = countdownSeconds; n >= 1; n--) {
        final at = end - Duration(seconds: n);
        // Only ticks that fall strictly inside the interval.
        if (at > start && at > from && at <= to) {
          events.add(CountdownTick(at, n));
        }
      }

      if (end > from && end <= to) {
        final isLast = total != null && end >= total;
        events.add(isLast
            ? WorkoutComplete(end)
            : PhaseSwitch(
                end,
                index.isEven ? IntervalPhase.walk : IntervalPhase.run,
                (index + 1) ~/ 2 + 1,
              ));
      }

      index++;
    }
    return events;
  }

  int _intervalIndexAt(Duration elapsed) {
    if (elapsed <= Duration.zero) return 0;
    final cycleUs = config.cycleDuration.inMicroseconds;
    final cycleIndex = elapsed.inMicroseconds ~/ cycleUs;
    final offsetUs = elapsed.inMicroseconds - cycleIndex * cycleUs;
    return cycleIndex * 2 +
        (offsetUs < config.runDuration.inMicroseconds ? 0 : 1);
  }

  Duration _intervalStart(int index) =>
      config.cycleDuration * (index ~/ 2) +
      (index.isOdd ? config.runDuration : Duration.zero);
}
