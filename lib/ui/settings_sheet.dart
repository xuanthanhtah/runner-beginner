import 'package:flutter/material.dart';

import '../domain/workout_config.dart';
import 'theme.dart';

/// Bottom sheet for editing the workout. Edits are kept in a local draft and
/// only applied when the user taps SAVE.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.initial, required this.onSave});

  final WorkoutConfig initial;
  final ValueChanged<WorkoutConfig> onSave;

  static Future<void> show(
    BuildContext context, {
    required WorkoutConfig initial,
    required ValueChanged<WorkoutConfig> onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1A1A1D),
      builder: (_) => SettingsSheet(initial: initial, onSave: onSave),
    );
  }

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  static const _presets = [
    (Duration(minutes: 1), Duration(minutes: 1)),
    (Duration(minutes: 2), Duration(minutes: 1)),
    (Duration(minutes: 3), Duration(minutes: 1)),
    (Duration(seconds: 30), Duration(seconds: 90)),
  ];

  late Duration _run = widget.initial.runDuration;
  late Duration _walk = widget.initial.walkDuration;
  late int _rounds = widget.initial.rounds ?? WorkoutConfig.defaults.rounds!;
  late bool _infinite = widget.initial.isInfinite;
  late bool _sound = widget.initial.soundEnabled;
  late bool _vibration = widget.initial.vibrationEnabled;
  late bool _keepScreenOn = widget.initial.keepScreenOn;

  /// 5 s steps for short intervals, 15 s steps above 30 s.
  static Duration _step(Duration d, {required bool up}) {
    final stepSeconds = (up ? d.inSeconds < 30 : d.inSeconds <= 30) ? 5 : 15;
    final next = d + Duration(seconds: up ? stepSeconds : -stepSeconds);
    return WorkoutConfig.clampInterval(next);
  }

  void _save() {
    widget.onSave(WorkoutConfig(
      runDuration: _run,
      walkDuration: _walk,
      rounds: _infinite ? null : _rounds,
      soundEnabled: _sound,
      vibrationEnabled: _vibration,
      keepScreenOn: _keepScreenOn,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                child: Text('Workout settings',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, 48),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                onPressed: _save,
                child: const Text('SAVE'),
              ),
            ]),
            const SizedBox(height: 16),
            Text('Quick presets (run / walk)', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (run, walk) in _presets)
                  ChoiceChip(
                    label: Text('${formatShort(run)} / ${formatShort(walk)}'),
                    selected: _run == run && _walk == walk,
                    onSelected: (_) => setState(() {
                      _run = run;
                      _walk = walk;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _StepperRow(
              label: 'Run',
              value: formatShort(_run),
              color: AppColors.run,
              onDecrease: _run > WorkoutConfig.minIntervalDuration
                  ? () => setState(() => _run = _step(_run, up: false))
                  : null,
              onIncrease: _run < WorkoutConfig.maxIntervalDuration
                  ? () => setState(() => _run = _step(_run, up: true))
                  : null,
            ),
            _StepperRow(
              label: 'Walk',
              value: formatShort(_walk),
              color: AppColors.walk,
              onDecrease: _walk > WorkoutConfig.minIntervalDuration
                  ? () => setState(() => _walk = _step(_walk, up: false))
                  : null,
              onIncrease: _walk < WorkoutConfig.maxIntervalDuration
                  ? () => setState(() => _walk = _step(_walk, up: true))
                  : null,
            ),
            _StepperRow(
              label: 'Rounds',
              value: _infinite ? '∞' : '$_rounds',
              color: AppColors.paper,
              onDecrease: !_infinite && _rounds > WorkoutConfig.minRounds
                  ? () => setState(() => _rounds--)
                  : null,
              onIncrease: !_infinite && _rounds < WorkoutConfig.maxRounds
                  ? () => setState(() => _rounds++)
                  : null,
            ),
            SwitchListTile(
              key: const Key('infinite-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Repeat until stopped'),
              value: _infinite,
              onChanged: (v) => setState(() => _infinite = v),
            ),
            const Divider(),
            SwitchListTile(
              key: const Key('vibration-switch'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.vibration),
              title: const Text('Vibration'),
              value: _vibration,
              onChanged: (v) => setState(() => _vibration = v),
            ),
            SwitchListTile(
              key: const Key('sound-switch'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.volume_up),
              title: const Text('Sound cues'),
              value: _sound,
              onChanged: (v) => setState(() => _sound = v),
            ),
            SwitchListTile(
              key: const Key('screen-switch'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.light_mode),
              title: const Text('Keep screen on'),
              value: _keepScreenOn,
              onChanged: (v) => setState(() => _keepScreenOn = v),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 6,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        IconButton.filledTonal(
          tooltip: 'Decrease $lower',
          iconSize: 28,
          onPressed: onDecrease,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 88,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontFeatures: tabularFigures,
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Increase $lower',
          iconSize: 28,
          onPressed: onIncrease,
          icon: const Icon(Icons.add),
        ),
      ]),
    );
  }
}
