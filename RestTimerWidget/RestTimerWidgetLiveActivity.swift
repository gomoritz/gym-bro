//
//  RestTimerWidgetLiveActivity.swift
//  RestTimerWidget
//
//  Created by Moritz Gößl on 12.01.26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) {
            context in
            // Lock screen/banner UI
            LockScreenRestTimerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimalView(context: context)
            }
            .keylineTint(stateColor(for: context))
        }
    }

    // MARK: - Expanded Leading

    @ViewBuilder
    private func expandedLeading(
        context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> some View {
        switch context.state.timerState {
        case .idle:
            Image(systemName: "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(stateColor(for: context))
                .padding(.leading, 4)

        case .restTimerRunning, .restTimerExpired:
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(stateColor(for: context))
                .padding(.leading, 4)

        case .transitionTimerRunning, .transitionTimerExpired:
            Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(stateColor(for: context))
                .padding(.leading, 4)
        }
    }

    // MARK: - Expanded Trailing

    @ViewBuilder
    private func expandedTrailing(
        context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> some View {
        VStack(alignment: .trailing) {
            switch context.state.timerState {
            case .idle:
                Text("Continue")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.5)

            case .restTimerRunning, .transitionTimerRunning:
                if let endTime = context.state.endTime {
                    Text(timerInterval: Date.now...endTime)
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(stateColor(for: context))
                        .lineLimit(1)
                        .allowsTightening(true)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.5)
                }

            case .restTimerExpired, .transitionTimerExpired:
                Text("Time's up!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(.trailing, 4)
    }

    // MARK: - Expanded Center

    @ViewBuilder
    private func expandedCenter(
        context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> some View {
        VStack(alignment: .center, spacing: 4) {
            // Status label
            switch context.state.timerState {
            case .idle:
                Text("Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .restTimerRunning:
                Text("Rest")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .transitionTimerRunning:
                Text("Transition")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .restTimerExpired:
                Text("Rest complete")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)

            case .transitionTimerExpired:
                Text("Ready to go")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }

            // Exercise name
            Text(exerciseDisplayName(context: context))
                .font(.headline)
                .lineLimit(1)
                .allowsTightening(true)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Expanded Bottom

    @ViewBuilder
    private func expandedBottom(
        context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> some View {
        switch context.state.timerState {
        case .idle:
            if let setNumber = context.state.currentSetNumber {
                Text("Set \(setNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
            }

        case .restTimerRunning:
            if let setNumber = context.state.currentSetNumber {
                Text("Set \(setNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
            }

        case .transitionTimerRunning, .transitionTimerExpired:
            VStack(spacing: 2) {
                if let target = context.state.nextExerciseTarget {
                    Label(target, systemImage: "target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .allowsTightening(true)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let notes = context.state.nextExerciseNotes {
                    Label(notes, systemImage: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .allowsTightening(true)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.top, 2)

        case .restTimerExpired:
            if let setNumber = context.state.currentSetNumber {
                Text("Set \(setNumber) complete")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.top, 1)
            }
        }
    }

    // MARK: - Compact Leading

    @ViewBuilder
    private func compactLeading(
        context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            switch context.state.timerState {
            case .idle:
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.green)

                Text("Ready")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

            case .restTimerRunning, .transitionTimerRunning:
                Image(
                    systemName: context.state.timerState == .restTimerRunning
                        ? "timer" : "arrow.right.circle.fill"
                )
                .foregroundStyle(stateColor(for: context))

                if let endTime = context.state.endTime {
                    Text(timerInterval: Date.now...endTime)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(stateColor(for: context))
                }

            case .restTimerExpired, .transitionTimerExpired:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)

                Text("Over")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.75)
            }

            Spacer()
        }
    }

    // MARK: - Compact Trailing

    @ViewBuilder
    private func compactTrailing(
        context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> some View {
        HStack(spacing: 4) {
            switch context.state.timerState {
            case .idle, .restTimerRunning, .restTimerExpired:
                Text(context.state.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

            case .transitionTimerRunning, .transitionTimerExpired:
                if let nextExercise = context.state.nextExerciseName {
                    Text(nextExercise)
                        .font(.headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.5)
                } else {
                    Text("Next Exercise")
                        .font(.headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .padding(.trailing, 6)
    }

    // MARK: - Minimal

    @ViewBuilder
    private func minimalView(
        context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> some View {
        switch context.state.timerState {
        case .idle:
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(.green)

        case .restTimerRunning, .transitionTimerRunning:
            if let endTime = context.state.endTime {
                Text(timerInterval: Date.now...endTime)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(stateColor(for: context))
                    .allowsTightening(true)
                    .minimumScaleFactor(0.5)
            } else {
                Image(systemName: "timer")
                    .foregroundStyle(stateColor(for: context))
            }

        case .restTimerExpired, .transitionTimerExpired:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helper Methods

    private func stateColor(
        for context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> Color {
        switch context.state.timerState {
        case .idle:
            return .green

        case .restTimerRunning:
            return .orange

        case .transitionTimerRunning:
            return .blue

        case .restTimerExpired, .transitionTimerExpired:
            return .red
        }
    }

    private func exerciseDisplayName(
        context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> String {
        switch context.state.timerState {
        case .idle, .restTimerRunning, .restTimerExpired:
            return context.state.exerciseName

        case .transitionTimerRunning, .transitionTimerExpired:
            return context.state.nextExerciseName ?? "Next Exercise"
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenRestTimerView: View {
    let context: ActivityViewContext<RestTimerActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Circular progress/status indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Image(systemName: iconName)
                    .foregroundStyle(timerColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Status and exercise
                HStack(spacing: 4) {
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if context.state.timerState != .idle {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(exerciseDisplayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }

                // Timer display
                if context.state.timerState == .restTimerRunning
                    || context.state.timerState == .transitionTimerRunning
                {
                    if let endTime = context.state.endTime {
                        Text(timerInterval: Date.now...endTime)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(timerColor)
                    }
                } else if context.state.timerState == .restTimerExpired
                    || context.state.timerState == .transitionTimerExpired
                {
                    Text("Time's up!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                } else {
                    Text(exerciseDisplayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }

                // Details
                if context.state.timerState == .transitionTimerRunning
                    || context.state.timerState == .transitionTimerExpired
                {
                    VStack(alignment: .leading, spacing: 2) {
                        if let target = context.state.nextExerciseTarget {
                            Text(target)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let notes = context.state.nextExerciseNotes {
                            Text(notes)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.10).blur(radius: 5.0))
        .activityBackgroundTint(nil)
        .activitySystemActionForegroundColor(.white)
    }

    // MARK: - Lock Screen Helpers

    private var isTimerRunning: Bool {
        context.state.timerState == .restTimerRunning
            || context.state.timerState == .transitionTimerRunning
    }

    private var progress: CGFloat {
        guard isTimerRunning,
            let endTime = context.state.endTime,
            let duration = context.state.restDuration,
            duration > 0
        else {
            return 0
        }

        let remaining = endTime.timeIntervalSinceNow
        return max(0, min(1, CGFloat(remaining / duration)))
    }

    private var timerColor: Color {
        switch context.state.timerState {
        case .idle:
            return .green
        case .restTimerRunning:
            return .orange
        case .transitionTimerRunning:
            return .cyan
        case .restTimerExpired, .transitionTimerExpired:
            return .red
        }
    }

    private var iconName: String {
        switch context.state.timerState {
        case .idle:
            return "dumbbell.fill"
        case .restTimerRunning:
            return "timer"
        case .transitionTimerRunning:
            return "arrow.right"
        case .restTimerExpired, .transitionTimerExpired:
            return "exclamationmark"
        }
    }

    private var statusLabel: String {
        switch context.state.timerState {
        case .idle:
            return "Ready"
        case .restTimerRunning:
            return "Rest"
        case .transitionTimerRunning:
            return "Transition"
        case .restTimerExpired:
            return "Rest Over!"
        case .transitionTimerExpired:
            return "Let's Go!"
        }
    }

    private var exerciseDisplayName: String {
        switch context.state.timerState {
        case .idle, .restTimerRunning, .restTimerExpired:
            return context.state.exerciseName
        case .transitionTimerRunning, .transitionTimerExpired:
            return context.state.nextExerciseName ?? "Next Exercise"
        }
    }
}

// MARK: - Previews

extension RestTimerActivityAttributes {
    fileprivate static var preview: RestTimerActivityAttributes {
        RestTimerActivityAttributes()
    }
}

extension RestTimerActivityAttributes.ContentState {
    fileprivate static var idle: RestTimerActivityAttributes.ContentState {
        RestTimerActivityAttributes.ContentState(
            timerState: .idle,
            exerciseName: "Bench Press",
            currentSetNumber: 1
        )
    }

    fileprivate static var restRunning: RestTimerActivityAttributes.ContentState
    {
        RestTimerActivityAttributes.ContentState(
            timerState: .restTimerRunning,
            exerciseName: "Bench Press",
            currentSetNumber: 1,
            endTime: Date().addingTimeInterval(90),
            restDuration: 120
        )
    }

    fileprivate static var transitionRunning:
        RestTimerActivityAttributes.ContentState
    {
        RestTimerActivityAttributes.ContentState(
            timerState: .transitionTimerRunning,
            exerciseName: "Transition",
            endTime: Date().addingTimeInterval(60),
            restDuration: 120,
            nextExerciseName: "Squats",
            nextExerciseTarget: "4 sets × 8-10 reps @ 100kg",
            nextExerciseNotes: "Keep form tight"
        )
    }

    fileprivate static var restExpired: RestTimerActivityAttributes.ContentState
    {
        RestTimerActivityAttributes.ContentState(
            timerState: .restTimerExpired,
            exerciseName: "Bench Press",
            currentSetNumber: 1
        )
    }

    fileprivate static var transitionExpired:
        RestTimerActivityAttributes.ContentState
    {
        RestTimerActivityAttributes.ContentState(
            timerState: .transitionTimerExpired,
            exerciseName: "Transition",
            nextExerciseName: "Squats",
            nextExerciseTarget: "4 sets × 8-10 reps @ 100kg",
            nextExerciseNotes: "Keep form tight"
        )
    }
}

#Preview(
    "Idle State",
    as: .content,
    using: RestTimerActivityAttributes.preview
) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerActivityAttributes.ContentState.idle
}

#Preview(
    "Rest Timer Running",
    as: .content,
    using: RestTimerActivityAttributes.preview
) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerActivityAttributes.ContentState.restRunning
}

#Preview(
    "Rest Timer Expired",
    as: .content,
    using: RestTimerActivityAttributes.preview
) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerActivityAttributes.ContentState.restExpired
}

#Preview(
    "Transition Timer Running",
    as: .content,
    using: RestTimerActivityAttributes.preview
) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerActivityAttributes.ContentState.transitionRunning
}

#Preview(
    "Transition Timer Expired",
    as: .content,
    using: RestTimerActivityAttributes.preview
) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerActivityAttributes.ContentState.transitionExpired
}
