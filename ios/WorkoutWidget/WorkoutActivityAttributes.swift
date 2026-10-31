import ActivityKit
import Foundation

/// Shared by the Runner app (which starts and updates the activity) and the
/// WorkoutWidget extension (which renders it).
struct WorkoutActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// "RUN" or "WALK".
    var phase: String
    var round: Int
    var totalRounds: Int?
    var phaseStart: Date
    var phaseEnd: Date
    /// Seconds left in the interval while paused; `nil` while running.
    var pausedRemaining: TimeInterval?

    var isRun: Bool { phase == "RUN" }
    var isPaused: Bool { pausedRemaining != nil }
  }
}
