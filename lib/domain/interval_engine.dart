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
        phase: config.secondPhase,
        round: config.rounds!,
        totalRounds: config.rounds,
        remaining: Duration.zero,
        intervalDuration: config.durationOf(config.secondPhase),
        isComplete: true,
      );
    }

    final cycleUs = config.cycleDuration.inMicroseconds;
    final cycleIndex = elapsed.inMicroseconds ~/ cycleUs;
    final offset = Duration(
      microseconds: elapsed.inMicroseconds - cycleIndex * cycleUs,
    );
    final firstDuration = config.durationOf(config.firstPhase);
    final inFirst = offset < firstDuration;
    final phase = inFirst ? config.firstPhase : config.secondPhase;

    return WorkoutSnapshot(
      phase: phase,
      round: cycleIndex + 1,
      totalRounds: config.rounds,
      remaining: inFirst
          ? firstDuration - offset
          : config.cycleDuration - offset,
      intervalDuration: config.durationOf(phase),
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

      final length = config.durationOf(_phaseOf(index));
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
        events.add(
          isLast
              ? WorkoutComplete(end)
              : PhaseSwitch(end, _phaseOf(index + 1), (index + 1) ~/ 2 + 1),
        );
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
        (offsetUs < config.durationOf(config.firstPhase).inMicroseconds
            ? 0
            : 1);
  }

  IntervalPhase _phaseOf(int index) =>
      index.isEven ? config.firstPhase : config.secondPhase;

  Duration _intervalStart(int index) =>
      config.cycleDuration * (index ~/ 2) +
      (index.isOdd ? config.durationOf(config.firstPhase) : Duration.zero);
}
