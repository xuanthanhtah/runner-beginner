import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/workout_controller.dart';
import '../domain/interval_phase.dart';
import 'control_bar.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'timer_ring.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Catch up immediately when returning from the background instead of
    // waiting for the next poll.
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(workoutControllerProvider.notifier).onAppResumed(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutControllerProvider);
    final controller = ref.read(workoutControllerProvider.notifier);
    final palette = PhasePalette.of(state);
    final snapshot = state.snapshot;
    final isComplete = state.status == WorkoutStatus.completed;

    final phaseLabel = isComplete ? 'DONE' : snapshot.phase.label;
    final countdown = formatCountdown(snapshot.remaining);
    final roundText = snapshot.totalRounds == null
        ? 'Round ${snapshot.round} · ∞'
        : 'Round ${snapshot.round} / ${snapshot.totalRounds}';

    final nextPhase = snapshot.phase == IntervalPhase.run
        ? IntervalPhase.walk
        : IntervalPhase.run;
    final nextDuration = state.config.durationOf(nextPhase);
    final isLastInterval =
        snapshot.totalRounds != null &&
        snapshot.round == snapshot.totalRounds &&
        snapshot.phase == state.config.secondPhase;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: palette.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      state.status == WorkoutStatus.paused
                          ? 'PAUSED'
                          : 'RUN / WALK',
                      style: TextStyle(
                        color: palette.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Workout settings',
                      iconSize: 30,
                      color: palette.foreground,
                      onPressed: state.isActive
                          ? null
                          : () => SettingsSheet.show(
                              context,
                              initial: state.config,
                              onSave: controller.updateConfig,
                            ),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                Expanded(
                  child: Semantics(
                    container: true,
                    label: '$phaseLabel, $countdown remaining, $roundText',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          phaseLabel,
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final size = math.min(
                              math.min(constraints.maxWidth, 360.0),
                              MediaQuery.sizeOf(context).height * 0.42,
                            );
                            return SizedBox.square(
                              dimension: size,
                              child: TimerRing(
                                progress: snapshot.progress,
                                color: palette.accent,
                                child: FittedBox(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      countdown,
                                      style: TextStyle(
                                        color: palette.foreground,
                                        fontSize: 96,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: tabularFigures,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          roundText,
                          style: TextStyle(
                            color: palette.foreground,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!isComplete)
                          Text(
                            isLastInterval
                                ? 'Last interval'
                                : 'Next · ${nextPhase.label} '
                                      '${formatCountdown(nextDuration)}',
                            style: TextStyle(
                              color: palette.foreground.withValues(alpha: 0.8),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                ControlBar(
                  status: state.status,
                  palette: palette,
                  onStart: controller.start,
                  onPause: controller.pause,
                  onResume: controller.resume,
                  onStop: controller.reset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
