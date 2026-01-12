//
//  RestTimerWidgetLiveActivity.swift
//  RestTimerWidget
//
//  Created by Moritz Gößl on 12.01.26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenRestTimerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - Full timer display
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isExpired ? "exclamationmark.circle.fill" : "timer")
                        .font(.title2)
                        .foregroundStyle(context.state.isExpired ? .red : .green)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isExpired {
                        Text("Time!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(.red)
                    } else {
                        Text(timerInterval: Date.now...context.state.endTime)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isExpired ? "Rest Over!" : "Rest Timer")
                        .font(.caption)
                        .foregroundStyle(context.state.isExpired ? .primary : .secondary)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 8)
                                
                                // Progress
                                // Note: Smooth progress bar animation in background is limited.
                                // We can use the progress view or accept it updates on snapshots.
                                // For improved background reliability, a simple ProgressView(timerInterval:)
                                // is preferred if supported, but custom drawing is okay for now.
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(context.state.isExpired ? Color.red : Color.green)
                                    .frame(
                                        width: context.state.isExpired ? geometry.size.width : geometry.size.width * CGFloat(context.state.remainingSeconds / context.attributes.restDuration),
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)
                        
                        Text(context.attributes.exerciseName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isExpired ? "exclamationmark.circle.fill" : "timer")
                    .foregroundStyle(context.state.isExpired ? .red : .green)
            } compactTrailing: {
                if context.state.isExpired {
                    Text("Time!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(.red)
                } else {
                    Text(timerInterval: Date.now...context.state.endTime)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.trailing)
                }
            } minimal: {
                Image(systemName: context.state.isExpired ? "exclamationmark.circle.fill" : "timer")
                    .foregroundStyle(context.state.isExpired ? .red : .green)
            }
            .keylineTint(context.state.isExpired ? .red : .green)
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenRestTimerView: View {
    let context: ActivityViewContext<RestTimerActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: context.state.isExpired ? "exclamationmark" : "timer")
                    .foregroundStyle(timerColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.isExpired ? "Rest Over!" : "Rest Timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if context.state.isExpired {
                    Text("0:00")
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.red)
                } else {
                    Text(timerInterval: Date.now...context.state.endTime)
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
                
                Text(context.attributes.exerciseName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.3))
        .activitySystemActionForegroundColor(.white)
    }
    
    private var progress: CGFloat {
        context.state.isExpired ? 1.0 : CGFloat(context.state.remainingSeconds / context.attributes.restDuration)
    }
    
    private var timerColor: Color {
        context.state.isExpired ? .red : .green
    }
}

// MARK: - Previews

extension RestTimerActivityAttributes {
    fileprivate static var preview: RestTimerActivityAttributes {
        RestTimerActivityAttributes(exerciseName: "Bench Press", restDuration: 120)
    }
}

extension RestTimerActivityAttributes.ContentState {
    fileprivate static var active: RestTimerActivityAttributes.ContentState {
        RestTimerActivityAttributes.ContentState(
            endTime: Date().addingTimeInterval(90),
            remainingSeconds: 90,
            isExpired: false
        )
    }
    
    fileprivate static var complete: RestTimerActivityAttributes.ContentState {
        RestTimerActivityAttributes.ContentState(
            endTime: Date(),
            remainingSeconds: 0,
            isExpired: true
        )
    }
}

#Preview("Notification", as: .content, using: RestTimerActivityAttributes.preview) {
   RestTimerLiveActivity()
} contentStates: {
    RestTimerActivityAttributes.ContentState.active
    RestTimerActivityAttributes.ContentState.complete
}
