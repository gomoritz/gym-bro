//
//  WatchRestTimerView.swift
//  gym-bro Watch
//

import SwiftUI
import WatchKit

struct WatchRestTimerView: View {
    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 8) {
            timerDisplay
            heartRateDisplay
            exerciseInfo
            dismissButton
        }
        .padding(.horizontal, 4)
        .onChange(of: sessionManager.isTimerExpired) { _, expired in
            if expired {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(timerColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            // Time text
            VStack(spacing: 2) {
                if sessionManager.isTimerExpired {
                    Text("Done!")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.red)
                } else {
                    Text(timeString)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(timerColor)
                }

                if sessionManager.transitionToExercise != nil {
                    Text("Transition")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Rest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 120, height: 120)
    }

    // MARK: - Heart Rate

    private var heartRateDisplay: some View {
        Group {
            if let hr = sessionManager.healthKitManager.currentHeartRate {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text("\(Int(hr)) BPM")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Exercise Info

    private var exerciseInfo: some View {
        Group {
            if let transition = sessionManager.transitionToExercise {
                Text("Next: \(transition.name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let exercise = sessionManager.currentExercise {
                Text("\(exercise.name) — Set \(sessionManager.currentSetNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button {
            sessionManager.toggleTimer()
        } label: {
            Text(sessionManager.isTimerExpired ? "Continue" : "Skip")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var progress: CGFloat {
        guard sessionManager.restTimerDuration > 0 else { return 0 }
        if sessionManager.isTimerExpired { return 1.0 }
        return CGFloat(1.0 - (sessionManager.restTimeRemaining / sessionManager.restTimerDuration))
    }

    private var timeString: String {
        let total = Int(sessionManager.restTimeRemaining)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var timerColor: Color {
        if sessionManager.isTimerExpired { return .red }
        if sessionManager.transitionToExercise != nil { return .blue }
        return .orange
    }
}
