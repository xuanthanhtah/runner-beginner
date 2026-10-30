/// User-configurable workout settings.
///
/// One round is a RUN interval followed by a WALK interval. A null [rounds]
/// means infinite mode: the workout repeats until stopped manually.
class WorkoutConfig {
  const WorkoutConfig({
    required this.runDuration,
    required this.walkDuration,
    required this.rounds,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.keepScreenOn = true,
  });

  static const minIntervalDuration = Duration(seconds: 5);
  static const maxIntervalDuration = Duration(minutes: 59, seconds: 59);
  static const minRounds = 1;
  static const maxRounds = 99;

  static const defaults = WorkoutConfig(
    runDuration: Duration(minutes: 1),
    walkDuration: Duration(minutes: 1),
    rounds: 8,
  );

  final Duration runDuration;
  final Duration walkDuration;
  final int? rounds;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool keepScreenOn;

  bool get isInfinite => rounds == null;

  Duration get cycleDuration => runDuration + walkDuration;

  /// Total workout length, or null in infinite mode.
  Duration? get totalDuration =>
      rounds == null ? null : cycleDuration * rounds!;

  WorkoutConfig copyWith({
    Duration? runDuration,
    Duration? walkDuration,
    int? Function()? rounds,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? keepScreenOn,
  }) {
    return WorkoutConfig(
      runDuration: clampInterval(runDuration ?? this.runDuration),
      walkDuration: clampInterval(walkDuration ?? this.walkDuration),
      rounds: rounds != null ? _clampRounds(rounds()) : this.rounds,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }

  Map<String, Object?> toJson() => {
        'runSeconds': runDuration.inSeconds,
        'walkSeconds': walkDuration.inSeconds,
        'rounds': rounds,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'keepScreenOn': keepScreenOn,
      };

  /// Parses persisted settings, clamping out-of-range values and falling back
  /// to [defaults] for anything missing or malformed.
  factory WorkoutConfig.fromJson(Map<String, Object?> json) {
    Duration seconds(String key, Duration fallback) {
      final value = json[key];
      return value is int
          ? clampInterval(Duration(seconds: value))
          : fallback;
    }

    bool flag(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    final int? rounds;
    if (!json.containsKey('rounds')) {
      rounds = defaults.rounds;
    } else {
      final value = json['rounds'];
      rounds = value is int ? _clampRounds(value) : null;
    }

    return WorkoutConfig(
      runDuration: seconds('runSeconds', defaults.runDuration),
      walkDuration: seconds('walkSeconds', defaults.walkDuration),
      rounds: rounds,
      soundEnabled: flag('soundEnabled', defaults.soundEnabled),
      vibrationEnabled: flag('vibrationEnabled', defaults.vibrationEnabled),
      keepScreenOn: flag('keepScreenOn', defaults.keepScreenOn),
    );
  }

  static Duration clampInterval(Duration d) {
    if (d < minIntervalDuration) return minIntervalDuration;
    if (d > maxIntervalDuration) return maxIntervalDuration;
    return d;
  }

  static int? _clampRounds(int? r) =>
      r?.clamp(minRounds, maxRounds);

  @override
  bool operator ==(Object other) =>
      other is WorkoutConfig &&
      other.runDuration == runDuration &&
      other.walkDuration == walkDuration &&
      other.rounds == rounds &&
      other.soundEnabled == soundEnabled &&
      other.vibrationEnabled == vibrationEnabled &&
      other.keepScreenOn == keepScreenOn;

  @override
  int get hashCode => Object.hash(runDuration, walkDuration, rounds,
      soundEnabled, vibrationEnabled, keepScreenOn);

  @override
  String toString() =>
      'WorkoutConfig(run: $runDuration, walk: $walkDuration, rounds: ${rounds ?? '∞'})';
}
