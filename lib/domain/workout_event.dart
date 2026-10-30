import 'interval_phase.dart';

/// A cue the workout emits at a precise elapsed time.
sealed class WorkoutEvent {
  const WorkoutEvent(this.at);

  /// Elapsed workout time at which the event is due.
  final Duration at;
}

/// Fired at T-3s, T-2s and T-1s of every interval.
final class CountdownTick extends WorkoutEvent {
  const CountdownTick(super.at, this.secondsLeft);

  final int secondsLeft;
}

/// Fired at T-0 when another interval follows.
final class PhaseSwitch extends WorkoutEvent {
  const PhaseSwitch(super.at, this.to, this.round);

  /// The phase that is starting.
  final IntervalPhase to;

  /// The (1-based) round the new interval belongs to.
  final int round;
}

/// Fired at T-0 of the final interval instead of a [PhaseSwitch].
final class WorkoutComplete extends WorkoutEvent {
  const WorkoutComplete(super.at);
}
