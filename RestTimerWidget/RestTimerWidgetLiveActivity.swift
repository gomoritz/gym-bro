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
                    Image(systemName: context.state.isExpired ? "exclamationmark.circle.fill" : (context.attributes.isTransition ? "arrow.right.circle.fill" : "timer"))
                        .font(.title2)
                        .foregroundStyle(timerColor(for: context))
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
                            .foregroundStyle(timerColor(for: context))
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .center) { // Centered alignment
                        Text(context.state.isExpired ? (context.attributes.isTransition ? "Let's Go!" : "Rest Over!") : (context.attributes.isTransition ? "Next Up" : "Rest Timer"))
                            .font(.caption)
                            .foregroundStyle(context.state.isExpired ? .primary : .secondary)
                        
                        Text(context.attributes.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity) // Ensure full width for centering
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        // Details (Target / Notes)
                        if context.attributes.isTransition {
                            VStack(spacing: 4) { // Changed to VStack for more space
                                if let target = context.attributes.target {
                                    Label(target, systemImage: "target")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                if let notes = context.attributes.notes {
                                    Label(notes, systemImage: "note.text")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2) // Allow more lines
                                }
                            }
                        }
                        
                        // Progress bar using native ProgressView for better reliability in Live Activities
                        ProgressView(
                            timerInterval: Date.now...context.state.endTime,
                            countsDown: true,
                            label: { EmptyView() },
                            currentValueLabel: { EmptyView() }
                        )
                        .tint(timerColor(for: context))
                        // Note: If ProgressView(timerInterval:) isn't visually suitable, we revert to manual
                        // But Native ProgressView handles background updates better.
                        // However, standard style is a thin bar. Let's try custom GeometryReader again but simpler
                        // or ensure we aren't relying on rapid updates.
                        // Actually, users usually prefer the visual bar. Let's stick to GeometryReader but ensure
                        // context.state.remainingSeconds is valid. It might only update on state changes.
                        // For smooth animation in a widget, we need `timerInterval` compatible views.
                        // `ProgressView(timerInterval: ...)` IS the way to go for smooth updates.
                        // Let's replace the custom one with the native one.
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isExpired ? "exclamationmark.circle.fill" : (context.attributes.isTransition ? "arrow.right.circle.fill" : "timer"))
                    .foregroundStyle(timerColor(for: context))
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
                        .foregroundStyle(timerColor(for: context))
                        .multilineTextAlignment(.trailing)
                }
            } minimal: {
                Image(systemName: context.state.isExpired ? "exclamationmark.circle.fill" : (context.attributes.isTransition ? "arrow.right.circle.fill" : "timer"))
                    .foregroundStyle(timerColor(for: context))
            }
            .keylineTint(timerColor(for: context))
        }
    }
    
    func timerColor(for context: ActivityViewContext<RestTimerActivityAttributes>) -> Color {
        if context.state.isExpired {
            return .red
        }
        return context.attributes.isTransition ? .blue : .green
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
                
                // Note: Smoother rotation in lock screen is hard without timerInterval
                // We fallback to a static "snapshot" of progress or use a full View that supports it.
                // For now, keep as is.
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: context.state.isExpired ? "exclamationmark" : (context.attributes.isTransition ? "arrow.right" : "timer"))
                    .foregroundStyle(timerColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(context.state.isExpired ? (context.attributes.isTransition ? "Let's Go!" : "Rest Over!") : (context.attributes.isTransition ? "Next Up" : "Rest Timer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if context.attributes.isTransition {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.exerciseName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                
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
                        .foregroundStyle(timerColor)
                }
                
                if context.attributes.isTransition {
                     VStack(alignment: .leading, spacing: 2) { // Changed to VStack for vertical stacking
                        if let target = context.attributes.target {
                            Text(target)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let notes = context.attributes.notes {
                            Text(notes)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2) // Increase line limit
                        }
                    }
                } else {
                    Text(context.attributes.exerciseName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.black) // Solid black background
        .activityBackgroundTint(nil) // Remove tint to allow solid background
        .activitySystemActionForegroundColor(.white)
    }
    
    private var progress: CGFloat {
        context.state.isExpired ? 1.0 : CGFloat(context.state.remainingSeconds / context.attributes.restDuration)
    }
    
    private var timerColor: Color {
        if context.state.isExpired {
            return .red
        }
        return context.attributes.isTransition ? .cyan : .green // Use cyan for better visibility
    }
}

// MARK: - Previews

extension RestTimerActivityAttributes {
    fileprivate static var preview: RestTimerActivityAttributes {
        RestTimerActivityAttributes(exerciseName: "Bench Press", restDuration: 120, isTransition: false)
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
