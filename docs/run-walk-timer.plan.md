# Plan: Run/Walk Interval Timer (Flutter)

**Complexity**: Medium-High
**Toolchain**: Flutter 3.47.0 stable, Dart 3.13.0
**Layout**: Flutter project at repo root (`runner-beginner/`), platforms Android + iOS

## Locked decisions
- One round = RUN then WALK. The workout ends after the final WALK, which works as a cool-down.
- Defaults: run 1:00, walk 1:00, 8 rounds, vibration on, sound on, keep screen awake during workouts.
- State management: Riverpod (`Notifier`).
- Drift-free timing: elapsed time comes from a monotonic `Stopwatch` minus time spent paused. Never count ticks.
- Android background: `flutter_foreground_task`. iOS background: `UIBackgroundModes: audio` with a silent loop, plus pre-scheduled local notifications as a fallback.

## Requirements
- RUN and WALK phases take turns. Each duration is set in minutes and seconds, from 5 s to 59:59.
- Rounds: 1–99, or ∞ (keeps going until the user stops it).
- Controls: Start, Pause, Resume, Reset/Stop.
- Haptic events (each one fires exactly once):
  - T-3, T-2, T-1: one short tick per second, in every interval.
  - T-0 when another interval follows: a strong burst of 3 pulses. It replaces the countdown tick at that moment.
  - T-0 of the final interval: a long "workout complete" pattern instead of the switch burst.
- Optional sound cue with each haptic event. Sound and vibration have separate toggles.
- The timer and alerts keep working with the screen locked or the app minimised.
- UI: high contrast for sunlight. Orange/green for RUN, cyan/blue for WALK. Large `MM:SS` digits, a progress ring, "Round 3 / 10", and a settings bottom sheet with steppers, an ∞ toggle and sound/vibration switches. Settings are locked while a workout runs.

## Architecture
```
lib/
  main.dart, app.dart
  domain/                       pure Dart, no Flutter imports
    workout_config.dart
    interval_phase.dart
    workout_snapshot.dart
    workout_event.dart          sealed: CountdownTick(n) | PhaseSwitch(to) | WorkoutComplete
    interval_engine.dart        snapshotAt(elapsed), eventsBetween(prev, now)
  application/
    clock.dart                  Clock abstraction (system vs fake)
    workout_controller.dart     Riverpod Notifier: start/pause/resume/reset, lifecycle resync
    providers.dart
  services/
    haptic_service.dart         interface + `vibration` impl
    sound_service.dart          audioplayers, preloaded cues
    background_keeper.dart      Android foreground service / iOS audio keep-alive
    notification_scheduler.dart pre-schedules notifications for each future transition
    wake_lock_service.dart      wakelock_plus
    settings_repository.dart    shared_preferences
  ui/
    workout_screen.dart, timer_ring.dart, round_tracker.dart,
    control_bar.dart, settings_sheet.dart, theme.dart
test/
  domain/interval_engine_test.dart
  application/workout_controller_test.dart
  ui/workout_screen_test.dart
```

The timer polls about every 100 ms. Each poll calls `eventsBetween(prev, now)`, which returns every event crossed since the last poll, so none are missed or fired twice. When the app comes back from the background, countdown ticks older than about 1.5 s are dropped. Switch and complete events within that window still fire once.

## Phases
1. **Scaffold.** `flutter create` at the root, add packages, native permissions (`AndroidManifest.xml`, `Info.plist`) and generated WAV cue sounds. Check: `flutter analyze`, `flutter build apk --debug`.
2. **Domain engine, test-first.** Check: `flutter test test/domain`.
3. **Controller and services**, tested with a fake clock and a mock haptics service.
4. **UI**, with widget tests.
5. **Background and native wiring:** wake lock, foreground service, notification scheduler.
6. **QA and run guide.**

## Acceptance tests
- With run 10 s / walk 5 s / 2 rounds: ticks at 7, 8, 9; switch at 10; ticks at 12, 13, 14; switch at 15; and so on, ending with complete at 30.
- Boundaries: 6.999 s fires nothing, 7.000 s fires tick 3. Each event fires exactly once.
- No T-0 countdown tick. The last interval ends with WorkoutComplete, not PhaseSwitch.
- A single large jump (0 → 20 s) returns every crossed event in order. Stale ticks are dropped on resume, but switch events are kept.
- Pause freezes time and fires no events. Resume continues from the same remaining time.
- Intervals of 3 s or less fire only the ticks that fit. Infinite mode never completes.

## Risks
| Risk | Severity | Mitigation |
|---|---|---|
| iOS App Store review may reject a silent-audio keep-alive | HIGH (store release) | Sound cues are a real audio feature; notifications back it up |
| iOS vibration while backgrounded is less reliable | MEDIUM | Notifications with sound give a second signal |
| Android 14+ foreground-service type and exact-alarm permission rules | MEDIUM | Declare the `health` service type; request permissions in-app |
| No device or emulator connected | LOW | Build and test without one; check background behaviour on a real phone |
