import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract interface class SoundService {
  Future<void> countdownTick();
  Future<void> phaseSwitch();
  Future<void> workoutComplete();
}

/// Plays short bundled cue sounds over any music that is playing.
class AudioPlayersSoundService implements SoundService {
  AudioPlayersSoundService();

  // Android ducks music only for the duration of each cue. iOS shares one
  // audio session that the background keep-alive holds open, so ducking there
  // would lower the user's music for the whole workout: mix instead.
  static final cueContext = AudioContextConfig(
    focus: Platform.isIOS
        ? AudioContextConfigFocus.mixWithOthers
        : AudioContextConfigFocus.duckOthers,
    stayAwake: true,
  ).build();

  final _tick = _Cue('sounds/tick.wav');
  final _switch = _Cue('sounds/switch.wav');
  final _complete = _Cue('sounds/complete.wav');

  @override
  Future<void> countdownTick() => _tick.play();

  @override
  Future<void> phaseSwitch() => _switch.play();

  @override
  Future<void> workoutComplete() => _complete.play();
}

class _Cue {
  _Cue(this.asset);

  final String asset;
  AudioPlayer? _player;

  Future<void> play() async {
    try {
      final player = _player ??= await _create();
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('SoundService: failed to play $asset: $e');
    }
  }

  Future<AudioPlayer> _create() async {
    final player = AudioPlayer();
    await player.setAudioContext(AudioPlayersSoundService.cueContext);
    await player.setReleaseMode(ReleaseMode.stop);
    return player;
  }
}
