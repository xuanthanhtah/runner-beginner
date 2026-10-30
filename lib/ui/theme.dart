import 'package:flutter/material.dart';

import '../application/workout_controller.dart';
import '../domain/interval_phase.dart';

/// High-contrast palette tuned for glanceability in direct sunlight:
/// saturated full-bleed backgrounds with near-black foregrounds.
abstract final class AppColors {
  static const run = Color(0xFFFF6A00);
  static const walk = Color(0xFF00C8FF);
  static const done = Color(0xFF2BE38B);
  static const idleBackground = Color(0xFF0E0E10);
  static const ink = Color(0xFF0A0A0A);
  static const paper = Color(0xFFF5F5F5);
}

/// Colours for the current workout state.
class PhasePalette {
  const PhasePalette({
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final Color background;
  final Color foreground;

  /// Accent for the phase label and progress ring.
  final Color accent;

  factory PhasePalette.of(WorkoutState state) {
    final phaseColor = state.snapshot.phase == IntervalPhase.run
        ? AppColors.run
        : AppColors.walk;
    return switch (state.status) {
      WorkoutStatus.idle => PhasePalette(
          background: AppColors.idleBackground,
          foreground: AppColors.paper,
          accent: phaseColor,
        ),
      WorkoutStatus.running => PhasePalette(
          background: phaseColor,
          foreground: AppColors.ink,
          accent: AppColors.ink,
        ),
      WorkoutStatus.paused => PhasePalette(
          background: Color.lerp(phaseColor, AppColors.idleBackground, 0.55)!,
          foreground: AppColors.paper,
          accent: phaseColor,
        ),
      WorkoutStatus.completed => const PhasePalette(
          background: AppColors.done,
          foreground: AppColors.ink,
          accent: AppColors.ink,
        ),
    };
  }
}

const tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.run,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.idleBackground,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        textStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
  );
}

/// `MM:SS`, rounding up so the display reads 00:03 at the T-3 tick and only
/// shows 00:00 when the interval is actually over.
String formatCountdown(Duration remaining) {
  final totalSeconds =
      (remaining.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
          Duration.microsecondsPerSecond;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Compact `M:SS` used in settings.
String formatShort(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
