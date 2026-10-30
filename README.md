# Run/Walk Interval Timer

A Flutter app (Android + iOS) that alternates **RUN** and **WALK** intervals and gives you a clear vibration and sound cue at each step:

| When | Cue |
|---|---|
| T-3s, T-2s, T-1s of every interval | short single tick |
| T-0, another interval follows | strong burst of 3 pulses |
| T-0 of the final WALK | long "workout complete" pattern |

One round = RUN then WALK. Set 1–99 rounds, or ∞ to repeat until you stop. The timer and cues keep running with the screen locked. Design notes: [docs/run-walk-timer.plan.md](docs/run-walk-timer.plan.md).

## Running it

### 1. Toolchains (one-time)
`flutter doctor` must show the platform you want as ✓.

- **Android:** install [Android Studio](https://developer.android.com/studio). Open its SDK Manager and install an SDK plus *Android SDK Command-line Tools*, then run `flutter doctor --android-licenses`.
- **iOS:** install Xcode from the App Store, then run:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch
  ```
  CocoaPods is already installed.

### 2. Run
```bash
flutter pub get
flutter devices                 # find your phone / emulator
flutter run -d <device-id>      # debug build
flutter run -d <device-id> --release   # use this to test background behaviour
```

To use an emulator: `flutter emulators` lists them and `flutter emulators --launch <id>` starts one. Vibration only works on a **real phone**.

**iOS signing (first time only):** open `ios/Runner.xcworkspace` in Xcode. Select *Runner → Signing & Capabilities*, pick your Team, and change the bundle id `com.runwalk.runWalkTimer` to something unique. Then on the phone, go to *Settings → General → VPN & Device Management* and trust the developer.

### 3. Tests
```bash
flutter test      # 45 unit + widget tests
flutter analyze
```

## Checking background behaviour on a phone
1. Settings: Run 0:10, Walk 0:10, 3 rounds, Keep screen on **off**.
2. Press START, then lock the screen right away.
3. You should feel ticks at 7, 8 and 9 s and the 3-pulse switch at 10 s, all the way to the long completion buzz at 60 s.
4. Repeat with the app minimised and with music playing.

## How background execution works
| Platform | Mechanism |
|---|---|
| Android | A foreground service (`flutter_foreground_task`, type `specialUse`) shows an ongoing "RUN in progress · Round x/y" notification and holds a CPU wake lock, so the Dart timer keeps running. Android 13+ asks for notification permission on the first START. |
| iOS | The `audio` background mode plus a silent looping track keeps the app alive, so in-app vibration and sound keep firing. As a fallback, every upcoming switch and the finish are also scheduled as local notifications (at most 60 ahead, the iOS limit is 64), which are cancelled on pause or stop. |

Timing never drifts. Elapsed time comes from a monotonic `Stopwatch` minus time spent paused, and the 100 ms poll only decides *when* to look at it. If the OS delays the app, it catches up correctly: countdown ticks more than 1.5 s late are skipped, and only the latest phase switch is replayed (if it's under 5 s old).

## Known limitations
- **App Store:** Apple may reject the silent-audio keep-alive. Use is fine for personal installs and TestFlight. Before publishing, either justify the background audio mode with the sound cues or rely on notifications only.
- **Google Play:** a `specialUse` foreground service needs a short justification in the Play Console.
- **iPhone Silent switch:** with it on, sound cues and notification sounds are muted (vibration still works).
- **Aggressive battery savers** (some Xiaomi, Huawei and Samsung phones) can still kill background apps. Exclude the app from battery optimisation if cues stop.

## Project layout
```
lib/domain/        pure Dart: config, interval engine (snapshot + events)
lib/application/   Riverpod WorkoutController, clock, providers
lib/services/      haptics, sound, background keeper, notifications, wake lock, settings
lib/ui/            workout screen, timer ring, controls, settings sheet, theme
assets/sounds/     generated WAV cues (tick, switch, complete, silence)
```
