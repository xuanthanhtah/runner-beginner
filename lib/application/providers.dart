import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_keeper.dart';
import '../services/haptic_service.dart';
import '../services/live_activity_service.dart';
import '../services/settings_repository.dart';
import '../services/sound_service.dart';
import '../services/wake_lock_service.dart';
import 'clock.dart';

typedef PeriodicScheduler = Timer Function(
  Duration interval,
  void Function(Timer timer) callback,
);

final clockProvider = Provider<Clock>((ref) => SystemClock());

final periodicSchedulerProvider = Provider<PeriodicScheduler>(
  (ref) => Timer.periodic,
);

final hapticServiceProvider = Provider<HapticService>(
  (ref) => VibrationHapticService(),
);

final soundServiceProvider = Provider<SoundService>(
  (ref) => AudioPlayersSoundService(),
);

final backgroundKeeperProvider = Provider<BackgroundKeeper>(
  (ref) => createPlatformBackgroundKeeper(),
);

final liveActivityServiceProvider = Provider<LiveActivityService>(
  (ref) => createPlatformLiveActivityService(),
);

final wakeLockServiceProvider = Provider<WakeLockService>(
  (ref) => WakelockPlusService(),
);

/// Must be overridden in `main()` once SharedPreferences has loaded.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) =>
      throw UnimplementedError('settingsRepositoryProvider not overridden'),
);
