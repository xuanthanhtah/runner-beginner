import 'package:flutter_test/flutter_test.dart';
import 'package:run_walk_timer/domain/interval_engine.dart';
import 'package:run_walk_timer/domain/interval_phase.dart';
import 'package:run_walk_timer/domain/workout_config.dart';
import 'package:run_walk_timer/domain/workout_event.dart';

Duration s(num seconds) => Duration(microseconds: (seconds * 1e6).round());

/// Renders events as compact strings so whole timelines can be compared.
List<String> describe(List<WorkoutEvent> events) => [
  for (final e in events)
    switch (e) {
      CountdownTick(:final at, :final secondsLeft) =>
        'tick$secondsLeft@${at.inMilliseconds / 1000}',
      PhaseSwitch(:final at, :final to, :final round) =>
        '${to.name}$round@${at.inMilliseconds / 1000}',
      WorkoutComplete(:final at) => 'done@${at.inMilliseconds / 1000}',
    },
];

void main() {
  // run 10s / walk 5s / 2 rounds → total 30s.
  const config = WorkoutConfig(
    runDuration: Duration(seconds: 10),
    walkDuration: Duration(seconds: 5),
    rounds: 2,
  );
  const engine = IntervalEngine(config);

  group('snapshotAt', () {
    test('starts in RUN round 1 with the full run duration remaining', () {
      final snap = engine.snapshotAt(Duration.zero);
      expect(snap.phase, IntervalPhase.run);
      expect(snap.round, 1);
      expect(snap.totalRounds, 2);
      expect(snap.remaining, s(10));
      expect(snap.progress, 0);
      expect(snap.isComplete, isFalse);
    });

    test('computes remaining time from elapsed delta mid-interval', () {
      final snap = engine.snapshotAt(s(3.25));
      expect(snap.phase, IntervalPhase.run);
      expect(snap.remaining, s(6.75));
      expect(snap.progress, closeTo(0.325, 1e-9));
    });

    test('switches to WALK exactly at the run boundary', () {
      expect(engine.snapshotAt(s(9.999)).phase, IntervalPhase.run);
      final snap = engine.snapshotAt(s(10));
      expect(snap.phase, IntervalPhase.walk);
      expect(snap.round, 1);
      expect(snap.remaining, s(5));
    });

    test('advances to RUN round 2 after the first walk', () {
      final snap = engine.snapshotAt(s(16));
      expect(snap.phase, IntervalPhase.run);
      expect(snap.round, 2);
      expect(snap.remaining, s(9));
    });

    test('is complete at and after the total duration', () {
      for (final t in [s(30), s(31), s(999)]) {
        final snap = engine.snapshotAt(t);
        expect(snap.isComplete, isTrue);
        expect(snap.round, 2);
        expect(snap.phase, IntervalPhase.walk);
        expect(snap.remaining, Duration.zero);
        expect(snap.progress, 1);
      }
    });

    test('infinite mode never completes and keeps counting rounds', () {
      const infinite = IntervalEngine(
        WorkoutConfig(
          runDuration: Duration(seconds: 10),
          walkDuration: Duration(seconds: 5),
          rounds: null,
        ),
      );
      final snap = infinite.snapshotAt(s(15 * 100 + 2));
      expect(snap.isComplete, isFalse);
      expect(snap.round, 101);
      expect(snap.totalRounds, isNull);
      expect(snap.phase, IntervalPhase.run);
    });

    test('treats negative elapsed as zero', () {
      expect(engine.snapshotAt(s(-1)).remaining, s(10));
    });
  });

  group('eventsBetween', () {
    test(
      'fires T-3, T-2, T-1 ticks then a switch at T-0 for every interval',
      () {
        expect(describe(engine.eventsBetween(Duration.zero, s(30))), [
          'tick3@7.0', 'tick2@8.0', 'tick1@9.0', 'walk1@10.0', //
          'tick3@12.0', 'tick2@13.0', 'tick1@14.0', 'run2@15.0',
          'tick3@22.0', 'tick2@23.0', 'tick1@24.0', 'walk2@25.0',
          'tick3@27.0', 'tick2@28.0', 'tick1@29.0', 'done@30.0',
        ]);
      },
    );

    test('last interval ends with WorkoutComplete instead of PhaseSwitch', () {
      final last = engine.eventsBetween(s(29.5), s(30));
      expect(last, hasLength(1));
      expect(last.single, isA<WorkoutComplete>());
    });

    test('never fires a countdown tick at T-0', () {
      final ticks = engine
          .eventsBetween(Duration.zero, s(30))
          .whereType<CountdownTick>();
      expect(ticks.map((t) => t.secondsLeft).toSet(), {3, 2, 1});
    });

    test('boundary is inclusive of the upper bound only', () {
      expect(engine.eventsBetween(Duration.zero, s(6.999)), isEmpty);
      expect(describe(engine.eventsBetween(s(6.999), s(7))), ['tick3@7.0']);
      // Already delivered at 7.0; must not repeat.
      expect(engine.eventsBetween(s(7), s(7.5)), isEmpty);
    });

    test('fine-grained polling yields each event exactly once', () {
      final all = <WorkoutEvent>[];
      var prev = Duration.zero;
      for (var ms = 100; ms <= 31000; ms += 100) {
        final now = Duration(milliseconds: ms);
        all.addAll(engine.eventsBetween(prev, now));
        prev = now;
      }
      expect(
        describe(all),
        describe(engine.eventsBetween(Duration.zero, s(31))),
      );
    });

    test('a single large jump returns all crossed events in order', () {
      final events = engine.eventsBetween(Duration.zero, s(20));
      expect(describe(events), [
        'tick3@7.0', 'tick2@8.0', 'tick1@9.0', 'walk1@10.0', //
        'tick3@12.0', 'tick2@13.0', 'tick1@14.0', 'run2@15.0',
      ]);
      final times = events.map((e) => e.at).toList();
      expect(times, [...times]..sort());
    });

    test('emits nothing after completion', () {
      expect(engine.eventsBetween(s(30), s(100)), isEmpty);
    });

    test('emits nothing for an empty or reversed range', () {
      expect(engine.eventsBetween(s(8), s(8)), isEmpty);
      expect(engine.eventsBetween(s(9), s(8)), isEmpty);
    });

    test('short intervals only emit ticks that fit inside the interval', () {
      const short = IntervalEngine(
        WorkoutConfig(
          runDuration: Duration(seconds: 3),
          walkDuration: Duration(seconds: 2),
          rounds: 1,
        ),
      );
      expect(describe(short.eventsBetween(Duration.zero, s(5))), [
        'tick2@1.0', 'tick1@2.0', 'walk1@3.0', //
        'tick1@4.0', 'done@5.0',
      ]);
    });

    test('infinite mode keeps emitting switches and never completes', () {
      const infinite = IntervalEngine(
        WorkoutConfig(
          runDuration: Duration(seconds: 10),
          walkDuration: Duration(seconds: 5),
          rounds: null,
        ),
      );
      final events = infinite.eventsBetween(Duration.zero, s(15 * 50));
      expect(events.whereType<WorkoutComplete>(), isEmpty);
      expect(events.whereType<PhaseSwitch>(), hasLength(100));
      final lastSwitch = events.whereType<PhaseSwitch>().last;
      expect(lastSwitch.to, IntervalPhase.run);
      expect(lastSwitch.round, 51);
    });
  });

  group('start with walk', () {
    const walkFirst = WorkoutConfig(
      runDuration: Duration(seconds: 10),
      walkDuration: Duration(seconds: 5),
      rounds: 2,
      startWithWalk: true,
    );
    const engine = IntervalEngine(walkFirst);

    test('each round is WALK then RUN', () {
      expect(engine.snapshotAt(Duration.zero).phase, IntervalPhase.walk);
      expect(engine.snapshotAt(Duration.zero).remaining, s(5));
      final snap = engine.snapshotAt(s(5));
      expect(snap.phase, IntervalPhase.run);
      expect(snap.remaining, s(10));
      expect(engine.snapshotAt(s(15)).phase, IntervalPhase.walk);
      expect(engine.snapshotAt(s(15)).round, 2);
    });

    test('switches and completion follow the walk-first order', () {
      expect(describe(engine.eventsBetween(Duration.zero, s(30))), [
        'tick3@2.0', 'tick2@3.0', 'tick1@4.0', 'run1@5.0', //
        'tick3@12.0', 'tick2@13.0', 'tick1@14.0', 'walk2@15.0',
        'tick3@17.0', 'tick2@18.0', 'tick1@19.0', 'run2@20.0',
        'tick3@27.0', 'tick2@28.0', 'tick1@29.0', 'done@30.0',
      ]);
      final done = engine.snapshotAt(s(30));
      expect(done.isComplete, isTrue);
      expect(done.phase, IntervalPhase.run);
    });
  });

  group('WorkoutConfig', () {
    test('round-trips through JSON, including infinite rounds', () {
      const cfg = WorkoutConfig(
        runDuration: Duration(seconds: 120),
        walkDuration: Duration(seconds: 45),
        rounds: null,
        soundEnabled: false,
        vibrationEnabled: true,
        keepScreenOn: false,
        startWithWalk: true,
      );
      expect(WorkoutConfig.fromJson(cfg.toJson()), cfg);
    });

    test('fromJson falls back to defaults for missing or invalid values', () {
      expect(WorkoutConfig.fromJson(const {}), WorkoutConfig.defaults);
      final clamped = WorkoutConfig.fromJson(const {
        'runSeconds': 1,
        'walkSeconds': 999999,
        'rounds': 500,
      });
      expect(clamped.runDuration, WorkoutConfig.minIntervalDuration);
      expect(clamped.walkDuration, WorkoutConfig.maxIntervalDuration);
      expect(clamped.rounds, WorkoutConfig.maxRounds);
    });
  });
}
