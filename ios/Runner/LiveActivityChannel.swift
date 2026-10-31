import ActivityKit
import Flutter
import Foundation

/// Handles `run_walk_timer/live_activity` calls from
/// `lib/services/live_activity_service.dart`.
enum LiveActivityChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "run_walk_timer/live_activity", binaryMessenger: messenger)

    guard #available(iOS 16.2, *) else {
      channel.setMethodCallHandler { _, result in result(nil) }
      return
    }

    let controller = WorkoutActivityController()
    controller.endLeftovers()
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "show":
        if let args = call.arguments as? [String: Any],
          let state = WorkoutActivityAttributes.ContentState(args)
        {
          controller.show(state)
        }
        result(nil)
      case "end":
        controller.end()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

@available(iOS 16.2, *)
private final class WorkoutActivityController {
  private var activity: Activity<WorkoutActivityAttributes>?

  func show(_ state: WorkoutActivityAttributes.ContentState) {
    let content = ActivityContent(state: state, staleDate: nil)
    if let activity, activity.activityState == .active {
      Task { await activity.update(content) }
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    do {
      activity = try Activity.request(
        attributes: WorkoutActivityAttributes(), content: content)
    } catch {
      NSLog("LiveActivity: request failed: \(error)")
    }
  }

  func end() {
    guard let activity else { return }
    self.activity = nil
    Task { await activity.end(nil, dismissalPolicy: .immediate) }
  }

  /// Activities outlive the app process; drop any from a previous run that
  /// was killed mid-workout.
  func endLeftovers() {
    Task {
      for activity in Activity<WorkoutActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }
}

extension WorkoutActivityAttributes.ContentState {
  fileprivate init?(_ args: [String: Any]) {
    guard let phase = args["phase"] as? String,
      let round = args["round"] as? Int,
      let startMs = args["phaseStartMs"] as? Int,
      let endMs = args["phaseEndMs"] as? Int
    else { return nil }
    self.init(
      phase: phase,
      round: round,
      totalRounds: args["totalRounds"] as? Int,
      phaseStart: Date(timeIntervalSince1970: Double(startMs) / 1000),
      phaseEnd: Date(timeIntervalSince1970: Double(endMs) / 1000),
      pausedRemaining: (args["pausedRemainingMs"] as? Int).map { Double($0) / 1000 })
  }
}
