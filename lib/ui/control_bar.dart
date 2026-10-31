import 'package:flutter/material.dart';

import '../application/workout_controller.dart';
import 'theme.dart';

/// Large, glove-friendly workout controls.
class ControlBar extends StatelessWidget {
  const ControlBar({
    super.key,
    required this.status,
    required this.palette,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final WorkoutStatus status;
  final PhasePalette palette;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton.styleFrom(
      backgroundColor: palette.foreground,
      foregroundColor: palette.background,
    );
    final secondary = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(72),
      foregroundColor: palette.foreground,
      side: BorderSide(color: palette.foreground, width: 3),
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );

    Widget main(String label, IconData icon, VoidCallback onPressed) =>
        FilledButton.icon(
          style: primary,
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
          label: Text(label),
        );

    Widget stop() => OutlinedButton.icon(
      style: secondary,
      onPressed: onStop,
      icon: const Icon(Icons.stop_rounded, size: 32),
      label: const Text('STOP'),
    );

    return switch (status) {
      WorkoutStatus.idle => main('START', Icons.play_arrow_rounded, onStart),
      WorkoutStatus.completed => main('AGAIN', Icons.replay_rounded, onStart),
      WorkoutStatus.running => Row(
        children: [
          Expanded(flex: 3, child: main('PAUSE', Icons.pause_rounded, onPause)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: stop()),
        ],
      ),
      WorkoutStatus.paused => Row(
        children: [
          Expanded(
            flex: 3,
            child: main('RESUME', Icons.play_arrow_rounded, onResume),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: stop()),
        ],
      ),
    };
  }
}
