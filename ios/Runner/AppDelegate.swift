import AudioToolbox
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityChannel") {
      LiveActivityChannel.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RingerChannel") {
      RingerChannel.register(with: registrar.messenger())
    }
  }
}

/// Handles `run_walk_timer/ringer` calls from
/// `lib/services/haptic_service.dart`: buzzes like an incoming call.
///
/// The system vibrate sound keeps working while the app runs in the
/// background (kept alive by the audio session), unlike Core Haptics.
enum RingerChannel {
  /// Pause between buzzes, matching the rhythm of a ringing phone.
  private static let gap: TimeInterval = 0.6

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "run_walk_timer/ringer", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "ring":
        let count = (call.arguments as? [String: Any])?["count"] as? Int ?? 3
        ring(times: count)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func ring(times: Int) {
    guard times > 0 else { return }
    AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate) {
      DispatchQueue.main.asyncAfter(deadline: .now() + gap) {
        ring(times: times - 1)
      }
    }
  }
}
