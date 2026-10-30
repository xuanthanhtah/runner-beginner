/// Time source for the workout.
///
/// [monotonic] drives all interval maths: it never jumps when the user or
/// network changes the system time. [wall] is only used to translate future
/// events into OS notification times.
abstract interface class Clock {
  Duration get monotonic;
  DateTime get wall;
}

class SystemClock implements Clock {
  SystemClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get monotonic => _stopwatch.elapsed;

  @override
  DateTime get wall => DateTime.now();
}
