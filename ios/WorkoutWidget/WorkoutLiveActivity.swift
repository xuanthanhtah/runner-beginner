import ActivityKit
import SwiftUI
import WidgetKit

// Mirrors AppColors in lib/ui/theme.dart.
private let runColor = Color(red: 1.0, green: 0x6A / 255, blue: 0.0)
private let walkColor = Color(red: 0.0, green: 0xC8 / 255, blue: 1.0)

struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
      LockScreenView(state: context.state)
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          PhaseLabel(state: state).padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Countdown(state: state)
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 6) {
            PhaseProgress(state: state)
            RoundLabel(state: state)
          }
        }
      } compactLeading: {
        Image(systemName: state.symbol).foregroundStyle(state.color)
      } compactTrailing: {
        Countdown(state: state)
          .frame(maxWidth: 52)
          .foregroundStyle(state.color)
      } minimal: {
        Image(systemName: state.symbol).foregroundStyle(state.color)
      }
    }
  }
}

private struct LockScreenView: View {
  let state: WorkoutActivityAttributes.ContentState

  var body: some View {
    VStack(spacing: 10) {
      HStack(alignment: .center) {
        PhaseLabel(state: state)
        Spacer()
        Countdown(state: state)
          .font(.system(size: 44, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
      }
      PhaseProgress(state: state)
      HStack {
        RoundLabel(state: state)
        Spacer()
        if state.isPaused {
          Label("Paused", systemImage: "pause.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
        }
      }
    }
    .padding(16)
  }
}

private struct PhaseLabel: View {
  let state: WorkoutActivityAttributes.ContentState

  var body: some View {
    Label(state.phase, systemImage: state.symbol)
      .font(.title2.weight(.heavy))
      .foregroundStyle(state.color)
  }
}

private struct RoundLabel: View {
  let state: WorkoutActivityAttributes.ContentState

  var body: some View {
    Text(state.totalRounds.map { "Round \(state.round) / \($0)" } ?? "Round \(state.round)")
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.white.opacity(0.7))
  }
}

/// Counts down natively, so the app does not have to push every second.
private struct Countdown: View {
  let state: WorkoutActivityAttributes.ContentState

  var body: some View {
    Group {
      if let remaining = state.pausedRemaining {
        Text(Duration.seconds(remaining.rounded(.up)).formatted(.time(pattern: .minuteSecond)))
      } else {
        Text(timerInterval: state.phaseStart...state.phaseEnd, countsDown: true)
      }
    }
    .monospacedDigit()
    .multilineTextAlignment(.trailing)
  }
}

private struct PhaseProgress: View {
  let state: WorkoutActivityAttributes.ContentState

  var body: some View {
    Group {
      if let remaining = state.pausedRemaining {
        let total = state.phaseEnd.timeIntervalSince(state.phaseStart)
        ProgressView(value: total > 0 ? 1 - remaining / total : 1)
      } else {
        ProgressView(timerInterval: state.phaseStart...state.phaseEnd, countsDown: false) {
          EmptyView()
        } currentValueLabel: {
          EmptyView()
        }
      }
    }
    .tint(state.color)
  }
}

extension WorkoutActivityAttributes.ContentState {
  fileprivate var color: Color { isRun ? runColor : walkColor }
  fileprivate var symbol: String { isRun ? "figure.run" : "figure.walk" }
}
